# Версионирование и git

## Ветки

- `main` — стабильная линия, только проверенные релизы.
- `feature/<кратко>` — новая функциональность (например, `feature/dwg-import`),
  вливается в `main` через `git merge --no-ff`.
- `fix/<кратко>` — исправления.
- `hotfix/<кратко>` — правки уже выпущенной версии (по необходимости).

## Коммиты — Conventional Commits

`<type>(<scope>): <краткое описание>`

| type | Назначение |
|---|---|
| `feat` | новая функциональность |
| `fix` | исправление |
| `refactor` | рефакторинг без изменения поведения |
| `perf` | производительность |
| `docs` | документация |
| `test` | тесты |
| `chore` | сборка, зависимости, настройки |
| `build`, `ci` | по необходимости |

Пример: `feat(measurements): подписи длин на каждой стороне`.

Шаблон сообщения — `.gitmessage` (подключён через `git config commit.template .gitmessage`).

## Версии — SemVer

`MAJOR.MINOR.PATCH`:
- **MAJOR** — несовместимые изменения (например, формат `.abris`);
- **MINOR** — новая функциональность;
- **PATCH** — исправления.

Версия задаётся в `pubspec.yaml`: `version: 1.0.0+1`
(`+N` — `versionCode` для Android, увеличивать при каждой публикации в магазин).

Релиз помечается аннотированным тегом:

```bash
git tag -a v1.0.0 -m "v1.0.0"
git push origin main --tags
```

## Релизный цикл

1. Обновить `CHANGELOG.md`: `[Unreleased]` → `[X.Y.Z] — дата`.
2. Обновить `version` в `pubspec.yaml`.
3. `flutter analyze` и `flutter test`.
4. Собрать артефакты:
   ```bash
   flutter build apk --release
   flutter build windows --release
   iscc installer/windows_installer.iss
   ```
5. Закоммитить: `release: vX.Y.Z`.
6. Поставить тег `vX.Y.Z` и запушить с тегами.
7. Приложить файлы из `dist/` к релизу на хостинге (GitHub Releases).

## Правила

- В репозиторий не коммитятся: `dist/`, `build/`, `.dart_tool/`, `.gradle/`,
  `windows/flutter/ephemeral/`, `*.iml`, `local.properties`.
- Секреты и ключи: `android/key.properties`, `*.jks`, `*.keystore` — только локально.
- Большие бинарники (APK/EXE) — только в релизах, не в истории git.
- Одна задача — одна ветка/один логический коммит; перед пушем — `flutter analyze` + `flutter test`.
