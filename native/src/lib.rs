//! Нативный слой «Мензулки»: конвертация DWG → DXF через `acadrust`.
//!
//! Контракт C ABI:
//! - `menzulka_dwg_to_dxf(in_ptr, in_len, workdir_ptr, out_ptr, out_len, err_ptr, err_len) -> i32`
//!   Возвращает 0 при успехе; иначе код ошибки (см. `ErrorCode`).
//!   `out_*` и `err_*` — выходные буферы, которые вызывает освобождать
//!   `menzulka_free(ptr, len)`.
//! - `menzulka_free(ptr, len)` — освобождение буфера, выделенного библиотекой.
//! - `menzulka_version()` — статическая строка версии (UTF-8, NUL-терминированная).
//!
//! Лицензия: MPL-2.0 (сам слой), сторонние компоненты — см. THIRD_PARTY_NOTICES.md.

use std::ffi::{c_char, CStr, CString};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

use acadrust::{DwgReader, DxfError, DxfWriter};

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
            // Шифрование и ошибки распаковки в DWG обычно означают пароль
            // или повреждённый контейнер — разделяем по тексту.
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

/// Уникальный рабочий каталог, чтобы параллельные вызовы не мешали друг другу.
fn unique_work_dir(base: &Path) -> std::io::Result<PathBuf> {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    let dir = base.join(format!(
        "menzulka_cad_{}_{}",
        std::process::id(),
        nanos
    ));
    std::fs::create_dir_all(&dir)?;
    Ok(dir)
}

fn conversion(
    input: &[u8],
    work_dir: &Path,
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

    std::fs::read(&output_path)
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
        let outcome = conversion(input, &dir);
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
