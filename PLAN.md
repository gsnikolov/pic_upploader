# План: Ray-Ban Meta Gen 2 → снимка → Google Drive (само с iPhone)

## Цел
Снимка от очилата да стигне в папка в Google Drive **без ръчния импорт в Meta AI**,
без Mac и без пари.

```
Очила ──DAT (Bluetooth/Wi‑Fi)──► GlassesToDrive app на iPhone ──► Files: Google Drive/Glasses ──► Google Drive cloud
```

## Архитектура
| Част | Технология | Бележка |
|---|---|---|
| iOS app | Fork на `CameraAccess` sample-а на Meta (SwiftUI, DAT SDK) | `MWDATCore`, `MWDATCamera` през SPM |
| Запис в Drive | `DriveFolderStore`: security-scoped bookmark + `NSFileCoordinator` | Без OAuth; иска инсталирано приложение Google Drive |
| Build | GitHub Actions, `macos-26`, unsigned `.ipa` | Безплатно за public repo; за private ~200 macOS мин./месец |
| Инсталиране | SideStore + LocalDevVPN, безплатен Apple ID | Подновяване на 7 дни, от самия телефон |

---

## Фаза 0: Repo ✅ (подготвено)
- [x] Fork на `CameraAccess` с `DriveFolderStore` и бутон за избор на папка
- [x] `.github/workflows/build-ipa.yml`
- [x] `CLAUDE.md`, `PLAN.md`

## Фаза 1: Зелен CI build
**Задачи (Claude):**
1. Push към `main` → проследяване на workflow-а (`gh run watch`).
2. Оправяне на compile грешки, ако има: Swift 6 concurrency, липсващи imports, версия на Xcode.
3. Ако `macos-26` или `latest-stable` Xcode е под 26.4, да се избере конкретна версия в `setup-xcode`.

**Готово, когато:** run-ът е зелен и в release `latest-build` има asset `GlassesToDrive.ipa`.

## Фаза 2: Инсталиране и първи тест (Георги)
**Еднократна подготовка на SideStore:**
1. На iPhone-а: App Store → **LocalDevVPN** → Connect.
2. Pairing file + инсталиране на SideStore:
   - стандартният път е **iloader** на Windows или Linux (веднъж, с кабел);
   - ако iPhone-ът е на iOS 27, провери дали вече има on-device pairing (напр. SideInstaller), тогава компютър не трябва.
3. Settings → General → VPN & Device Management → Trust за Apple ID-то; Settings → Privacy & Security → Developer Mode → On.

**Инсталиране на приложението:**
1. На iPhone-а отвори release `latest-build` в GitHub → изтегли `GlassesToDrive.ipa`.
2. Files → `.ipa` → Share → SideStore. Може и SideStore → My Apps → `+` → избираш файла.
3. Meta AI app → Settings → App Info → 5 пъти върху версията → **Developer Mode ON**. Софтуерът на очилата трябва да е v20+.

**Тест (acceptance):**
- [ ] Connect → пренасочване към Meta AI → връщане → registered
- [ ] Start session → Preview → виждаш картина от очилата
- [ ] Бутон с папка → Google Drive → папка `Glasses` → бутонът става зелен
- [ ] Бутон с камера → „Saved glasses_….jpg“ → файлът се появява в drive.google.com до ~1 мин.

**Ако нещо се счупи** → прати на Claude screenshot или текста на грешката.

## Фаза 3: Снимане с физическия бутон на очилата (Inputs)
DAT има експериментална функция **Inputs**: събитие `.capture(pressType, …)` при натискане на бутона за снимка.

**Предусловия (Георги, в браузъра на iPhone-а):**
1. https://wearables.developer.meta.com → създаваш app (безплатно).
2. Включваш **Inputs** и **Camera** за приложението.
3. В GitHub repo → Settings → Secrets → Actions: `META_APP_ID`, `CLIENT_TOKEN`.

**Задачи (Claude):**
1. В `CameraViewModel`: след `sessionState == .started` → `session.addInputs(configuration: InputsConfiguration(consumeBack: false))`, а в `Task` → `for await event in inputs.events`.
2. При `.capture`: ако няма активен stream, стартирай го и изчакай `.streaming`, после `capturePhoto()`.
3. Cleanup: cancel на task-а, `session.removeInputs()` при край на сесията.
4. Обработка на грешка `InputsError.permissionDenied` → ясно съобщение („Inputs не е одобрен в Developer Center“).
5. Проверка в docs-а дали `MetaAppID` и `TeamID` трябва да съвпадат с подписа от SideStore (bundle ID-то се променя при SideStore).

**Готово, когато:** натискане на бутона на очилата с отворено приложение → файл в Drive.

**Рискове:**
- Inputs може да изисква attestation, което не минава със SideStore подпис. Тогава fallback е Фаза 4.
- Не е ясно дали `.capture` спира и вградената снимка на очилата. Ще се провери на живо.

## Фаза 4 (по желание): удобство
- **Voice Invocations**: „Hey Meta, start <app>“ отваря приложението и автоматично стартира session + stream.
- Автоматичен старт на session и stream при отваряне на приложението, а след първото избиране на папка без допълнителни натискания.
- Haptic или звуков сигнал при успешен запис.
- Опит сесията да остане жива във фонов режим (sample-ът нарочно я спира; да се провери дали DAT го поддържа).

## Фаза 5 (по-късно): pipeline към Claude
Drive папка → Java/Spring Boot (Drive API `changes.watch` или Drive for Desktop + `WatchService`) → Claude API → Telegram.
Извън обхвата на това repo.

---

## Известни ограничения
- Приложението трябва да е **отворено на преден план**, докато снимаш (поведение на sample-а).
- 7-дневно подновяване през SideStore: LocalDevVPN трябва да е включен при refresh.
- Unsigned build-ът няма entitlements (`HotspotConfiguration`, `wifi-info`), така че DAT вероятно ще ползва Bluetooth вместо Wi‑Fi. Stream-ът и снимките трябва да работят, но по-бавно. Проверява се във Фаза 2.
- Upload-ът зависи от синхронизацията на приложението Google Drive, която понякога закъснява.
