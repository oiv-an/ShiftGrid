# ShiftGrid Privacy

ShiftGrid is local-only software.

## Data collection

ShiftGrid does not collect, transmit, sell or share personal data. It contains
no analytics, advertising, crash-reporting SDK, telemetry or network requests.

## Accessibility permission

macOS Accessibility permission is required to:

- identify the topmost window under the pointer;
- read whether that window can be moved and resized;
- change its position and size;
- observe the global keyboard and pointer events needed to recognize and cancel
  the activation gesture.

Keyboard text, window contents and pointer history are not stored or sent
anywhere.

## Local storage

The only persisted data is stored in macOS `UserDefaults` under the bundle
identifier `app.ivol.ShiftGrid`: layout mode, selection method, spacing and a
settings migration revision. Removing the app does not automatically delete
these preferences.

---

# Конфиденциальность ShiftGrid

ShiftGrid работает только локально. Приложение не собирает и не передаёт данные,
не содержит аналитики, рекламы, телеметрии и сетевых запросов.

«Универсальный доступ» используется для определения верхнего окна под курсором,
проверки возможности изменить его размер, перемещения окна и распознавания
глобального жеста клавиатуры и мыши. Текст нажатых клавиш, содержимое окон и
история движений курсора не сохраняются и никуда не отправляются.

Локально в `UserDefaults` сохраняются только режим разметки, способ выбора,
размер отступов и номер миграции настроек.
