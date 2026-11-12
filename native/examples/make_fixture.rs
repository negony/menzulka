//! Генератор тестовой DWG-фикстуры: создаёт чертёж с простой геометрией
//! (5 линий) и сохраняет его в DWG AC1032 (R2018).
//!
//! Запуск:
//! `cargo run --release --example make_fixture -- test/fixtures/sample_r2018.dwg`

use acadrust::{CadDocument, DwgWriter, EntityType, Line};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let output = std::env::args()
        .nth(1)
        .ok_or("нужен путь к выходному DWG")?;

    let mut document = CadDocument::new();

    // Квадрат 100 × 50 с диагональю — удобно проверять координаты после конвертации.
    let lines = [
        (0.0, 0.0, 100.0, 0.0),
        (100.0, 0.0, 100.0, 50.0),
        (100.0, 50.0, 0.0, 50.0),
        (0.0, 50.0, 0.0, 0.0),
        (0.0, 0.0, 100.0, 50.0),
    ];
    for (x1, y1, x2, y2) in lines {
        document.add_entity(EntityType::Line(Line::from_coords(x1, y1, 0.0, x2, y2, 0.0)))?;
    }

    if let Some(parent) = std::path::Path::new(&output).parent() {
        std::fs::create_dir_all(parent)?;
    }
    DwgWriter::write_to_file(&output, &document)?;
    println!(
        "записано: {output} (сущностей: {})",
        document.entities().count()
    );
    Ok(())
}
