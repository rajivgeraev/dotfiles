# Восстановление настроек клавиатуры (Karabiner-Elements) после переустановки macOS

Документ описывает, как с нуля восстановить текущую настройку клавиатуры. Три независимых правила:

1. **Переключение раскладки**: тап левого Cmd → английская раскладка, тап правого Cmd → русская. Обе операции идемпотентны (повторный тап не переключает обратно — это абсолютное присваивание раскладки, а не тумблер).
2. **Caps Lock полностью отключён** (не переключает регистр, не подсвечивается).
3. **Яркость подсветки клавиатуры**: `⌥+F1` — уменьшить, `⌥+F2` — увеличить (на текущих MacBook эти клавиши по умолчанию заняты под Dictation/Do Not Disturb, штатного способа управлять подсветкой с клавиатуры нет).

Актуально на момент написания: MacBook Pro (Mac15,10, Apple M3 Max, arm64), macOS 26.6.1, Karabiner-Elements 16.1.0, встроенная клавиатура ANSI (US).

✅ **Этот файл живёт в репозитории дотфайлов** (`~/.local/share/chezmoi/karabiner-recovery.md`) — переживает переустановку macOS вместе с остальным репозиторием, при условии что коммит с ним запушен в `origin/main` (проверить: `git -C "$(chezmoi source-path)" status`, ветка не должна быть "ahead of origin"). Сам конфиг (`karabiner.json`) тоже управляется через chezmoi (`dot_config/private_karabiner/private_karabiner.json`) — `chezmoi apply` кладёт его на место автоматически. Разделы ниже (выдача разрешений в System Settings, добавление раскладки) всё равно требуют ручных действий — автоматизировать их нельзя.

---

## Шаг 0. Что вообще происходит под капотом

Karabiner-Elements ставит:
- root-демон, монопольно перехватывающий физическую клавиатуру и создающий виртуальную (через DriverKit-расширение `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice`);
- пользовательский агент (`karabiner_console_user_server`), который применяет активный профиль из `~/.config/karabiner/karabiner.json` и умеет переключать системный источник ввода (`select_input_source`) — именно этим достигается идемпотентность переключения раскладки.

Никакой kanata/macism в этой схеме не участвует — заменены на штатный механизм Karabiner-Elements.

**Важно про Caps Lock**: пока Karabiner-Elements работает, он эксклюзивно захватывает физическую клавиатуру, из-за чего нативная настройка **System Settings → Keyboard → Modifier Keys → Caps Lock → No Action** перестаёт действовать (задокументированный конфликт: https://github.com/pqrs-org/Karabiner-Elements/issues/194). Поэтому Caps Lock отключён именно правилом внутри `karabiner.json` (`simple_modifications` + `vk_none`), а не через System Settings — трогать нативную настройку не нужно, пусть остаётся в состоянии по умолчанию ("Caps Lock ⇪").

---

## Шаг 1. Установить Homebrew (если его тоже смыло переустановкой)

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
Официальная инструкция: https://brew.sh

---

## Шаг 2. Установить Karabiner-Elements

```sh
brew install --cask karabiner-elements
```
Это официальный cask, устанавливает тот же `.pkg`, что и на сайте karabiner-elements.pqrs.org. Альтернатива — скачать `.dmg` вручную с https://karabiner-elements.pqrs.org и запустить `Karabiner-Elements.pkg` — результат идентичен.

Установщик попросит пароль администратора — это нормально, без этого никак.

---

## Шаг 3. Запустить приложение один раз

```sh
open -a "Karabiner-Elements"
```
или через Launchpad/Spotlight. Это нужно, чтобы демоны зарегистрировались и система показала запросы на разрешения.

---

## Шаг 4. Выдать разрешения (руками, через System Settings — не автоматизируется)

1. **System Settings → Privacy & Security → Accessibility** → включить Karabiner-Elements (и связанные пункты, если появятся отдельно).
   - *Input Monitoring трогать не нужно* — начиная с Karabiner-Elements 16.0.0 это разрешение поглощено Accessibility и отдельно не запрашивается (официально задокументировано: https://karabiner-elements.pqrs.org/docs/manual/misc/required-macos-settings/).
2. **System Settings → General → Login Items & Extensions → Driver Extensions** → включить `org.pqrs.Karabiner-DriverKit-VirtualHIDDevice`.
3. Проверить активацию драйвера:
   ```sh
   systemextensionsctl list | grep -i pqrs
   ```
   Ожидаемый вывод — строка со статусом `[activated enabled]`.
4. Проверить, что демоны реально работают:
   ```sh
   launchctl print system/org.pqrs.service.daemon.Karabiner-Core-Service | head -5
   launchctl print gui/$(id -u)/org.pqrs.service.agent.karabiner_console_user_server | head -5
   ```
   В обоих выводах должно быть `state = running`, а не "Could not find service".
5. При первом обнаружении встроенной клавиатуры Karabiner может спросить тип клавиатуры — выбрать **ANSI**.

---

## Шаг 5. Добавить русскую раскладку в систему

Свежая macOS после установки знает только English. Правило ниже завязано на конкретный идентификатор `com.apple.keylayout.RussianWin` — это **не** тот вариант, что называется просто "Russian" в списке, а вариант **"Russian - PC"**. Важно выбрать именно его, иначе regex в правиле ни на что не сработает и переключение будет молча ничего не делать.

1. **System Settings → Keyboard → Input Sources → Edit… → "+"**
2. Найти **Russian → Russian - PC** (не просто "Russian") → Add.
3. Английская (`U.S.`) обычно уже стоит по умолчанию — проверить, что она в списке.
4. Проверить итоговые идентификаторы командой:
   ```sh
   defaults read com.apple.HIToolbox AppleEnabledInputSources
   ```
   Должны быть записи `"KeyboardLayout Name" = "U.S."` и `"KeyboardLayout Name" = RussianWin`. Если у RussianWin вдруг другое имя/ID — см. Шаг 7 (как поправить конфиг под другой идентификатор).
5. **System Settings → Keyboard** → выключить **"Automatically adjust keyboard brightness in low light"**. Это отдельная настройка, не связанная с раскладкой, но нужна для корректной работы правила подсветки клавиатуры (Шаг 6) — без её отключения regulировка яркости периодически не срабатывает (показывает 🚫), это задокументированный баг: https://github.com/pqrs-org/Karabiner-Elements/issues/2645

---

## Шаг 6. Восстановить конфиг-файл

Этот файл управляется через chezmoi (`dot_config/private_karabiner/private_karabiner.json` в репозитории дотфайлов) — `chezmoi apply` кладёт его на место автоматически вместе с остальными конфигами, вручную создавать ничего не нужно. Ниже — содержимое на случай восстановления в обход chezmoi (вручную создать `~/.config/karabiner/karabiner.json`; директория создастся автоматически при первом запуске приложения, если её нет — `mkdir -p ~/.config/karabiner`):

```json
{
    "profiles": [
        {
            "complex_modifications": {
                "rules": [
                    {
                        "description": "Left Command (tap) -> English, Right Command (tap) -> Russian",
                        "manipulators": [
                            {
                                "from": {
                                    "key_code": "left_command",
                                    "modifiers": { "optional": ["any"] }
                                },
                                "to": [
                                    {
                                        "key_code": "left_command",
                                        "lazy": true
                                    }
                                ],
                                "to_if_alone": [{ "select_input_source": { "input_source_id": "^com\\.apple\\.keylayout\\.US$" } }],
                                "type": "basic"
                            },
                            {
                                "from": {
                                    "key_code": "right_command",
                                    "modifiers": { "optional": ["any"] }
                                },
                                "to": [
                                    {
                                        "key_code": "right_command",
                                        "lazy": true
                                    }
                                ],
                                "to_if_alone": [{ "select_input_source": { "input_source_id": "^com\\.apple\\.keylayout\\.RussianWin$" } }],
                                "type": "basic"
                            }
                        ]
                    },
                    {
                        "description": "Option+F1 / Option+F2 -> keyboard backlight brightness",
                        "manipulators": [
                            {
                                "from": {
                                    "key_code": "f1",
                                    "modifiers": { "mandatory": ["left_option"] }
                                },
                                "to": [ { "key_code": "illumination_decrement" } ],
                                "type": "basic"
                            },
                            {
                                "from": {
                                    "key_code": "f2",
                                    "modifiers": { "mandatory": ["left_option"] }
                                },
                                "to": [ { "key_code": "illumination_increment" } ],
                                "type": "basic"
                            }
                        ]
                    }
                ]
            },
            "name": "Default profile",
            "selected": true,
            "simple_modifications": [
                {
                    "from": { "key_code": "caps_lock" },
                    "to": [ { "key_code": "vk_none" } ]
                }
            ],
            "virtual_hid_keyboard": { "keyboard_type_v2": "ansi" }
        }
    ]
}
```

Файл читается фоновыми сервисами автоматически (file-watch), перезапускать приложение или демоны не нужно — достаточно сохранить файл. Проверить валидность JSON после сохранения:
```sh
python3 -m json.tool ~/.config/karabiner/karabiner.json > /dev/null && echo OK
```

---

## Шаг 7. Если идентификаторы раскладок отличаются от указанных выше

Возможно, после переустановки другая версия macOS назовёт источник ввода иначе. Проверить фактический ID:
```sh
/usr/bin/defaults read com.apple.HIToolbox AppleEnabledInputSources
```
и подставить актуальные значения `KeyboardLayout Name` в `input_source_id` внутри JSON (формат обычно `com.apple.keylayout.<Name>`).

Аналогично, если `f1`/`f2` не срабатывают в правиле подсветки — открыть **Karabiner-EventViewer** (ставится вместе с приложением), нажать F1/F2 без Option и проверить, каким именно key_code они фактически долетают, затем поправить `"key_code"` в правиле.

---

## Шаг 8. Финальная проверка

1. Открыть любое текстовое поле.
2. Тапнуть **левый Cmd** (быстро, без удержания) → раскладка переключается на английскую. Тапнуть ещё раз подряд → должна остаться английской (идемпотентность).
3. Тапнуть **правый Cmd** → раскладка переключается на русскую, повторный тап — остаётся русской.
4. Проверить, что `Cmd+C`, `Cmd+Tab`, `Cmd+Space` работают как обычно (подтверждает, что `lazy`-модификатор не сломан и обычные сочетания с Cmd не пострадали).
5. Нажать **Caps Lock** → ничего не должно происходить (ни регистр, ни подсветка клавиши).
6. Нажать **⌥+F1** → подсветка клавиатуры тускнеет; **⌥+F2** → ярче. Если не работает — проверить, что выключена "Automatically adjust keyboard brightness in low light" (Шаг 5.5).

---

## Если что-то не работает — куда смотреть

- Официальный раздел Troubleshooting: https://karabiner-elements.pqrs.org/docs/help/troubleshooting/
- "Driver alert keeps showing up": https://karabiner-elements.pqrs.org/docs/help/troubleshooting/driver-alert-keeps-showing-up/
- Требуемые настройки macOS (разрешения): https://karabiner-elements.pqrs.org/docs/manual/misc/required-macos-settings/
- Синтаксис `complex_modifications` / `select_input_source`: https://karabiner-elements.pqrs.org/docs/json/complex-modifications-manipulator-definition/to/
- Caps Lock не отключается через System Settings, пока работает Karabiner: https://github.com/pqrs-org/Karabiner-Elements/issues/194
- Подсветка клавиатуры показывает 🚫 / не срабатывает: https://github.com/pqrs-org/Karabiner-Elements/issues/2645

Ключевые команды диагностики:
```sh
ps aux | grep -i karabiner                  # процессы должны быть запущены
systemextensionsctl list | grep -i pqrs      # драйвер должен быть [activated enabled]
launchctl print gui/$(id -u)/org.pqrs.service.agent.karabiner_console_user_server
```
