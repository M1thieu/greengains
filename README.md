# GreenGains 🌱

Passive environmental sensor data collection for greener cities.

## Quick Start

### 1. Setup
```bash
# Copy the API key template
cp dart_defines.json.example dart_defines.json

# Edit dart_defines.json and add your API key
# (Get it from Render.com → greengains service → Environment → API_KEY)
```

### 2. Run
```bash
# Easy way (PowerShell)
.\run-debug.ps1

# Or standard Flutter
flutter run --dart-define-from-file=dart_defines.json
```

### 3. Build APK
```bash
# Easy way (PowerShell)
.\build-apk.ps1

# Or standard Flutter
flutter build apk --dart-define-from-file=dart_defines.json
```

---

## How It Works

- **Passive Collection**: Runs in background collecting sensor data (light, accelerometer, gyroscope, pressure, GPS)
- **Privacy First**: Location data for environmental correlation
- **Low Impact**: Minimal battery usage, adaptive upload intervals
- **Track Impact**: See your contributions and coverage map
- **Daily Rewards**: Earn credits for contributing data

---

## Internationalization (i18n)

**Supported Languages:** English, French

The app automatically detects your device language and displays the appropriate translation.

### Adding/Editing Translations

1. **English**: Edit `lib/l10n/app_en.arb`
2. **French**: Edit `lib/l10n/app_fr.arb`
3. Run `flutter pub get` to regenerate localization code
4. The app won't compile if translations are missing (failsafe!)

**Adding a new language:**
1. Create `lib/l10n/app_XX.arb` (XX = language code)
2. Copy all strings from `app_en.arb`
3. Translate each value
4. Add `Locale('XX')` to `supportedLocales` in `main.dart`

See `I18N_GUIDE.md` for detailed documentation.

---

## Architecture

```
Flutter App → Render.com Backend → Supabase Database
```

- **Frontend**: Flutter (Android)
- **Backend**: Node.js/TypeScript on Render.com
- **Database**: PostgreSQL on Supabase
- **Auth**: Firebase Authentication

---

## Security

- API keys are NOT committed to git
- `dart_defines.json` is gitignored (local only)
- See `SECURITY_SETUP.md` for details

---

## Development Setup

See `SETUP_DEV.md` for detailed setup instructions.

---

## Continuous integration

`.github/workflows/ci.yml` runs on every push to `main`/`master` and on every pull request.
It never deploys and needs no secrets; the backend deploys through Railway on push, separately.

| Job | What it checks | Run it locally |
|---|---|---|
| Repo hygiene | no secret or signing file is tracked; EN/FR `.arb` files have the same keys and placeholders | `node tools/check-l10n.mjs` |
| Backend | `tsc` type check, then all `backend/src/**/*.test.ts` | `cd backend && npm run build && npm test` |
| Flutter | `flutter analyze` (must be clean), generated l10n files match the `.arb` files | `flutter analyze` and `flutter gen-l10n && git diff --exit-code lib/l10n` |
| Android | native Kotlin unit tests (position filter, aux sensors) | `cd android && ./gradlew :app:testDebugUnitTest` |

Flutter is pinned in the workflow (`FLUTTER_VERSION`) because the committed `lib/l10n/app_localizations*.dart`
are generated output; bump it together with your local Flutter. To make Railway wait for a green CI before
deploying, enable "Wait for CI" in the Railway service settings.

---

## Contributing

1. Fork the repo
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

---

## License

MIT
