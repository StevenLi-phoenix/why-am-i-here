# Usability test plan: Why Am I Here? (hi-fi iOS build, TestFlight)

Evidence level: **plan**. Tasks come from the main persona (Maya Rivera, "The Habitual Scroller") and the group storyboard. The task list was checked against the inspection in [inspection.md](inspection.md). Fill in [session-sheet.md](session-sheet.md) once per participant.

## Goals / research questions

1. Can a first-time user set up the Shortcuts automation from the in-app guide, and tell whether it works?
2. Does the Intent Check make every choice clear, including leaving without opening the app (the storyboard ending)?
3. After a check-in or a reminder, do users know where they are and what was recorded?
4. Can users answer questions about their week from Today and Reflection? What do they think "Intentional %" and "Mindless" mean?
5. Can users change how often the app asks, when it stays quiet, how soon it reminds them, and which apps it watches?
6. Does the app feel calm and free of judgment? (Maya's frustration: "Screen-time totals make her feel guilty without showing what to change.")

## Participants

5 people in one round (the lecture rule: 5 users find about 85% of the core problems). They should look like Maya and the sidekick personas:

- Age 18–35, iPhone users who open social apps many times a day and want to cut down.
- At least 2 who have never made a Shortcuts automation, and at least 1 who is not a CS student.
- Excluded: group members, their roommates or partners, and anyone graded by the group.

## Tasks

The tasks are goals, never UI words. Read them out exactly and hand the participant a printed copy.

| # | Task given to participant | Success criterion | Max time |
|---|---|---|---|
| T1 | "You just installed Why Am I Here? because you keep opening Instagram without meaning to. Get it ready so that the next time you open Instagram, it stops and asks you why. Tell me when you're sure it works." | An "Is Opened" automation for Instagram that runs "Ask Why I'm Here"; opening Instagram shows the question. | 8 min |
| T2 | "You're studying. Your friend Sam just sent you a message on Instagram. Go and reply to Sam." | Picks Messages (or another fitting reason), continues, and ends up in Instagram. | 2 min |
| T5 | (right after T2) "Keep using Instagram the way you normally would." When the reminder arrives: "You've been here longer than you planned. Wrap up." | Opens the reminder (banner or its button) and chooses to stop. | 2 min after the reminder |
| T3 | "You're back to studying. A few minutes later you grab your phone and open Instagram without thinking. When the app asks, you realize you don't need Instagram right now. Get back to studying without going into Instagram." | Leaves through **Never Mind**. Tapping Skip and landing in Instagram is a failure. | 1 min |
| T4 | "Your friend posted the start time of tonight's party in her Instagram story. Open Instagram to check it, and tell the app exactly why you're there." | Chooses Other…, types a note such as "party time", continues. | 2 min |
| T6 | (the facilitator loads the sample week first) "The app has been keeping track of your week. On which day did you pick up your phone the most, and how many times? How many times on Monday? Which reason did you give most often?" | All three answers right: the busiest day and its count, Monday's count, and Messages. | 3 min |
| T7 | "Being asked every single time is getting annoying. Make the app ask only when you come back to an app after being away from it for a while." | "After 30+ Minutes Away" is selected. | 2 min |
| T8 | "You don't want any questions or reminders while you're in bed, from 11 PM to 8 AM." | Quiet hours are on, from 11 PM to 8 AM. | 2 min |
| T9 | "You also lose a lot of time on YouTube. Make the app ask about YouTube too, and make the nudge come after 20 minutes instead." | YouTube is watched and Remind After is 20. Bonus: the participant notices that YouTube also needs its own automation. | 3 min |

The order above (T1, T2, T5, T3, T4, T6, T7–T9) matters. T2 starts the session that T5's reminder comes from, and the settings tasks come last so that they don't stop later check-ins from asking.

## Before each session (facilitator)

1. Test iPhone on iOS 26 or later, with the latest TestFlight build (public link https://testflight.apple.com/join/utJrrru3). Install Instagram and YouTube, and log Instagram into a **test account**, never the participant's.
2. In Shortcuts → Automation, delete every "Ask Why I'm Here" and "Mark App Closed" automation left from the last participant.
3. In Why Am I Here?, go to Settings → Erase All Data and Settings. Then set Remind After to **5** minutes so the T5 reminder arrives during the session. Allow notifications for the app, and turn Focus / Do Not Disturb off.
4. Start the screen recording (Control Center), with the microphone on if the participant agrees.
5. Fallback: if T1 runs out of time, the facilitator builds the Instagram "Is Opened" automation (rehearse it; it takes about 1 minute), so T2 onward can still run. Write T1 down as failed.
6. Before T6: Settings → Load Sample Week. Say "I'm loading a week of sample data" and don't show the Settings screen. The sample week depends on today's date, so write the correct T6 answers (busiest day and its count, Monday's count) on your sheet first. Messages is always the top reason.

## Session script (about 40 minutes)

1. **Welcome (2 min).** "Thanks for coming. We're testing the app, not you. If something is hard, that's the app's fault and exactly what we want to find."
2. **Consent (1 min).** Ask permission to record the screen and audio. They can stop at any time, and notes use a participant number, not their name.
3. **Think-aloud (2 min).** "Please say out loud what you look at, what you expect, and what you're thinking." Practice: "Find the weather for tomorrow."
4. **Warm-up (2 min).** "Tell me about the last time you picked up your phone for one thing and ended up somewhere else."
5. **Tasks (25 min)** in the order above. Don't help. Answer questions with a question ("What do you think it does?"), and when they go quiet, prompt "What are you thinking?" During the 5-minute wait in T5, ask: "Walk me through how you use Instagram on a normal evening."
6. **After each task:** "How easy or hard was that, from 1 (very hard) to 7 (very easy)?" and "What did you expect to happen?"
7. **SUS (3 min)**: the 10 items in [session-sheet.md](session-sheet.md).
8. **Debrief (3 min):**
   - "What was most confusing?"
   - "What does the big percentage on the first screen mean to you? What counts as 'Mindless'?"
   - "How did you feel when the app asked why you were there?"
   - "Would you keep this on your own phone? Why or why not?"
   - "Is there anything we didn't ask about?"
9. **Thanks**, and a small treat.

## Measures

- **Effectiveness:** completion per task (success / partial / fail), errors, and critical incidents.
- **Efficiency:** time on task, wrong turns, and help requests.
- **Satisfaction:** ease rating per task (1–7), SUS score (mean and range; about 68 is average), and quotes.

## Roles

1–2 people per session (more makes participants uneasy):

- **Facilitator:** reads the tasks, keeps the session moving, never helps.
- **Note-taker:** fills in the session sheet, timing each task and writing quotes verbatim.

## Analysis

1. Merge the five session sheets into one issues table: issue · task · participants affected (n/5) · evidence (quote or observation) · severity · suggested change.
2. Rate severity the way the lecture does: **critical** (blocks the task or loses data), **serious** (slows users down a lot, or they recover only with help), **minor** (cosmetic or slight hesitation).
3. Report completion rate and median time per task, the mean ease rating per task, and the SUS mean and range.
4. End with the changes you would make with more time, ranked by severity.
