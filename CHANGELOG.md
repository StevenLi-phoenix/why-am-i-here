# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [0.1.0] - 2026-11-17

### Added

- Today screen with the intentional-pickup ring, screen time, pickups, mindless count, top reasons, weekly trend card and last check-in.
- Intent Check ("Why Are You Here?") with seven reasons, free-text "Other…", Continue and Skip for Now.
- Gentle Reminder screen and notifications every N minutes of a session, with "I’m Done for Now" and "Keep Going".
- Weekly Reflection with daily pickup chart, average line, top reasons by share and a generated insight.
- Settings for asking, frequency (every open, every 3rd open, after 30+ minutes away), reminder interval, watched apps and quiet hours.
- Watched Apps list with 20 built-in apps, custom apps, a Shortcuts setup guide and an in-app preview of the flow.
- App Intents "Ask Why I’m Here" and "Mark App Closed" for Shortcuts automations.
- Deep links (`whyamihere://ask`, `closed`, `reminder`, `preview`, `today`, `reflection`, `settings`).
- Unit tests for the check-in engine, statistics, settings and formatting; UI tests for the main flows.
- `scripts/build.sh` for tests, signed development builds and device installs.
