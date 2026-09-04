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

1. Open the [latest GitHub Release](https://github.com/oiv-an/ShiftGrid/releases/latest)
   and download the DMG marked as the recommended macOS installer. Do not use
   the automatically generated `Source code` archives.
2. Open the DMG and drag `ShiftGrid.app` onto the **Applications** shortcut in
   the installer window.
3. Wait for the copy to finish, eject the ShiftGrid disk image, and launch
   ShiftGrid from the Applications folder. Its three-column icon appears in
   the menu bar.
4. If macOS blocks the first launch, open **System Settings → Privacy &
   Security**, find the ShiftGrid message and click **Open Anyway**. Then
   launch ShiftGrid again from Applications.
5. In the ShiftGrid menu, open **Settings…**, then enable ShiftGrid in
   **System Settings → Privacy & Security → Accessibility**.

If the DMG cannot be opened, download the ZIP from the same release page,
unzip it, and move `ShiftGrid.app` to Applications before launching it.

### Gatekeeper notice

Current builds are ad-hoc signed and are not Apple-notarized because a
Developer ID certificate is not configured yet. The DMG makes installation
more convenient but does not remove the first-launch warning. Ad-hoc-signed
updates may also require Accessibility permission to be enabled again.

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

To create the same DMG, fallback ZIP and checksums used by GitHub Releases,
install the pinned packaging tools with Python 3.10 or later:

```sh
python3 -m venv .build/release-venv
.build/release-venv/bin/python -m pip install --requirement Scripts/requirements-release.txt
DMGBUILD_EXECUTABLE=.build/release-venv/bin/dmgbuild \
    CODE_SIGN_IDENTITY=- ./Scripts/package-release.sh
```

For a notarized distribution, use a Developer ID Application identity,
hardened runtime, secure timestamp and Apple's notarization service.

## Privacy and limitations

See [PRIVACY.md](PRIVACY.md) for the exact permissions and local data use.

- Full-screen windows and some system windows cannot be resized through the
  Accessibility API.
- Apps with fixed or large minimum window sizes may adjust the requested frame.
- ShiftGrid has no launch-at-login option, auto-updater or localization yet;
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

1. Откройте [страницу последнего релиза](https://github.com/oiv-an/ShiftGrid/releases/latest)
   и скачайте DMG, отмеченный как рекомендуемый установщик для macOS.
   Архивы `Source code` не содержат готового приложения.
2. Откройте DMG и перетащите `ShiftGrid.app` на ярлык **Applications**
   в окне установщика.
3. Дождитесь копирования, извлеките диск ShiftGrid и запустите
   ShiftGrid из папки «Программы». В верхней строке меню появится иконка
   с тремя колонками.
4. Если macOS заблокирует первый запуск, откройте **Системные настройки →
   Конфиденциальность и безопасность**, найдите сообщение о ShiftGrid и
   нажмите **Всё равно открыть**. После этого ещё раз запустите ShiftGrid из
   папки «Программы».
5. Откройте **Настройки…** и включите ShiftGrid в разделе
   **Системные настройки → Конфиденциальность и безопасность → Универсальный
   доступ**.

Если DMG не открывается, скачайте ZIP с той же страницы релиза,
распакуйте его и перенесите `ShiftGrid.app` в папку «Программы» до запуска.

Текущие сборки подписаны ad-hoc и пока не нотарифицированы Apple. DMG
упрощает установку, но не убирает предупреждение при первом запуске. После
обновления macOS также может попросить включить «Универсальный доступ» повторно.

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
