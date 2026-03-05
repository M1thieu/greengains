# Play Store Listing — GreenGains

## App name
GreenGains

## Short description (80 chars max — 76 used)
Passively map your city. Light, pressure, motion — collected while you move.

## Full description (4000 chars max)

Your phone already senses the world around it. GreenGains puts those sensors to work.

While you go about your day — commuting, walking, running errands — the app quietly collects environmental readings in the background: ambient light, barometric pressure, movement patterns, and magnetic field data. No tapping required. No battery drain. Just passive contribution to a shared city map.

**What you're building**

Every trip you take covers ground that no sensor network could afford to place hardware on. Your phone fills those gaps. The coverage map shows your personal contribution tiles alongside the community's collective footprint — and over time, it builds into a real environmental dataset that researchers and urban planners can actually use.

**How it works**

1. Sign in and tap Start — the app runs silently in the background
2. Sensors collect readings every 15–60 seconds depending on your movement
3. Data uploads automatically every 5 minutes over any connection
4. Your coverage appears on the map as colored hexagons
5. Pause or stop anytime from the notification shade or app

**What we measure**

- Ambient light — indoor/outdoor patterns, daylight availability
- Barometric pressure — altitude variations, weather micropatterns
- Accelerometer & gyroscope — movement context and activity
- Magnetometer — magnetic field mapping, indoor detection
- GPS location — anonymized to neighborhood-level hexagons before storage

**Your privacy**

Your precise location is never stored. Before any data leaves your device, GPS coordinates are generalized to coarse geographic cells (H3 hexagons, roughly the size of a city block). We never sell your data. All readings are anonymous and cannot be traced back to you. You can delete your account and all associated data at any time at greengains.eremat.org/legal/data-deletion.

**Designed for real-world use**

- Runs in the background with a persistent notification (required for foreground location access)
- Adapts GPS precision to your motion: full accuracy when moving, reduced when stationary to save battery
- Pauses uploads automatically when battery drops below 15%
- Works on WiFi or mobile data

Privacy Policy: https://greengains.eremat.org/legal/privacy-policy

---

## Category
Tools (primary) — Maps & Navigation (secondary, if available as secondary)

## Content rating
Everyone

## Tags / keywords
environmental data, sensor mapping, citizen science, urban mapping, passive data, city map, barometer, light sensor, background tracking

---

## Short description alternatives (pick one)

Option A (76 chars):
Passively map your city. Light, pressure, motion — collected while you move.

Option B (73 chars):
Your phone senses your city. Contribute passively while you go about your day.

Option C (72 chars):
Map your city passively. Environmental sensors, zero effort, real impact.

---

## What's new (first release)
Initial release. Start contributing environmental sensor data to your city's coverage map.

---

## Notes for reviewer
- App uses foreground location service for background GPS collection (declared in manifest as FOREGROUND_SERVICE_TYPE_LOCATION)
- Data is anonymized on-device before upload — precise coordinates are never transmitted
- Users can stop the service at any time via in-app controls or notification action
