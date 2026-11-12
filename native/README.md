# native/ — модуль DWG → DXF

Нативный слой «Мензулки»: читает DWG (R12–R2018, AC1009–AC1032) и отдаёт DXF,
который дальше разбирает существующий парсер приложения (`lib/services/dxf_parser.dart`).

## Лицензии

- **acadrust** (Rust, `=0.6.8`) — **MPL-2.0**, <https://github.com/hakanaktt/acadrust>.
  Используется как неизменённая зависимость; файлы не патчатся. Код приложения
  остаётся под MIT. Полный текст уведомлений — `../THIRD_PARTY_NOTICES.md`.
- LibreDWG (GPLv3) не используется; проприетарные SDK Autodesk/ODA не используются
  и не поставляются.

## Сборка

```powershell
powershell -ExecutionPolicy Bypass -File ..\tool\build_native.ps1
```

Скрипт соберёт:

- Windows x64: `menzulka_cad.dll` (копируется в `native/windows/` и далее в каталог
  сборки Flutter через `POST_BUILD` в `windows/CMakeLists.txt`);
- Android: `libmenzulka_cad.so` для `arm64-v8a`, `armeabi-v7a`, `x86_64`
  (в `android/app/src/main/jniLibs/`).

Требования: Rust (rustup) с целями `x86_64-pc-windows-msvc`,
`aarch64-linux-android`, `armv7-linux-androideabi`, `x86_64-linux-android`;
Android NDK; `cargo-ndk`.

## API (C ABI)

```
menzulka_dwg_to_dxf(in_ptr, in_len, workdir_ptr, flags, out_ptr, out_len, err_ptr, err_len) -> i32
menzulka_dxf_to_dwg(in_ptr, in_len, workdir_ptr, flags, out_ptr, out_len, err_ptr, err_len) -> i32
menzulka_free(ptr, len)
menzulka_version() -> *const c_char   // "menzulka_cad X / acadrust Y"
```

Коды возврата: 0 — успех, 1 — неверный вход, 2 — неподдерживаемая версия DWG,
3 — повреждённый файл, 4 — пароль/шифрование, 5 — внутренняя ошибка.

lags: бит 0 (FLAG_FILTER_UNUSED_BLOCKS) — убрать геометрию блоков без
вставок (в Civil 3D там остаются миллионы линий удалённых 3D-поверхностей).

## Тестовая фикстура

```bash
cargo run --release --manifest-path native/Cargo.toml --example make_fixture -- test/fixtures/sample_r2018.dwg
```

## Проверка лицензий зависимостей

```bash
cargo deny --manifest-path native/Cargo.toml check licenses bans sources
```
