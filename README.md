# AllerScan

**Smart Allergy Ingredient Checker — iOS**

AllerScan helps people with food allergies make safe consumption decisions in real time. Point your iPhone camera at any packaged-food ingredient label and the app extracts the text, identifies declared allergens (and hidden aliases) against your personal allergy profile, and returns a clear **Safe / Warning / High Risk** verdict in seconds.

For travel, the app translates labels in 17 languages, generates a multilingual *"I am allergic to…"* card to show restaurant staff, and provides a step-by-step first-aid protocol if a reaction occurs.

The critical paths — scanning, allergen detection, first aid, travel card — work entirely **on-device, in airplane mode**. Cloud sync (Firebase) is an optional convenience layer for cross-device backup.

---

## Features

### Core (MVP)
- **Ingredient label scanning** — Apple `Vision` OCR with multi-rotation extraction
- **Allergen detection** — `NaturalLanguage` tokenisation + Apple Foundation Model (Apple Intelligence) for ingredient extraction, alias matching against the EU's 14 regulated allergens plus corn and coconut
- **Multi-profile support** — separate allergen lists, scan history, and custom allergens per profile (e.g. parent and child on one device)
- **Scan history** — every scan persisted to Core Data, filterable by risk level
- **Biometric authentication** — Face ID / Touch ID gates the Settings tab so the scanner and First Aid Guide stay instantly accessible
- **Local notifications** — daily safety reminder + emergency-specific (second-dose epinephrine at +10 min, biphasic reaction watch at +6 hr)
- **Haptic feedback** — capture pulse + critical-result pulse via Core Haptics

### Enhanced
- **Translation Mode** — multi-language OCR (Japanese, Chinese Simplified/Traditional, Cantonese, Korean, Thai, Arabic, English, French, German, Italian, Spanish, Portuguese, Russian, Ukrainian, Vietnamese, *17 total*) with on-device translation via Apple's `Translation` framework
- **Travel Allergy Card** — hand-curated medical-grade translations in 14 secondary languages with a full-screen "show to staff" mode (max brightness, no auto-lock, tap-to-dismiss)
- **Smart First Aid Guide** — mild-vs-severe triage screen, interactive checklist with timestamps, live epinephrine redose timer, pre-populated 911 script, SMS alert with GPS location to a saved emergency contact

### Advanced
- **Foundation Models extraction** — on-device LLM for semantic ingredient extraction (significantly higher recall than regex; gracefully falls back to regex when unavailable)
- **Risk classification** — `Safe` / `Warning` / `High Risk` / `Not Food` (LLM identifies non-food products)
- **Cloud sync (Firebase Auth + Firestore)** — multi-device sync of profiles, scan history, custom allergens, with a real-time sync status row in Settings (online/offline/syncing/error states)
- **Authentication flow** — splash + 3-page swipeable onboarding + sign up / login / email-link verification / password reset
- **Apple Health Medical ID export** — copies tracked allergens to clipboard and deep-links to Health app for paste
- **Siri Shortcut** — say *"Hey Siri, allergic reaction help in AllerScan"* to open First Aid hands-free (`AppIntents` framework)

---

## Tech stack

| Layer | Technology |
|---|---|
| UI | SwiftUI (iOS 16+) |
| Persistence | Core Data + SQLite |
| Camera + OCR | AVFoundation, Vision (`VNRecognizeTextRequest`) |
| NLP | NaturalLanguage, Apple FoundationModels (Apple Intelligence) |
| Translation | Translation framework (on-device, native) |
| Auth + Cloud | Firebase Auth, Firestore |
| Networking detection | Network framework (`NWPathMonitor`) |
| Biometric | LocalAuthentication |
| Notifications | UserNotifications (`.timeSensitive` interruption) |
| Haptics | Core Haptics |
| Location | CoreLocation (one-shot fetch, used only for emergency SMS) |
| Voice | AppIntents (Siri Shortcut) |
| Testing | XCTest |

---

## Architecture

Modular monolith organized by feature, with clear layering:

```
AllerScan/
├── AllerScanApp.swift              # @main, dependency injection root
├── ContentView.swift               # Top-level routing only (~40 lines)
├── Models.swift                    # Domain types (Allergen, ScanRecord, UserProfile, etc.)
├── Services.swift                  # Allergen detection, OCR, biometric, notifications, haptics, location
├── PersistenceStore.swift          # Core Data layer + repository
├── ViewModels.swift                # AppViewModel (scan, profile, settings orchestration)
├── AuthService.swift               # Firebase Auth wrapper
├── SyncService.swift               # Firestore sync coordinator with status states
├── FoundationModelExtractionService.swift   # Apple Intelligence ingredient extraction
├── FirstAidIntent.swift            # Siri AppIntent
├── CameraPreview.swift             # AVFoundation camera preview
└── Views/                          # 35 per-feature SwiftUI views
    ├── Onboarding/
    ├── Auth/
    ├── Dashboard/
    ├── Scanner/
    ├── Translation/
    ├── TravelCard/
    ├── FirstAid/
    ├── Profiles/
    ├── History/
    ├── Settings/
    └── Shared/
```

**Key design decisions:**

- **Local-first, cloud-optional.** Core Data is the source of truth; Firestore is a sync/backup layer. Scanner, allergen detection, and First Aid have zero network dependencies.
- **Settings-only Face ID lock** instead of app-wide. Scanner and First Aid stay instantly accessible because emergency access trumps privacy in a medical app.
- **Static translations for the Travel Card.** ML-translated medical content can hallucinate; the 14-language table is hand-curated against official health-authority phrasing.
- **Single anaphylaxis protocol for all allergens.** Anaphylaxis biology is identical regardless of trigger — one vetted protocol covers every allergen, custom or built-in. Per-allergen variations from web sources risk hallucinated medical advice.

---

## Requirements

- **Xcode 16+**
- **iOS 16.0+** target device or simulator (iOS 17+ for full Apple Intelligence; falls back gracefully on older versions)
- **Apple Developer account** (free tier works) — needed for Face ID, biometric testing, push permissions
- **Firebase project** (free Spark plan) — for Auth + Firestore

---

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/<your-username>/AllerScan.git
cd AllerScan
```

### 2. Configure Firebase

1. Create a project at https://console.firebase.google.com
2. Add an iOS app with the bundle identifier matching the Xcode project (default: `com.<yourname>.AllerScan`)
3. Download `GoogleService-Info.plist` and drop it into `AllerScan/` (next to `AllerScanApp.swift`) — make sure it's added to the AllerScan target in Xcode.
4. **Enable Email/Password authentication:** Firebase Console → Authentication → Sign-in method → Email/Password → Enable.
5. **Create Firestore database:** Firebase Console → Firestore Database → Create database → Production mode → choose region.
6. **Set Firestore rules** — Rules tab, replace defaults with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

### 3. Add required Info.plist keys

Open the AllerScan target → **Info** tab. Add these privacy descriptions:

| Key | Value |
|---|---|
| `Privacy - Camera Usage Description` | `AllerScan uses the camera to scan ingredient labels.` |
| `Privacy - Face ID Usage Description` | `AllerScan uses Face ID to lock your settings and profile.` |
| `Privacy - Location When In Use Usage Description` | `AllerScan needs your location only when you tap the emergency alert button to include it in the SMS to your contact.` |

### 4. Open and run

```bash
open AllerScan.xcodeproj
```

Or in Xcode:
1. **Signing & Capabilities** → set your Apple Team for both `AllerScan` and `AllerScanTests` targets.
2. Select a destination (simulator or connected device).
3. **⌘R** to run.

---

## Running tests

```bash
⌘U  # in Xcode
```

Or from CLI:

```bash
xcodebuild test \
  -project AllerScan.xcodeproj \
  -scheme AllerScan \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

The test suite (`AllerScanTests/AllerScanTests.swift`) covers:

- `ScanService.normalize` — text normalisation (case, diacritics, whitespace)
- `AllergenDetectionService` — direct match, profile filter, mayContain, hidden alias, nutrition panel filtering, plural form matching, empty profile
- `AllergenCatalog` — full set of 16 allergens, alias correctness
- `TranslationService.detectLanguage` — Japanese, Chinese, Korean, Thai, German, sparse-kana noise, empty input
- `TranslationService.findAllergenOccurrences` — basic detection, trace context, no-match
- `AllergenTravelTranslations` — multi-language lookups, fallback for unknown allergens, all 14 languages have phrases
- `EmergencyAlert` — SMS body with/without coordinates, URL separator, phone formatting cleanup
- `FirstAidGuide` — emergency number resolution by region, plan structure, action ordering
- `PersistenceStore` — multi-profile save/load, cascade delete

---

## Assignment requirements mapping

| Requirement | Implementation |
|---|---|
| Mandatory iOS feature: **Push Notifications** | `UserNotifications` with `.timeSensitive` interruption — daily reminder, second-dose, biphasic-reaction watch |
| Mandatory iOS feature: **Core Data** | `PersistenceStore` with 4 entities (UserProfile, ScanRecord, AppSettings, CustomAllergen), automatic migration |
| Mandatory iOS feature: **Face ID / Touch ID** | `BiometricAuthService` via `LocalAuthentication`, gates Settings tab |
| Advanced iOS feature: **SiriKit / AppIntents** | `OpenFirstAidIntent` exposes a Siri shortcut |
| Modular code | 30+ feature files under `Views/`, services and models in dedicated files |
| Unit tests | ~28 test cases in `AllerScanTests.swift` |
| Accessibility | Dynamic Type, semantic colours + icons, Right-to-Left layout for Arabic, ≥44 pt touch targets |

---

## Known limitations

- **Apple Intelligence** is needed for the highest-quality ingredient extraction. Without it, the app falls back to a regex-based extractor — still functional, slightly less accurate on messy OCR.
- **Translation framework** requires the user to download a language pack on first use of an unfamiliar pair. After that it's offline.
- **Cloud sync uses last-write-wins** — no conflict resolution. Sufficient for one-user-multi-device scenarios; would need refinement for shared profiles.
- **First aid protocol assumes anaphylaxis-grade reactions.** Mild reactions are routed to a separate antihistamine-and-monitor protocol, but the app cannot diagnose. The triage screen is informed self-assessment, not medical advice.

---

## Project structure summary

| Path | Purpose |
|---|---|
| `AllerScan/AllerScanApp.swift` | App entry, Firebase init, dependency wiring |
| `AllerScan/ContentView.swift` | Top-level routing (auth state → onboarding → main app) |
| `AllerScan/Models.swift` | Pure domain types — Allergen, ScanRecord, UserProfile, etc. |
| `AllerScan/Services.swift` | OCR, allergen detection, biometrics, notifications, location, haptics |
| `AllerScan/PersistenceStore.swift` | Core Data setup + repository methods |
| `AllerScan/ViewModels.swift` | Profile, scan, security view-model logic |
| `AllerScan/AuthService.swift` | Firebase Auth wrapper |
| `AllerScan/SyncService.swift` | Firestore push/pull + status state machine |
| `AllerScan/FoundationModelExtractionService.swift` | Apple Intelligence ingredient extraction |
| `AllerScan/FirstAidIntent.swift` | Siri Shortcut intent |
| `AllerScan/CameraPreview.swift` | AVFoundation preview wrapper |
| `AllerScan/Views/` | 35 SwiftUI views grouped by feature |
| `AllerScan/Assets.xcassets` | App icon, colours, image assets |
| `AllerScanTests/AllerScanTests.swift` | XCTest suite |

---

## Credits

Built as part of an iOS coursework project. Uses Apple's native frameworks where possible; Firebase only where on-device cannot replicate cross-device sync and authentication.

Translation strings for the Travel Card are sourced from official health-authority materials (NHS multilingual leaflets, EU FIC food-information regulations) where available.

---

## License

This project is for educational purposes.
