# GreenGains — Claude Code Project Guide

## Architecture

| Layer | Tech | Deploy |
|---|---|---|
| Backend | Fastify + TypeScript | Railway (auto on push to master) |
| Mobile | Flutter (com.eremat.greengains) | Manual APK / Play Store |
| Dashboard | React + Vite + TypeScript (`dashboard-web/`) | Manual |
| DB | Neon (PostgreSQL) | Managed |
| Auth | Firebase | Managed |

## CRITICAL: Flutter Run Command

Always run Flutter with dart defines — without it, API key is empty and all backend calls fail:

```bash
/c/Users/mathi/flutter/bin/flutter run --device-id 29081FDH200BGW --debug --dart-define-from-file=dart_defines.json
```

Shorter alias (works from project root):
```bash
flutter run --dart-define-from-file=dart_defines.json
```

## Backend

- **Root dir on Railway:** `backend/` (railway.json at repo root)
- **Push to master → auto-deploys on Railway** (M1thieu/greengains, not erematorg/greengains)
- **App URL:** https://greengains-production.up.railway.app
- **Type check:** `cd backend && npx tsc --noEmit`
- **All DB queries must be parameterized** — no string interpolation in SQL
- **Rate limiting is DB-based** (sensor_batches.created_at sliding window) — scales horizontally

## Flutter Rules

### L10n (STRICT)
- Never hardcode user-visible strings — always use `context.l10n.*`
- Import: `import '../core/extensions/context_extensions.dart'`
- Add keys to **both** `lib/l10n/app_en.arb` AND `lib/l10n/app_fr.arb` simultaneously
- After editing `.arb` files: run `flutter gen-l10n`
- ICU plurals: `"{count, plural, =1{1 item} other{{count} items}}"`

### Android Gotchas
- Apostrophes in `res/values/strings.xml` MUST be escaped as `\'` (unescaped = NullPointerException)
- Notification strings in Kotlin: `context.getString(R.string.*)`
- EN: `res/values/strings.xml`, FR: `res/values-fr/strings.xml`

### State Management
- `AppPreferences.instance` for persistent prefs (SharedPreferences wrapper)
- `AppEventBus` for cross-widget events
- `ValueNotifier` + `ListenableBuilder` for reactive UI state

## Database

- **Primary indexing:** geohash (stable, working)
- **Secondary indexing:** H3 (columns exist in sensor_batches; h3-js computes at ingest)
- **Pending migration:** `backend/db/20260315_add_h3_index_columns.sql` — run in Supabase SQL editor before H3 tile endpoints work
- All migrations use `IF NOT EXISTS` — safe to re-run

## Map / H3 Tile System

- Personal tiles: `/api/user/tiles` — res 9 (~174m hex), includes geohash fallback for pre-migration rows
- Global tiles: `/api/tiles/global` — res 8 (~461m hex), 5-min in-memory cache, 30-day window
- Public tiles: `/api/tiles/public` — same data as global, no auth required

## Design Standards

- **Theme:** Dark (`#0f1a1e` bg, `#10b981` primary green) — Stripe/Linear/Vercel aesthetic
- **No decorative gradients, no emojis in UI**
- Sensor colors: light=#fbbf24, movement=#14b8a6, pressure=#0ea5e9, quality=#10b981
- WCAG 2.2 AA: 4.5:1 contrast, keyboard nav, 24×24px touch targets

## What NOT to Do

- Do not use `request as any` — use `request.user!.uid` (middleware sets it)
- Do not log token values or secrets — log only error messages or absence of value
- Do not hardcode strings in Flutter widgets
- Do not add `max()` calls inline for movement score — use `movementScore()` helper in aggregator.ts
