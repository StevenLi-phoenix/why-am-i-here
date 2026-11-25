# Inspection: cognitive walkthrough and heuristic evaluation

**Evidence level: inspection.** One evaluator (Claude) walked through the simulator build on 2026-11-24. These are predictions about where users will struggle, not observations of real users. The [usability test plan](test-plan.md) checks them with 5 participants.

- **Build:** the main branch before and after the fixes below. iPhone 18 Pro simulator, iOS 27.2, English.
- **Persona:** Maya Rivera, "The Habitual Scroller" (26, social worker, uses technology constantly). She wants "a timely pause before opening a distracting app" and "reminders she can customize or dismiss". Screen-time totals make her feel guilty.
- **Tasks:** T1–T9 from the [test plan](test-plan.md), drawn from Maya's goals and the group storyboard. In the storyboard, the app asks, Maya thinks "Maybe not.", and she goes back to studying.
- **Screens:** `scripts/walkthrough.sh <dir>` plays every task in the simulator and saves a screenshot of each step: [screens/before](screens/before) is the baseline, [screens/after](screens/after) is after the fixes.
- **Severity:** Nielsen's 0–4 scale, mapped to the course's labels: 4 critical, 3 serious, 1–2 minor.

## Issues

| # | Issue | Task | Heuristic | Severity | Status |
|---|---|---|---|---|---|
| 1 | The test can't run on the TestFlight build. Today and Reflection stay empty for a new participant, sample data needs a launch argument, and data can't be reset between participants. T6 can't be done. | T6, all | — (test readiness) | 4 critical | **Fixed** |
| 2 | The Intent Check has no way to *not* go into the app, so the storyboard's ending ("Maybe not.") has no button. "Skip for Now" looks like the way out but opens Instagram. | T3 | 3 User control and freedom; 2 Match with the real world | 3 serious | **Fixed** |
| 3 | Nothing shows whether setup worked. The "Finish Setup" card disappears after the first pickup ever, and Watched Apps shows only checkmarks. The only way to check is to open Instagram. | T1 | 1 Visibility of system status | 3 serious | **Fixed** |
| 4 | The default "Every 3rd Open" lets the 2nd and 3rd opens through without a word. Right after setup it looks broken, and in a test session it stops T2–T4 from asking. The rule is explained nowhere in the app. | T1, T2–T4, T7 | 1 Visibility; 6 Recognition rather than recall | 3 serious | **Fixed** |
| 5 | Quiet hours are fixed at 10 PM–7 AM. Maya needs "reminders she can customize", and T8 (11 PM–8 AM) can't be done. | T8 | 7 Flexibility and efficiency | 3 serious | **Fixed** |
| 6 | The Daily Pickups chart labels only the busiest day, so no other day's count can be read. VoiceOver reads only the average. | T6 | 6 Recognition rather than recall; accessibility | 3 serious | **Fixed** |
| 7 | Watched Apps sits under "Gentle Reminder", but it also decides which apps get the Intent Check. | T9 | 4 Consistency; 2 Match | 2 minor | **Fixed** |
| 8 | "Look Something Up" is cut off as "Look Something…" in the weekly Top Reasons. | T6 | 8 Aesthetic and minimalist design | 1 minor | **Fixed** |
| 9 | Try a Check-In ends silently on Today, so it's unclear whether anything was saved. | T1 | 1 Visibility | 1 minor | **Fixed** |
| 10 | Setup happens in another app: 5 steps for "Is Opened" and 3 for "Is Closed", for every watched app, recalled from memory while in Shortcuts. iOS allows no other way in. | T1 | 6 Recognition rather than recall; 10 Help | 3 serious | Open, main thing to watch in T1 |
| 11 | "62% Intentional" and "Mindless" are never explained. Skipping counts as mindless, so one skip shows "0% Intentional", which may feel like blame (Maya: totals make her feel guilty). | T6, T2 | 2 Match; 10 Help | 2 minor | Open, asked in the debrief |
| 12 | A reason picked by mistake can't be corrected after Continue, and there is no list of past check-ins. | T2, T4 | 3 User control | 2 minor | Open |
| 13 | The notification permission prompt appears as soon as the setup guide opens, with nothing to explain why. | T1 | 2 Match; 1 Visibility | 2 minor | Open |
| 14 | Add App asks for a "URL Scheme", which is developer jargon. | T9 | 2 Match | 2 minor | Open |
| 15 | Continue is nearly invisible while disabled (dark gray on black), so users may not see that it exists until they pick a reason. | T2 | 1 Visibility | 1 minor | Open |
| 16 | "Adjust Reminders" on Reflection opens the top of Settings instead of the reminder settings. | T6 | 4 Consistency | 1 minor | Open |
| 17 | The ring on the reminder screen is always full and doesn't show anything. The 4-second notice banner covers the "Today" title. | T5, T2 | 8 Aesthetic | 1 minor | Open |

## Fixes

1. **Sample data and reset (issue 1).** Settings → Data has **Load Sample Week** and **Erase All Data and Settings**, and each asks for confirmation first. The sample is the week from the prototype (37 pickups today, 62% intentional, down 8% on last week). Erasing deletes every pickup and pending reminder and restores the default settings, the same as a fresh install.
2. **Never Mind (issue 2).** The Intent Check has **Skip for Now** and **Never Mind** side by side under Continue. Never Mind stays out of the app, shows "Nice. Instagram can wait.", and records the pickup as "Changed Your Mind": no session, no reminders, and it doesn't count as mindless. VoiceOver hints say where each button leads.
3. **Setup status (issues 3, 9).** The setup guide starts with a "Your Watched Apps" card, and each watched app in Watched Apps has a status line: "Working · last opened today at 9:41 AM", or "No opens yet. Set up its automation." A sixth step was added: "Open Instagram to try it." A preview now ends with "That was a preview. Nothing was saved."
4. **Every Open by default (issue 4).** New installs ask on every open, and a footer under How Often explains the selected rule. Existing settings are kept. If the group prefers the prototype's default, it is one line in `Core/Sources/WAIHCore/Settings.swift`.
5. **Adjustable quiet hours (issue 5).** When Pause All Prompts is on, From and To menus appear, and reminders already planned are re-planned when the hours change.
6. **Readable chart (issue 6).** Tapping a bar shows that day's count, and tapping it again goes back to the busiest day. A caption says that bars can be tapped. VoiceOver reads each day as "Monday, 30 pickups".
7. **Settings order (issue 7).** Watched Apps has its own "Apps" section at the top of Settings.
8. **Truncation (issue 8).** Reason names shrink up to 20% before they are cut off.

## Cognitive walkthrough

For each step of the correct path: **Q1** Will the user try to achieve this effect? **Q2** Will they notice that the action is available? **Q3** Will they connect the action with the effect they want? **Q4** Will they see that progress was made? Before → after the fixes.

| Task | Step | Q1 | Q2 | Q3 | Q4 | Notes |
|---|---|---|---|---|---|---|
| T1 Set up | Today → Show Me How | Y | Y | Y | Y | The card is the most prominent thing on an empty Today ([before](screens/before/t1-1-first-launch.jpg)). |
| | Read the guide, tap Open Shortcuts | Y | Y | Y | Y | |
| | Build the automation in Shortcuts | Y | ? | ? | ? | The steps must be recalled in another app (issue 10). The simulator can't create automations, so this step needs real users. |
| | Check that it works | **N → Y** | **N → Y** | — | **N → Y** | Before, nothing showed whether setup worked, and with Every 3rd Open the next two opens didn't ask (issues 3, 4). After: step 6 and the status lines ([after](screens/after/t1-5-watched-apps-after-first-open.jpg)). |
| T2 Reply to Sam | Pick Messages | Y | Y | Y | Y | Large tiles, a checkmark, and a haptic tap ([before](screens/before/t2-2-reason-selected.jpg)). |
| | Continue | Y | Y | Y | Y | The disabled Continue barely shows until a reason is picked (issue 15), but it turns blue as soon as one is. |
| T5 Wrap up | Tap the reminder → I'm Done for Now | Y | Y | Y | Y | Today and a "Nice work" banner follow ([before](screens/before/t5-2-after-done.jpg)). |
| T3 Back to studying | Leave without going in | Y | **N → Y** | **N → Y** | **– → Y** | Before, there was no button for it, and "Skip for Now" opened Instagram ([before](screens/before/t3-2-after-leaving.jpg)). After: Never Mind ([after](screens/after/t3-1-intent-check.jpg), [result](screens/after/t3-2-after-leaving.jpg)). |
| T4 Party time | Other… → type a note → OK → Continue | Y | Y | Y | Y | The note replaces "Other…" in the tile ([before](screens/before/t4-2-other-selected.jpg)). |
| T6 Read the week | Today → This Week card | Y | Y | Y | Y | The chevron and sparkline suggest more detail. |
| | Busiest day and its count | Y | Y | Y | Y | |
| | Monday's count | Y | **N → Y** | **N → Y** | **N → Y** | Before, only the busiest bar had a number ([before](screens/before/t6-3-reflection.jpg)). After: tap a bar ([after](screens/after/t6-5-reflection-first-day-selected.jpg)). |
| T7 Ask less often | Settings → After 30+ Minutes Away | Y | Y | Y | **~ → Y** | Before, only a checkmark showed the rule; now the footer explains it ([after](screens/after/t7-2-frequency-changed.jpg)). |
| T8 Quiet 11 PM–8 AM | Turn on quiet hours, set the times | Y | Y | **N → Y** | **N → Y** | Before, the times couldn't be changed ([before](screens/before/t8-1-settings-bottom.jpg)). After: From and To menus ([after](screens/after/t8-3-quiet-hours-set.jpg)). |
| T9 YouTube | Settings → Watched Apps → YouTube | Y | **~ → Y** | Y | Y | Before, the row was hidden under "Gentle Reminder". |
| | Realize that YouTube needs its own automation | **N → ~** | — | — | — | After, the new row reads "No opens yet. Set up its automation." Whether people act on it is a question for T9 with real users. |

## Heuristics at a glance

- **Works well:** the calm tone ("No pressure. Just checking in."); big, labeled reason tiles; the app's name and pickup number on the question; real platform controls in Settings; clear empty states ("No check-ins yet", "Reasons you give today will show up here.").
- **Main remaining risk:** setup (issue 10). It happens in another app, there are 8 steps for each watched app, and no app can automate them. Watch it closely in T1. If most participants fail, consider a short video in the guide and leaving the "Is Closed" automation for later.

## What this inspection can't tell

- How long setup in Shortcuts actually takes and where people get lost there.
- Whether people bring the app back up when a real notification arrives, or swipe it away.
- How it *feels* to be asked "Why are you here?" again and again during a day: calm, nagging, or guilt-inducing.
- Whether "Never Mind" and "Skip for Now" next to each other cause mistakes (watch in T3).
