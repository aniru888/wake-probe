# Wake Probe: on-device test protocol

## Install (Windows, free Apple ID)
1. Install iTunes and iCloud from apple.com, not the Microsoft Store. AltServer needs the apple.com versions.
2. Install AltServer for Windows from altstore.io and put AltStore Classic on the iPhone (not AltStore PAL). Follow its guide.
3. Get the app file. On github.com/aniru888/wake-probe, open Actions, pick the latest green run of the "build" workflow, and download the artifact "WakeProbe-ipa". Unzip it to get `WakeProbe.ipa`.
4. Send `WakeProbe.ipa` to the iPhone (iCloud Drive or AirDrop). Open AltStore, go to My Apps, tap +, and choose the file.
5. On the iPhone, go to Settings > Privacy & Security > Developer Mode and turn it on (the phone restarts). Then go to Settings > General > VPN & Device Management and trust your Apple ID.
6. Write down the exact install date and time, and the expiry date AltStore shows. The app stops opening about 7 days later. That is what G2 tests.
7. A free Apple ID allows 10 new App IDs per 7 days and this app uses 2 (app + widget). Reinstalling the same build reuses them; avoid changing anything that would create new ones.

## Before any gate
The first time you open Wake Probe a location prompt may appear. Choose Allow While Using App (you'll switch it to Always later, in G7).

1. Open the app and go to the Alarms screen. Tap "Allow motion access (G9 setup)" once, and allow the motion prompt.
2. When the alarms prompt appears (first time you schedule anything), allow it.

## Gates
Record every result with the result buttons in the app. Each gate below names the buttons.

| Gate | Do this | Pass |
|---|---|---|
| G1 | Turn on Silent mode (Action button, or the bell toggle in Control Center), turn on Do Not Disturb (Control Center › Focus), lock the phone. On the Alarms screen tap "Schedule G1 in 2 min". Swipe Wake Probe away in the app switcher before the alarm rings. Then press one of "rang-silent+focus", "no-ring-silent+focus" or "rang-normal-mode". | It rings audibly: "rang-silent+focus" |
| G8 | Same setup. Tap "Schedule G8 in 2 min". Swipe Wake Probe away in the app switcher before the alarm rings. Listen to the full 28 s. Press "quiet-then-loud", "flat-loud", "default-sound", "silent" or "chime-inaudible". Note whether the phone also vibrated and tap the matching button: "vibrated" or "no-vibration". | A soft chime for about 20 s, then a loud tone: "quiet-then-loud" |
| G5 | Tap "Arm G5 and schedule in 1 min". Swipe Wake Probe away in the app switcher before the alarm rings. When it rings, tap the system Stop. Repeat on every re-ring. Then press "re-rang-3x", "re-rang-<3" or "no-re-ring". | Re-rings about 15 s after each Stop. Log shows "rescheduled" for rounds 1 to 3, then "cap-reached" on the 4th Stop |
| G9 | Comes with every Stop above. Check the Log section. | "steps45" has a number (not "nil") and "ms" is under 2000 |
| G3 | On the Defuse screen tap "Start defuse countdown (3 min)". Lock the phone. Tap "Still up" on the lock screen. Then stop tapping and let the countdown run out. Finally tap "End and cancel backup". Result buttons are listed in the G3 notes. | Each tap logs "defuse-called" and "defused", then "backup-moved". With no more taps, the backup alarm rings at the deadline: press "backup-rang-on-time" |
| G4 | On the Stillness screen: tap "Start: desk" and leave the phone on the desk 10 min. Tap "Start: bed" and leave it on the bed 10 min. Tap "Start: pocket-walking" and walk with it 10 min. Then tap "Analyse last 2 hours". | Desk and bed lines show PASS. Pocket-walking shows PASS (not still for 6 min) |
| G7 | See the G7 steps below. | Log has an "event" with state unsatisfied and appState background, shortly after you left |
| G2 | See the G2 steps below. | The alarm rings after the app has stopped opening |

### G1, G8 notes
For G8, if you could not hear the first 20 s at all, press "chime-inaudible" and tell Claude. The fix is to raise the chime amplitude (`tools/make_sound.py`, constant 0.015 to 0.04) and rebuild.

### G9 notes
A cold start shows a small "processAgeMs" (under ~2000) on the "stop-intent-ran" line. A large value means the app was already running. The cold case is the one G9 cares about, so swipe the app away before the alarm rings in G1, G5 and G8.

### G3 notes
Result buttons on the Defuse screen: press "tap-moved-alarm" if the log shows "backup-moved" after your lock-screen tap. Press "tap-needed-unlock" if the tap needed Face ID or an unlock first. Press "tap-did-nothing" if the tap had no effect and nothing was logged. Press "backup-rang-on-time" if the backup alarm rang at the deadline after you stopped tapping.

The lock-screen "Still up" button may need Face ID or an unlock first. Apple documents that buttons on a locked device are inactive until the user authenticates, so this is expected. In the log, "defused" carries an appState value. "background" means the tap ran without opening the app. "active" means the app opened. "backup-moved" means the backup alarm shifted to the new deadline. "backup-missing" means it did not.

### G4 notes
Each line ends in PASS, FAIL or INCONCLUSIVE. INCONCLUSIVE means too little data (the window was under 6 min, or there were no samples). Redo that placement.

### G7 steps
1. In your room, open the Geofence screen. Tap "1. Allow location (then set 'Always' in Settings)" and choose "Allow While Using App".
2. Tap "Open Settings", go to Location, and choose Always.
3. Only now, standing in your room, tap "2. Map a 200 m fence here". Check the log for "mapped".
4. Close the app by swiping it away.
5. Walk out past about 300 m. Note the clock time yourself. Do not reopen the app during the walk: reopening hands it queued events and corrupts the timing.
6. Stay away at least 5 min, then reopen the app. Tapping "I just passed ~300 m from the room" is optional. The clock time you noted is the reference.
7. In the log, "event" with state unsatisfied and appState background is a real background wake. The first "auth-changed" line appears at launch and is not something you did.

### G2 steps
1. Right after install, you wrote down the install time and AltStore's expiry date. Use the Alarms screen: set "Ring at" to the expiry date plus 2 hours, then tap "Schedule G2".
2. Do not refresh or reinstall in AltStore that week. AltStore Classic can re-sign apps in the background while AltServer is reachable, which would push the expiry back and void G2. For the G2 week, quit AltServer on the PC (and/or turn off Background App Refresh for AltStore on the iPhone). The day before the G2 alarm, open AltStore and check the expiry date has not moved. If it moved, note the new date and reschedule G2.
3. On the day, note outside the app whether the alarm rang. The app may not open after expiry.
4. After you reinstall the app, press the G2 result button ("rang" or "did-not-ring").
5. If it did not ring, the free route cannot be trusted for real mornings.

## Finish
Open the main screen, tap "Export gate log" in the Log section, and send `gatelog.jsonl` to Claude.

G6 (Wi-Fi access point) is not tested: free Apple IDs cannot get the Access WiFi Information capability.
