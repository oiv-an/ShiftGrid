# ShiftGrid

Native menu-bar window tiling for macOS. ShiftGrid selects the topmost window
under the pointer and snaps it to one or two vertical zones with a left Shift
gesture.

[Download the latest release](https://github.com/oiv-an/ShiftGrid/releases/latest)
· [Русская инструкция](#русский)

## Features

- Two or three vertical zones, selected automatically from the display's
  physical pixel width or chosen manually.
- The window under the pointer is captured when the gesture begins.
- Hold-and-release workflow: tap left Shift once, press it again and hold,
  point to a zone, then release.
- An L-shaped gesture (up, then left or right) joins exactly two adjacent zones.
- Optional double-Shift and click workflow.
- Configurable 0–30 physical pixel gaps; 2 px by default.
- Correct handling of visible menu bar and Dock, auto-hidden Dock, multiple
  displays and displays with negative coordinates.
- A permanent menu-bar icon for settings; no Dock icon.
- No network requests, telemetry, analytics or third-party dependencies.

## Requirements

- macOS 13 or later.
- Apple Silicon or Intel Mac. Release archives contain a Universal 2 binary.
- Accessibility permission, used only to identify and resize windows and to
  observe the global activation gesture.

## Install

1. Download `ShiftGrid-0.1.0-macOS-universal.zip` from
   [GitHub Releases](https://github.com/oiv-an/ShiftGrid/releases), not the
   automatically generated source archive.
2. Unzip it and move `ShiftGrid.app` to `/Applications` before granting
   Accessibility permission.
3. Open ShiftGrid. Its three-column icon appears in the menu bar.
4. In the ShiftGrid menu, open **Settings…**, then enable ShiftGrid in
   **System Settings → Privacy & Security → Accessibility**.

### Gatekeeper notice for v0.1.0

The first public build is ad-hoc signed and is not Apple-notarized because a
Developer ID certificate is not configured yet. If macOS blocks the first
launch, open **System Settings → Privacy & Security**, find the ShiftGrid
message and click **Open Anyway**. Future ad-hoc-signed updates may require
Accessibility permission to be enabled again.

The SHA-256 checksum is published as `SHA256SUMS.txt` beside every release.

## Use

1. Point to the window you want to move.
2. Quickly press and release left Shift.
3. Press left Shift again and keep holding it.
4. Point to a zone and release Shift.

To span two zones, move upward inside the first zone and then turn into the
adjacent zone to the left or right. Release after the combined `1 + 2` or
`2 + 3` highlight appears.

Escape, another key, right click or scrolling cancels the overlay. The menu-bar
settings let you switch to the alternative double-Shift → point → click mode.

## Build from source

Xcode Command Line Tools are required.

```sh
swift test
./Scripts/build-app.sh
```

The app is created at `dist/ShiftGrid.app`. The build is Universal 2 by
default and uses an ad-hoc signature when no identity is configured. To keep a
stable local signature between builds, put the identity name or SHA-1 hash in
the ignored `.local-signing-identity` file, or set `CODE_SIGN_IDENTITY`.

To create the same archive and checksum used by GitHub Releases:

```sh
CODE_SIGN_IDENTITY=- ./Scripts/package-release.sh
```

For a notarized distribution, use a Developer ID Application identity,
hardened runtime, secure timestamp and Apple's notarization service.

## Privacy and limitations

See [PRIVACY.md](PRIVACY.md) for the exact permissions and local data use.

- Full-screen windows and some system windows cannot be resized through the
  Accessibility API.
- Apps with fixed or large minimum window sizes may adjust the requested frame.
- Version 0.1.0 has no launch-at-login option, auto-updater or localization;
  the interface is currently Russian.

---

## Русский

ShiftGrid — нативное приложение для macOS, которое живёт в строке меню,
выбирает верхнее окно под курсором и раскладывает его по вертикальным областям.

### Возможности

- На дисплеях шириной от 3000 физических пикселей автоматически показываются
  три области, на меньших — две. В настройках можно принудительно выбрать 2 или
  3 области.
- Окно выбирается под курсором в момент начала жеста.
- Две соседние области объединяются Г-жестом: сначала вверх, затем влево или
  вправо.
- Отступы настраиваются от 0 до 30 физических пикселей; по умолчанию — 2 px.
- Учитываются видимые строка меню и Dock, автоматически скрытый Dock и
  несколько мониторов.
- Настройки открываются через иконку из трёх колонок в верхней строке меню;
  значка в Dock нет.

### Установка

1. Скачайте `ShiftGrid-0.1.0-macOS-universal.zip` в разделе
   [Releases](https://github.com/oiv-an/ShiftGrid/releases). Архивы
   `Source code` не содержат готового приложения.
2. Распакуйте архив и перенесите `ShiftGrid.app` в `/Applications` до выдачи
   разрешения.
3. Запустите ShiftGrid. В верхней строке меню появится иконка с тремя колонками.
4. Откройте **Настройки…** и включите ShiftGrid в разделе
   **Системные настройки → Конфиденциальность и безопасность → Универсальный
   доступ**.

Первая публичная версия подписана ad-hoc и пока не нотарифицирована Apple. Если
macOS заблокирует первый запуск, откройте **Системные настройки →
Конфиденциальность и безопасность**, найдите сообщение о ShiftGrid и нажмите
**Открыть всё равно**. После обновления macOS может попросить включить
«Универсальный доступ» повторно.

### Использование

1. Наведите курсор на нужное окно.
2. Быстро нажмите и отпустите левый Shift.
3. Нажмите левый Shift второй раз и удерживайте.
4. Наведите курсор на область и отпустите Shift.

Для двух областей проведите вверх внутри первой области, затем поверните в
соседнюю влево или вправо. Отпустите Shift после общей подсветки `1 + 2` или
`2 + 3`.

Через настройки можно включить другой режим: двойной левый Shift, наведение и
щелчок. `Esc`, другая клавиша, правый клик или прокрутка отменяют выбор.

ShiftGrid не отправляет данные, не использует аналитику и хранит настройки
только локально. Подробности находятся в [PRIVACY.md](PRIVACY.md).
