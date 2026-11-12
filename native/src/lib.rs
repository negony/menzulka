//! Нативный слой «Мензулки»: конвертация DWG → DXF через `acadrust`.
//!
//! Контракт C ABI:
//! - `menzulka_dwg_to_dxf(in_ptr, in_len, workdir_ptr, flags, out_ptr, out_len, err_ptr, err_len) -> i32`
//!   Возвращает 0 при успехе; иначе код ошибки (см. `ErrorCode`).
//!   `out_*` и `err_*` — выходные буферы, которые вызывает освобождать
//!   `menzulka_free(ptr, len)`.
//!   `flags` — битовые опции (см. `FLAG_*`).
//! - `menzulka_free(ptr, len)` — освобождение буфера, выделенного библиотекой.
//! - `menzulka_version()` — статическая строка версии (UTF-8, NUL-терминированная).
//!
//! Лицензия: MPL-2.0 (сам слой), сторонние компоненты — см. THIRD_PARTY_NOTICES.md.

use std::collections::HashSet;
use std::ffi::{c_char, CStr, CString};
use std::fs::File;
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

use acadrust::{DwgReader, DxfError, DxfWriter};

/// Убрать из DXF геометрию блоков, на которые нет ни одной вставки (INSERT).
///
/// В чертежах Civil 3D часто остаются огромные «анонимные» блоки от удалённых
/// 3D-поверхностей: например, файл 51 МБ даёт 306 МБ DXF, из которых 1 025 697
/// линий лежат в трёх блоках без единой вставки. Фильтр вырезает такие блоки,
/// оставляя от них пустое определение (структура DXF и таблица BLOCK_RECORD
/// остаются валидными).
pub const FLAG_FILTER_UNUSED_BLOCKS: u32 = 1;

/// Коды ошибок, которые понимает Dart-обвязка.
#[repr(i32)]
pub enum ErrorCode {
    Ok = 0,
    BadInput = 1,
    UnsupportedVersion = 2,
    CorruptFile = 3,
    Encrypted = 4,
    Internal = 5,
}

fn set_error(err_out: &mut Option<String>, message: impl Into<String>) {
    *err_out = Some(message.into());
}

fn classify(error: &DxfError) -> (i32, String) {
    let text = error.to_string();
    let code = match error {
        DxfError::UnsupportedVersion(_) => ErrorCode::UnsupportedVersion as i32,
        DxfError::Decryption(_) | DxfError::Compression(_) | DxfError::Decompression(_) => {
            if text.to_lowercase().contains("decrypt") || text.to_lowercase().contains("password")
            {
                ErrorCode::Encrypted as i32
            } else {
                ErrorCode::CorruptFile as i32
            }
        }
        DxfError::InvalidHeader(_)
        | DxfError::InvalidFormat(_)
        | DxfError::Parse(_)
        | DxfError::ChecksumMismatch { .. }
        | DxfError::InvalidSentinel(_)
        | DxfError::InvalidDxfCode(_)
        | DxfError::RecoveryFailed(_) => ErrorCode::CorruptFile as i32,
        DxfError::Io(_) => ErrorCode::BadInput as i32,
        _ => ErrorCode::Internal as i32,
    };
    (code, text)
}

fn known_dwg_versions() -> &'static [&'static str] {
    &[
        "AC1009", "AC1012", "AC1014", "AC1015", "AC1018", "AC1021", "AC1024", "AC1027", "AC1032",
    ]
}

fn unique_work_dir(base: &Path) -> std::io::Result<PathBuf> {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    let dir = base.join(format!("menzulka_cad_{}_{}", std::process::id(), nanos));
    std::fs::create_dir_all(&dir)?;
    Ok(dir)
}

/// Собирает имена блоков, на которые есть INSERT.
///
/// `allowed` — если задан, учитываются только INSERT внутри этих блоков
/// (и внутри пространства модели). Так отбрасываются блоки, на которые
/// ссылаются лишь другие неиспользуемые блоки.
fn collect_insert_targets(
    path: &Path,
    allowed: Option<&HashSet<String>>,
) -> std::io::Result<HashSet<String>> {
    let file = File::open(path)?;
    let mut lines = BufReader::with_capacity(1 << 20, file).lines();
    let mut names = HashSet::new();
    let mut section = String::new();
    let mut current_block: Option<String> = None;
    let mut block_allowed = true;
    let mut last_entity = String::new();
    let mut awaiting_insert_name = false;

    loop {
        let code = match lines.next() {
            Some(Ok(value)) => value.trim().to_string(),
            _ => break,
        };
        let value = match lines.next() {
            Some(Ok(value)) => value.trim().to_string(),
            _ => break,
        };

        if code == "0" {
            last_entity = value.clone();
            awaiting_insert_name = value == "INSERT";
            match value.as_str() {
                "SECTION" => section.clear(),
                "ENDSEC" => {
                    section.clear();
                    current_block = None;
                }
                "BLOCK" => current_block = Some(String::new()),
                "ENDBLK" => {
                    current_block = None;
                    block_allowed = true;
                }
                _ => {}
            }
        } else if code == "2" {
            match (section.as_str(), current_block.as_deref()) {
                // имя секции
                ("", _) if last_entity == "SECTION" => section = value.clone(),
                // имя блока в секции BLOCKS
                ("BLOCKS", Some("")) => {
                    block_allowed = match allowed {
                        None => true,
                        Some(set) => set.contains(&value),
                    };
                    current_block = Some(value.clone());
                }
                // цель INSERT в пространстве модели
                ("ENTITIES", _) if awaiting_insert_name => {
                    names.insert(value.clone());
                    awaiting_insert_name = false;
                }
                // цель INSERT внутри блока — если блок участвует
                ("BLOCKS", Some(_)) if awaiting_insert_name && block_allowed => {
                    names.insert(value.clone());
                    awaiting_insert_name = false;
                }
                _ => {}
            }
        }
    }
    Ok(names)
}

/// Переписывает DXF, вырезая сущности блоков, на которые нет вставок.
///
/// От «мёртвого» блока остаются заголовок и пустое тело (BLOCK … ENDBLK),
/// поэтому структура DXF и таблица BLOCK_RECORD остаются согласованными.
fn filter_unused_blocks(input: &Path, output: &Path) -> std::io::Result<()> {
    // Несколько проходов: блок может вставляться только из другого
    // неиспользуемого блока — тогда его тоже можно выбросить.
    // Один проход: собираем все имена блоков, на которые есть INSERT.
    // Уточняющие проходы отбрасываем — на 300-мегабайтных файлах они дороже,
    // чем экономия от блоков, вставленных только из неиспользуемых блоков.
    let used = collect_insert_targets(input, None)?;

    let reader = BufReader::with_capacity(1 << 20, File::open(input)?);
    let mut lines = reader.lines();
    let mut writer = BufWriter::with_capacity(1 << 20, File::create(output)?);

    let mut in_block = false;
    let mut block_name_seen = false;
    let mut skip_block = false;
    let mut drop_entity = false;

    loop {
        let code = match lines.next() {
            Some(Ok(value)) => value,
            _ => break,
        };
        let value = match lines.next() {
            Some(Ok(value)) => value,
            _ => break,
        };
        let code_trim = code.trim();

        if !in_block {
            if code_trim == "0" && value.trim() == "BLOCK" {
                in_block = true;
                block_name_seen = false;
                skip_block = false;
                drop_entity = false;
            }
            writeln!(writer, "{code}\n{value}")?;
            continue;
        }

        if !block_name_seen {
            if code_trim == "2" {
                block_name_seen = true;
                skip_block = !used.contains(value.trim());
            }
            writeln!(writer, "{code}\n{value}")?;
            continue;
        }

        if code_trim == "0" {
            if value.trim() == "ENDBLK" {
                writeln!(writer, "{code}\n{value}")?;
                in_block = false;
                block_name_seen = false;
                skip_block = false;
                drop_entity = false;
                continue;
            }
            if skip_block {
                drop_entity = true;
                continue;
            }
            writeln!(writer, "{code}\n{value}")?;
            continue;
        }

        if drop_entity {
            continue;
        }
        writeln!(writer, "{code}\n{value}")?;
    }
    writer.flush()?;
    Ok(())
}
fn conversion(
    input: &[u8],
    work_dir: &Path,
    flags: u32,
) -> Result<Vec<u8>, (i32, String)> {
    let input_path = work_dir.join("input.dwg");
    let output_path = work_dir.join("output.dxf");
    std::fs::write(&input_path, input)
        .map_err(|e| (ErrorCode::BadInput as i32, format!("не удалось записать DWG: {e}")))?;

    let document = DwgReader::from_file(&input_path)
        .map_err(|e| classify(&e))?
        .read()
        .map_err(|e| classify(&e))?;

    DxfWriter::new(&document)
        .write_to_file(&output_path)
        .map_err(|e| classify(&e))?;

    let result_path = if flags & FLAG_FILTER_UNUSED_BLOCKS != 0 {
        let filtered_path = work_dir.join("output_filtered.dxf");
        filter_unused_blocks(&output_path, &filtered_path).map_err(|e| {
            (
                ErrorCode::Internal as i32,
                format!("не удалось отфильтровать DXF: {e}"),
            )
        })?;
        filtered_path
    } else {
        output_path
    };

    std::fs::read(&result_path)
        .map_err(|e| (ErrorCode::Internal as i32, format!("не удалось прочитать DXF: {e}")))
}

fn audit_version(input: &[u8]) -> Option<String> {
    if input.len() < 6 {
        return None;
    }
    let header = std::str::from_utf8(&input[0..6]).ok()?;
    if header.starts_with("AC10") {
        Some(header.to_string())
    } else {
        None
    }
}

/// Основная точка входа: DWG-байты → DXF-байты.
///
/// # Safety
/// Все указатели должны быть валидны; `input` должен указывать на
/// `input_len` байт, `workdir` — на NUL-терминированную UTF-8 строку.
#[no_mangle]
pub unsafe extern "C" fn menzulka_dwg_to_dxf(
    input_ptr: *const u8,
    input_len: usize,
    workdir_ptr: *const c_char,
    flags: u32,
    out_ptr: *mut *mut u8,
    out_len: *mut usize,
    err_ptr: *mut *mut u8,
    err_len: *mut usize,
) -> i32 {
    let mut output: Option<Vec<u8>> = None;
    let mut error: Option<String> = None;

    let result = catch_unwind(AssertUnwindSafe(|| -> i32 {
        if input_ptr.is_null() || workdir_ptr.is_null() || out_ptr.is_null() || out_len.is_null() {
            set_error(&mut error, "переданы нулевые указатели");
            return ErrorCode::BadInput as i32;
        }
        if input_len == 0 || input_len > 512 * 1024 * 1024 {
            set_error(&mut error, "недопустимый размер входного файла");
            return ErrorCode::BadInput as i32;
        }
        let input = std::slice::from_raw_parts(input_ptr, input_len);
        let workdir = match CStr::from_ptr(workdir_ptr).to_str() {
            Ok(value) => value.to_string(),
            Err(_) => {
                set_error(&mut error, "каталог для временных файлов не в UTF-8");
                return ErrorCode::BadInput as i32;
            }
        };
        let base = PathBuf::from(workdir);
        if !base.is_dir() {
            set_error(&mut error, format!("каталог не найден: {}", base.display()));
            return ErrorCode::BadInput as i32;
        }
        if let Some(version) = audit_version(input) {
            if !known_dwg_versions().contains(&version.as_str()) {
                set_error(
                    &mut error,
                    format!("формат DWG {version} новее поддерживаемого (до AC1032 / R2018)"),
                );
                return ErrorCode::UnsupportedVersion as i32;
            }
        } else {
            set_error(&mut error, "файл не является DWG (нет сигнатуры AC10xx)");
            return ErrorCode::BadInput as i32;
        }

        let dir = match unique_work_dir(&base) {
            Ok(dir) => dir,
            Err(e) => {
                set_error(&mut error, format!("не удалось создать рабочий каталог: {e}"));
                return ErrorCode::BadInput as i32;
            }
        };
        let outcome = conversion(input, &dir, flags);
        let _ = std::fs::remove_dir_all(&dir);
        match outcome {
            Ok(bytes) => {
                output = Some(bytes);
                ErrorCode::Ok as i32
            }
            Err((code, message)) => {
                set_error(&mut error, message);
                code
            }
        }
    }));

    let code = match result {
        Ok(code) => code,
        Err(_) => {
            error = Some("внутренняя ошибка библиотеки (паника)".to_string());
            ErrorCode::Internal as i32
        }
    };

    if !out_ptr.is_null() && !out_len.is_null() {
        match output {
            Some(bytes) => {
                let boxed = bytes.into_boxed_slice();
                let len = boxed.len();
                let raw = Box::into_raw(boxed) as *mut u8;
                *out_ptr = raw;
                *out_len = len;
            }
            None => {
                *out_ptr = std::ptr::null_mut();
                *out_len = 0;
            }
        }
    }
    if !err_ptr.is_null() && !err_len.is_null() {
        match error {
            Some(message) => {
                let bytes = message.into_bytes().into_boxed_slice();
                let len = bytes.len();
                let raw = Box::into_raw(bytes) as *mut u8;
                *err_ptr = raw;
                *err_len = len;
            }
            None => {
                *err_ptr = std::ptr::null_mut();
                *err_len = 0;
            }
        }
    }
    code
}

/// Освобождает буфер, возвращённый библиотекой.
///
/// # Safety
/// `ptr`/`len` должны быть получены из этой библиотеки и освобождаться один раз.
#[no_mangle]
pub unsafe extern "C" fn menzulka_free(ptr: *mut u8, len: usize) {
    if ptr.is_null() || len == 0 {
        return;
    }
    let slice = std::ptr::slice_from_raw_parts_mut(ptr, len);
    drop(Box::from_raw(slice));
}

/// Версия нативного слоя (строка живёт всё время работы процесса).
#[no_mangle]
pub extern "C" fn menzulka_version() -> *const c_char {
    use std::sync::OnceLock;
    static VERSION: OnceLock<CString> = OnceLock::new();
    VERSION
        .get_or_init(|| {
            CString::new(format!(
                "menzulka_cad {} / acadrust {}",
                env!("CARGO_PKG_VERSION"),
                acadrust::VERSION
            ))
            .unwrap_or_default()
        })
        .as_ptr()
}
#[cfg(test)]
mod tests {
    use super::*;

    fn sample_dxf() -> String {
        concat!(
            "0\nSECTION\n2\nBLOCKS\n",
            "0\nBLOCK\n8\n0\n2\nUSED_BLOCK\n70\n0\n",
            "0\nLINE\n8\n0\n10\n0\n20\n0\n11\n1\n21\n1\n",
            "0\nENDBLK\n",
            "0\nBLOCK\n8\n0\n2\nUNUSED_BLOCK\n70\n0\n",
            "0\nLINE\n8\n0\n10\n0\n20\n0\n11\n777\n21\n777\n",
            "0\nENDBLK\n",
            "0\nENDSEC\n",
            "0\nSECTION\n2\nENTITIES\n",
            "0\nINSERT\n8\n0\n2\nUSED_BLOCK\n",
            "0\nENDSEC\n0\nEOF\n"
        )
        .to_string()
    }

    #[test]
    fn filter_removes_only_unused_block_geometry() {
        let dir = std::env::temp_dir().join("menzulka_cad_filter_test");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let input = dir.join("in.dxf");
        let output = dir.join("out.dxf");
        std::fs::write(&input, sample_dxf()).unwrap();

        filter_unused_blocks(&input, &output).unwrap();
        let out = std::fs::read_to_string(&output).unwrap();

        // Используемый блок сохранил геометрию.
        assert!(out.contains("USED_BLOCK"));
        assert!(out.contains("11\n1"));
        // Неиспользуемый блок стал пустым определением.
        assert!(out.contains("UNUSED_BLOCK"));
        assert!(!out.contains("11\n777"));
        // Структура файла цела.
        assert!(out.contains("ENDBLK"));
        assert!(out.contains("ENTITIES"));
        let _ = std::fs::remove_dir_all(&dir);
    }

    #[test]
    fn collects_insert_targets() {
        let dir = std::env::temp_dir().join("menzulka_cad_collect_test");
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("in.dxf");
        std::fs::write(&path, sample_dxf()).unwrap();
        let used = collect_insert_targets(&path, None).unwrap();
        assert!(used.contains("USED_BLOCK"));
        assert!(!used.contains("UNUSED_BLOCK"));
        let _ = std::fs::remove_dir_all(&dir);
    }
}