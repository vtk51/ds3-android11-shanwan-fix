# DS3 Android 11 SHANWAN fix

Исправление Bluetooth для SHANWAN/совместимых клонов DualShock 3 на **одном
подтверждённом профиле Android 11**. Проверенный USB VID:PID: `054c:0268`.
Решение **не универсальное**. Неподдерживаемая прошивка возвращает `UNSUPPORTED`
до изменений устройства. Текущий профиль требует root, Magisk 24.3 / `24300`,
включённый Zygisk API v3, 32-битный Bluetooth userspace (`armeabi-v7a`) и
подтверждённую среду SELinux `Permissive`. Новая SELinux policy не поставляется.

> **1.0.0: включён одобренный publication-safe rev7 production payload.**
> Точный SHA256: `e4183947d3ef3917b4b8cc261b3a869e6190aedcd59c87728b24061a578447cf`.
> Approval: `PRODUCTION_APPROVED_PUBLICATION_SAFE_REV7`; контролируемая live
> acceptance PASS. Сохранены независимый project SHA-256 и digest-only
> validation. Происхождение: [docs/PROVENANCE.md](docs/PROVENANCE.md).

## Подтверждённый результат

Этот точный бинарник прошёл Bluetooth connection, `sony_probe`, регистрацию input
и одно нажатие/отпускание Cross / `BTN_SOUTH` (`0x0130` / `304`); crash count
Bluetooth и tombstones не изменились. Reconnect/reply logic сохранена из
проверенной lineage; отдельный reconnect-тест финального бинарника не заявляется.
Публичные install/rollback transactions проверены offline; их полная live
приёмка на устройстве не заявляется.
**Индикаторы 1/2/3/4 могут продолжать медленно мигать**, не показывая номер игрока.
Это известная нерешённая косметическая проблема; её исправление в релиз не входит.

## Архитектура

```text
USB 054c:0268 -- MANUAL_GATE: master-BDADDR/readback --> Bluetooth адаптер
                              |
существующий допущенный bond --> cached HID (app=6, mask=117, 148 bytes)
                              |
stock с устройства --> Site B transform --> Magisk overlay
                              |
DS3 BR/EDR --> Android HID --> UHID SET --> production rev7 pending/completion
                              |                         |
                              +<--- matching SET reply -+
                              |
                     hid-sony --> SHANWAN input --> Cross
```

Site B затрагивает **все входящие bonded HID**, проходящие эту функцию Android,
а не только DS3: атрибут требования HID security заменяется на virtual-cable.
Отдельная проверка допуска входящего соединения по bond глобально не отключается.

## Требования и подготовка

* Windows PowerShell 5.1+ или PowerShell 7; собственные Android platform-tools,
  `adb` в PATH. ADB, прошивка и ремонтные бинарники не включены.
* Одно авторизованное ADB-устройство; для явного выбора используйте
  `-Serial <ADB_SERIAL>`. Доступ ADB/root должен сохраняться после перезагрузки.
* Точное совпадение fingerprint, API, ARM32 процесса, размера библиотеки, BuildID,
  stock SHA256, Site B и hook fingerprints с `profiles/ohm-api30-arm32.json`.
* Bluetooth включён, Magisk mirror и busybox исправны, Zygisk включён.
  Неизвестные версии Magisk получают `UNSAFE_STATE`; автоматического старого
  ремонта нет. Прошивка с другим SELinux окружением требует отдельного профиля.
* Ровно одна существующая секция SHANWAN с ранее установленным допуском bond:
  `LinkKeyType=4`, `LinkKey` из 32 hex-символов. USB cable setup сам по себе не
  создаёт нормальный BR/EDR bond. Старые ключи разработческого устройства не
  распространяются, новые неподтверждённые ключи не генерируются. Отсутствующая
  или неоднозначная запись означает manual gate / `UNSAFE_STATE`.
* USB master setup выполняется независимым доверенным DS3 pairing-инструментом:
  обнаружить `054c:0268`, прочитать текущий master BDADDR, изменить только при
  отличии от настоящего Bluetooth MAC приставки, проверить readback. В проекте
  не найден пригодный доказанный USB writer с установленным происхождением.
  Поэтому предусмотрен `MANUAL_GATE`: ввести MAC приставки после независимой
  проверки readback. Не подтверждайте значение без чтения с контроллера.

## Обычная установка

```powershell
.\scripts\install.ps1 -DryRun
.\scripts\install.ps1
```

`-DryRun` только читает состояние, классифицирует и показывает план. Нет записей
установщика: push/pull, backup, pairing, изменения config/modules, reboot.
ADB/root могут вести обычные системные журналы. `preflight.ps1` возвращает одно
из `SUPPORTED`, `ALREADY_INSTALLED`, `UNSUPPORTED`, `UNSAFE_STATE`. Совместимость
устройства и разрешение поставки payload — разные проверки: даже `SUPPORTED`
дополняется проверкой точного одобренного payload из пакета.

Предусмотренный процесс: compatibility checks → проверенный backup → ручная
проверка USB master → atomic cached HID merge → оба модуля → on-device checksums
→ **ровно одна обычная перезагрузка** → ограниченное ожидание ADB/root → проверки
Magisk/Zygisk, Magic Mount, STG0–STG5 текущего boot, I00–I13 (PID Bluetooth в
I00/I01, остальные completion stages — с проверкой свежести текущего boot),
здоровья Bluetooth → пауза для одного P3/PS → SHANWAN main/motion inputs.
`-CrossTest` включает ограниченный 30 секундами `getevent` для одного Cross
press/release. `ALREADY_INSTALLED` выполняет только verify, без reboot. При ошибке
нет повторных перезагрузок или автоматического rollback.

```powershell
.\scripts\preflight.ps1
.\scripts\verify.ps1 -AskP3 -CrossTest
.\scripts\collect-diagnostics.ps1
```

Диагностика сохраняет только сведения для нового профиля: API/build, ABI,
архитектуру/maps Bluetooth, SHA256/BuildID/signatures библиотеки, Magisk/Zygisk
и нужные DS3 input observations. Полные Bluetooth config, logcat, unrelated logs,
serial и crash dumps не собираются. Перед передачей просмотрите результат.

## Backup и rollback

Транзакции timestamp/GUID сохраняются в `/data/adb/ds3-fix/transactions/` и
`%LOCALAPPDATA%/DS3Fix/backups/`. Manifest включает наличие config/modules,
рекурсивные хеши обычных файлов, mode/owner/context, SHA256 архива, stock identity
и метаданные транзакции. До продолжения архив независимо распаковывается и
проверяется по хешам; затем проверяется копия на ПК. Ошибка backup останавливает
установку. Backup содержит вашу Bluetooth-конфигурацию: храните его приватно,
не добавляйте backup, созданные библиотеки или диагностику в публичный репозиторий.

```powershell
.\scripts\rollback.ps1 -Transaction <TRANSACTION_ID> -DryRun
.\scripts\rollback.ps1 -Transaction <TRANSACTION_ID>
```

Восстанавливается выбранная транзакция: Bluetooth config, состояния
`ds3-hid-nosec` и `ds3-uhid-hook`, включая прежнее отсутствие каталогов,
mode/owner/context. Удаляются lock/temp config установщика, проверяются хеши,
запрашивается одна перезагрузка. Backup не перезаписывается. Автоматического
выбора «последнего» backup нет. USB master — внешний ручной шаг: при необходимости
верните прежнее значение доверенным инструментом. Если ADB потерян, нужен доступ
recovery для отключения модулей; см. troubleshooting.

## Контрольные суммы и офлайн-проверки

| Артефакт | SHA256 |
|---|---|
| Stock `libbluetooth.so`, не поставляется | `153cb547688608e4070276e1f688d37a8eecb9146c491a34e3d5e793f7763caa` |
| Локальный overlay, не поставляется | `68249b8126a3160fdf17a93b464762d8517cea2d25c125aacb4fddb47fddb86c` |
| Одобренный publication-safe rev7, включён | `e4183947d3ef3917b4b8cc261b3a869e6190aedcd59c87728b24061a578447cf` |

```powershell
.\tests\run.ps1
.\tests\run.ps1 -RequirePublishable
```

Первый запуск проверяет автоматизацию, целостность и чистоту офлайн без устройства.
Второй дополнительно проверяет одобренный production payload и provenance.
GitHub Actions не требует Android или ADB credentials. `CHECKSUMS.txt`
проверяет поставляемые файлы, кроме самого себя. SHA256 ZIP записан в соседний
дистрибутивный `CHECKSUMS.txt`: включение хеша ZIP внутрь этого ZIP создало бы
циклическую зависимость. Тесты распакованного архива требуют только PowerShell
и файлов пакета.

Payload прошёл offline provenance/regressions и live acceptance точного SHA.
Финальная упаковка выполнена offline без rebuild/deployment. ZIP создан заново
из чистого public tree; GitHub publication — отдельный шаг. Project contributions имеют
MIT notice, сторонние компоненты сохраняют свои лицензии: см. `LICENSE` и
[docs/PROVENANCE.md](docs/PROVENANCE.md).

Дополнительно: [TECHNICAL.md](docs/TECHNICAL.md), [PORTING.md](docs/PORTING.md),
[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md), [KNOWN_ISSUES.md](docs/KNOWN_ISSUES.md).
