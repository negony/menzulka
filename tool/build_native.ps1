# Сборка нативного слоя DWG → DXF (Rust + acadrust, MPL-2.0).
#
# Что делает:
#   1) проверяет Rust и добавляет нужные цели;
#   2) собирает Windows x64 (menzulka_cad.dll) и Android (libmenzulka_cad.so
#      для arm64-v8a, armeabi-v7a, x86_64);
#   3) кладёт артефакты туда, откуда их берут Flutter и установщик.
#
# Требования: Rust (rustup), Android NDK (через Android SDK), cargo-ndk.
# Запуск: powershell -ExecutionPolicy Bypass -File tool\build_native.ps1

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not (Test-Path (Join-Path $root 'pubspec.yaml'))) {
    throw 'Скрипт должен лежать в папке tool проекта'
}
$native = Join-Path $root 'native'
$cargoBin = Join-Path $env:USERPROFILE '.cargo\bin'
$cargo = Join-Path $cargoBin 'cargo.exe'
$rustup = Join-Path $cargoBin 'rustup.exe'

function Write-Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }

if (-not (Test-Path $cargo)) {
    throw 'Rust не найден. Установите: winget install Rustlang.Rustup'
}

Write-Step 'Цели Rust'
& $rustup target add x86_64-pc-windows-msvc aarch64-linux-android armv7-linux-androideabi x86_64-linux-android
if ($LASTEXITCODE -ne 0) { throw 'не удалось добавить цели rustup' }

Write-Step 'Windows x64'
Push-Location $native
try {
    & $cargo build --release
    if ($LASTEXITCODE -ne 0) { throw 'сборка под Windows завершилась ошибкой' }
} finally { Pop-Location }

$dll = Join-Path $native 'target\release\menzulka_cad.dll'
$winDir = Join-Path $native 'windows'
New-Item -ItemType Directory -Force -Path $winDir | Out-Null
Copy-Item $dll (Join-Path $winDir 'menzulka_cad.dll') -Force
Write-Host "DLL: $(Join-Path $winDir 'menzulka_cad.dll')"

Write-Step 'cargo-ndk'
if (-not (Test-Path (Join-Path $cargoBin 'cargo-ndk.exe'))) {
    & $cargo install cargo-ndk
    if ($LASTEXITCODE -ne 0) { throw 'не удалось установить cargo-ndk' }
}
$env:PATH = "$cargoBin;$env:PATH"

if (-not $env:ANDROID_NDK_HOME) {
    $ndkRoot = Join-Path $env:LOCALAPPDATA 'Android\Sdk\ndk'
    if (Test-Path $ndkRoot) {
        $env:ANDROID_NDK_HOME = (Get-ChildItem $ndkRoot -Directory |
            Sort-Object Name -Descending | Select-Object -First 1).FullName
    }
}
if (-not $env:ANDROID_NDK_HOME) { throw 'не найден Android NDK (ANDROID_NDK_HOME)' }
Write-Host "NDK: $env:ANDROID_NDK_HOME"

Write-Step 'Android (arm64-v8a, armeabi-v7a, x86_64)'
$jniLibs = Join-Path $root 'android\app\src\main\jniLibs'
Push-Location $native
try {
    & $cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -o $jniLibs build --release
    if ($LASTEXITCODE -ne 0) { throw 'сборка под Android завершилась ошибкой' }
} finally { Pop-Location }

Write-Step 'Готово'
Get-ChildItem $jniLibs -Recurse -Filter '*.so' -ErrorAction SilentlyContinue |
    ForEach-Object { "{0}  ({1:N1} MB)" -f $_.FullName.Replace("$root\", ''), ($_.Length / 1MB) }
