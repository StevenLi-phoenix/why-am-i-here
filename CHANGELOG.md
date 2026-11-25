# Changelog

All notable changes to this project are documented here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [0.2.0] - 2026-11-24

### Added

- "Never Mind" on the Intent Check: stays out of the watched app and records the pickup as "Changed Your Mind".
- Settings → Data: Load Sample Week and Erase All Data and Settings, each behind a confirmation.
- Setup status for each watched app ("Working · last opened …" / "No opens yet") in the setup guide and Watched Apps, plus a "try it" step in the guide.
- Adjustable quiet hours (From / To) when Pause All Prompts is on.
- Tap a bar in Daily Pickups to read that day's count; VoiceOver reads every day.
- Usability test plan, session sheet and inspection report in `docs/design/usability-test/`.
- `scripts/walkthrough.sh` plays every usability-test task in the simulator and saves a screenshot per step.

### Changed

- New installs ask on every open; the How Often footer explains the selected rule.
- Watched Apps moved to its own section at the top of Settings.
- Previews end with "That was a preview. Nothing was saved."
- Reason names shrink slightly instead of being cut off.

### Fixed

- Changing the quiet hours now re-plans pending reminders.

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
