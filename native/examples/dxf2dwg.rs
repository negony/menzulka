//! Отладочная утилита: DXF → DWG (та же логика, что в приложении).
//!
//! Запуск:
//! `cargo run --release --example dxf2dwg -- input.dxf out.dwg [--2007|--2013] [--strip]`
//!
//! Версия по умолчанию — R2018 (AC1032).

use std::path::{Path, PathBuf};

use menzulka_cad::{
    convert_dxf_to_dwg, FLAG_DWG_STRIP_CUSTOM_OBJECTS, FLAG_DWG_VERSION_MASK,
};

fn main() {
    let mut args = std::env::args().skip(1);
    let input: PathBuf = args.next().expect("нужен путь к DXF").into();
    let output: PathBuf = args.next().expect("нужен путь к DWG").into();
    let mut flags = 0u32;
    for extra in args {
        match extra.as_str() {
            "--strip" => flags |= FLAG_DWG_STRIP_CUSTOM_OBJECTS,
            "--2013" => flags = (flags & !FLAG_DWG_VERSION_MASK) | (1 << 1),
            "--2007" => flags = (flags & !FLAG_DWG_VERSION_MASK) | (2 << 1),
            other => eprintln!("неизвестный флаг: {other}"),
        }
    }

    let dxf = std::fs::read(&input).expect("не удалось прочитать DXF");
    println!("DXF: {} байт (flags={flags})", dxf.len());
    let work_dir = std::env::temp_dir().join("menzulka_dxf2dwg_example");
    let _ = std::fs::remove_dir_all(&work_dir);
    std::fs::create_dir_all(&work_dir).expect("не удалось создать рабочий каталог");

    let started = std::time::Instant::now();
    match convert_dxf_to_dwg(&dxf, &work_dir, flags) {
        Ok(dwg) => {
            write_output(&output, &dwg);
            println!(
                "DWG: {} байт за {:.1} с → {}",
                dwg.len(),
                started.elapsed().as_secs_f64(),
                output.display()
            );
            let header = &dwg[..6.min(dwg.len())];
            println!("заголовок: {}", String::from_utf8_lossy(header));
        }
        Err((code, message)) => {
            eprintln!("ошибка (код {code}): {message}");
            std::process::exit(1);
        }
    }
    let _ = std::fs::remove_dir_all(&work_dir);
}

fn write_output(path: &Path, bytes: &[u8]) {
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    std::fs::write(path, bytes).expect("не удалось записать DWG");
}
