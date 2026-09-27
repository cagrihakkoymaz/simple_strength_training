# Garmin fenix 7 Extension – Feasibility & Step-by-Step Guide

Status: **feasibility only – nothing built yet.**
Goal: use the Goliaz strength program (see [CLAUDE.md](CLAUDE.md)) from a **Garmin fenix 7** watch.

---

## 1. Short answer

| Question | Answer |
|---|---|
| Can the Flutter app just be installed on the watch? | **No.** Garmin watches don't run Android or Flutter. They run **Connect IQ** apps written in **Monkey C**. |
| Can we build a watch version? | **Yes, and it's realistic.** The core logic is small: the table, 7 sets, rest timer, and unbroken/broken check. |
| How hard? | A basic standalone watch app is **medium** effort (≈ 3–6 evenings, including learning Monkey C). Syncing watch ↔ phone is the **hard** part (≈ 1–2 weeks extra). |
| Can I try it without publishing to the store? | **Yes.** Build a `.prg` file and copy it to the watch over USB ("sideloading"). |
| Is there a zero-code option? | **Partly.** Garmin Connect *Workouts* can hold your sets, reps, and rest (see Option 0). |

**Recommendation:** start with a **standalone watch app** (Option A). Keep the phone app as the place for history and charts. Add activity recording and sync later only if you really need them.

---

## 2. Options (easiest → hardest)

### Option 0 – No code: Garmin Connect strength workouts
In the Garmin Connect app, go to *Training & Planning → Workouts → Create → Strength*. Add, for example, "Pull-ups, 7 sets: 5,5,4,4,4,3,3 reps, 60 s rest" and send it to the watch.
- ✅ Works today, with a native rest timer, beeps, and vibration, and it's recorded in Garmin Connect.
- ❌ You must edit the workout by hand every time your group changes. There's no Goliaz table, no automatic advance/stay logic, and no link to this app.
- Good for testing the watch experience before writing any code.

### Option A – Standalone Connect IQ watch app (**recommended first step**)
A small watch app that holds the Goliaz table, your current group per exercise, a rest countdown with beeps and vibration, a failed-set rep entry, and a next group/stay choice. Data is stored on the watch.
- ✅ Everything happens on the wrist. The phone isn't needed during training.
- ❌ Watch and phone histories are separate. You set your groups on the watch by hand to match the phone.

### Option B – Option A + record a Garmin activity
Also record a **strength training activity** (FIT file) with `ActivityRecording`, so the workout, heart rate, and calories show up in Garmin Connect.
- Extra effort: small (≈ 1 evening). Needs the `Fit` permission.

### Option C – Option A + two-way sync with the Flutter app
The watch sends finished sessions to the phone, and the phone sends current groups to the watch.
- Watch side: the `Communications` API (`transmit`, `registerForPhoneAppMessages`).
- Phone side: Garmin's **Connect IQ Mobile SDK for Android** (`connectiq-android-sdk`). There is no official Flutter plugin, so this needs a small **Kotlin plugin + Flutter MethodChannel/EventChannel** in `android/`.
- The **Garmin Connect Mobile** app must be installed on the phone. It carries the messages.
- You also need rules for merging and duplicates, such as a session id and a "last writer wins" rule for groups.
- ❌ This is the hardest and most fragile part: pairing, background delivery, and the app not running when a message arrives.

---

## 3. What carries over from the current app

| Current (Flutter) | Watch (Monkey C) | Effort |
|---|---|---|
| `lib/data/goliaz_table.dart` (48 rows × 7) | A constant array in a `GoliazTable` module. Also port `setsForMax` with extrapolation above 49. | Easy |
| `lib/logic/progression.dart` | Same 3 functions | Easy |
| `lib/logic/workout_plan.dart` (straight/circuit order) | Same loop logic. You could start with straight sets only. | Easy |
| `lib/state/workout_controller.dart` | `Timer.Timer` + a small state machine (WORKING / RESTING / FINISHED) | Medium |
| sqflite history | `Application.Storage` (key/value, small). Keep only current groups + last ~30 sessions. | Easy |
| Countdown beeps in the last 5 s | `Attention.playTone()` + `Attention.vibrate()`. Beeps come from the watch speaker. | Easy |
| Ducking YouTube Music | ❌ Not possible from the watch. The watch beeps and vibrates on the wrist instead. | – |
| Screens (home, workout, finish) | `WatchUi.View` + `BehaviorDelegate` (buttons) | Medium |
| History list, charts, backup | **Keep on the phone.** Too heavy for the watch. | – |

**Keep the table identical in both apps.** Suggested approach: generate `GoliazTable.mc` from `goliaz_table.dart` with a small script in `tool/`, so the numbers are never typed twice.

---

## 4. fenix 7 facts that matter

- **Family:** fenix 7S / 7 / 7X, plus Solar, Sapphire, and Pro variants. Each has its **own Connect IQ device id**. Pick all of them in the manifest (e.g. `fenix7`, `fenix7s`, `fenix7x`, `fenix7pro`…). Check the SDK Manager's device list for the exact ids of your model.
- **Screen:** round, always-on MIP display. The size depends on the model (7S 240×240, 7 260×260, 7X 280×280), so don't hard-code coordinates. Use `dc.getWidth()/getHeight()`.
- **Input:** 5 buttons (START/STOP, BACK/LAP, UP, DOWN, LIGHT) plus a touchscreen. The touchscreen is usually disabled during activities, so design for **buttons first**:
  - **START** = set done
  - **UP/DOWN** = change reps
  - **BACK** = failed / back
- **Sound & vibration:** built-in speaker tones and a vibration motor. Both are available through `Toybox.Attention` if the user hasn't turned off tones and vibration in the watch settings.
- **Memory:** watch apps have a per-device memory limit (a few hundred KB). This app will be far below it, but check your model in the SDK's device reference (`compiler.json` / Device Reference page).
- **API level:** the fenix 7 supports a recent Connect IQ API level (System 5+/API 4+). Everything used here (Timer, Attention, Storage, ActivityRecording, Communications) is available.

---

## 5. Step-by-step: build and try it on your fenix 7 (Linux / this machine)

### Step 1 – Garmin developer account
Create a free account at **developer.garmin.com/connect-iq**. You need it to download the SDK. Publishing to the store is optional.

### Step 2 – Install the Connect IQ SDK Manager
1. Download **Connect IQ SDK Manager** for Linux from the Connect IQ developer site.
2. Unpack it and run `./sdkmanager` (it's in the `bin/` folder).
3. Log in, then download:
   - the **latest SDK**, and set it as *current*
   - **Devices:** fenix 7 / 7S / 7X (and your exact variant if it's Pro/Solar/Sapphire)
4. On newer Ubuntu, the SDK Manager or simulator may complain about missing libraries. Typical fixes:
   ```bash
   sudo apt install libwebkit2gtk-4.1-0 libusb-1.0-0 libsecret-1-0 libjpeg-turbo8
   ```
   If the simulator still won't start, run it from a terminal to see which `.so` file is missing, and install the package that provides it.

### Step 3 – VS Code extension
1. In VS Code, install the extension **"Monkey C"** (publisher: Garmin).
2. Run the command palette: **Monkey C: Verify Installation**. It finds the SDK installed by the SDK Manager.

### Step 4 – Developer key (signs your builds)
```bash
mkdir -p ~/garmin-keys && cd ~/garmin-keys
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem -out developer_key.der -nocrypt
```
In VS Code settings, set **Monkey C: Developer Key Path** to `~/garmin-keys/developer_key.der`.
⚠️ **Never commit this key.** Keep a backup. You need the same key to update a store app later.

### Step 5 – Create the watch project
1. Command palette: **Monkey C: New Project** → type **Watch App** → name `GoliazWatch` → template *Simple*.
2. Put it in this repo under **`garmin/`**, i.e. `simple_strength_training/garmin/GoliazWatch/`.
3. Open `manifest.xml`, pick the **products** (fenix 7 family), and set the minimum API level.
4. Permissions: none for Option A. Add `Fit` for Option B and `Communications` for Option C.
5. Add to `.gitignore`: `garmin/**/bin/`, `*.der`, `*.pem`.

### Step 6 – Run in the simulator
- Command palette: **Monkey C: Run** (or F5) → choose **fenix 7**.
- The simulator opens a picture of the watch. Use the on-screen buttons or the keyboard to press START/UP/DOWN/BACK.
- The simulator can also test tones and vibration, low memory, and different screen sizes.

Command-line equivalent:
```bash
monkeyc -d fenix7 -f garmin/GoliazWatch/monkey.jungle \
        -o garmin/GoliazWatch/bin/GoliazWatch.prg -y ~/garmin-keys/developer_key.der
connectiq &                                   # start simulator
monkeydo garmin/GoliazWatch/bin/GoliazWatch.prg fenix7
```

### Step 7 – Build for your watch
Command palette: **Monkey C: Build for Device** → choose your exact model. The result is **`GoliazWatch.prg`**.

### Step 8 – Copy to the watch (sideload)
The fenix 7 connects over USB as an **MTP** device. It isn't a normal USB drive, and there is no Garmin Express for Linux.
1. Connect the watch with the Garmin cable. Unlock it if it asks.
2. In **Files (Nautilus)** it appears as "fenix 7". Open **Internal Storage → GARMIN → APPS**.
3. Copy `GoliazWatch.prg` into `GARMIN/APPS/`.
4. **Eject** the watch in Files, then unplug it. The watch installs the app after it disconnects.

Command-line alternative:
```bash
gio mount -li | grep -i mtp                  # find the device
# the device appears under /run/user/$UID/gvfs/mtp:host=.../
cp GoliazWatch.prg "/run/user/$UID/gvfs/mtp:host=<...>/Internal Storage/GARMIN/APPS/"
```
If MTP is flaky: use a different USB port or cable, close any other app using the watch, and replug. `jmtpfs` is another option.

### Step 9 – Start it on the watch
Press **START** (activity list) or hold **UP** (apps/controls), depending on the app type. For a watch app it shows in the **activity/apps list**. Scroll to **GoliazWatch**; you can add it to your favourites.

### Step 10 – Debugging on the real watch
1. On the watch storage, create an **empty** file `GARMIN/APPS/LOGS/GoliazWatch.TXT`. The name must match the `.prg` name.
2. `System.println("...")` output is then written to that file. Crash logs appear as `GARMIN/APPS/LOGS/CIQ_LOG.YML` (or similar).
3. Reconnect the watch by USB to read the logs.

### Step 11 (optional, later) – Publish
Upload the `.iq` export (**Monkey C: Export Project**) to the Connect IQ Store, as a *beta* or private app. After that you can install and update it through the Connect IQ phone app, with no more USB copying.

---

## 6. Watch MVP – feature spec

1. **Exercise list:** Pull-ups G11, Push-ups G20, Squats G30. UP/DOWN to choose, START to begin.
2. **Set screen:** big target number, "Set 3/7". Button actions:
   - **START:** done at the target
   - **UP/DOWN:** change the reps first (for a failed set), then START to save
   - **BACK (long press):** finish early
3. **Rest screen:** countdown with a default of 60 s (a setting on the watch). **UP = +15 s, DOWN = −15 s, START = skip.**
   - The last 5 s play a short tone and a vibration each second. At 0, a long tone and a strong vibration.
   - Turn on the backlight at the end of rest.
4. **Summary:** UNBROKEN/BROKEN. Next group is the default after unbroken and Stay after broken; UP/DOWN toggles, START saves.
5. **Storage:** current group per exercise + the last ~30 sessions (date, group, 7 actuals).
6. **Settings menu:** rest seconds, and edit the group per exercise (to copy from the phone until sync exists).
7. Later: circuit mode, activity recording (Option B), sync (Option C).

### Minimal code sketch (Monkey C)

```monkeyc
// source/GoliazTable.mc  (generate from lib/data/goliaz_table.dart)
using Toybox.Math;

module GoliazTable {
    const ROWS = {
        11 => [5, 5, 4, 4, 4, 3, 3],
        20 => [8, 9, 8, 8, 8, 6, 3],
        30 => [12, 14, 12, 11, 12, 8, 6],
        // ... all rows 2..49
    };

    function setsForMax(max as Number) as Array<Number> {
        if (max < 2) { return ROWS[2]; }
        if (max <= 49) { return ROWS[max]; }
        var last = ROWS[49];
        var out = new [7];
        for (var i = 0; i < 7; i++) {
            out[i] = Math.round(last[i] * max / 49.0).toNumber();
        }
        return out;
    }
}
```

```monkeyc
// source/RestTimer.mc – countdown with 5 s beeps
using Toybox.Timer;
using Toybox.Attention;
using Toybox.System;
using Toybox.WatchUi;

class RestTimer {
    private var _timer = new Timer.Timer();
    private var _endMs = 0;
    private var _lastBeep = -1;
    private var _onDone;

    function start(seconds as Number, onDone as Method) as Void {
        _endMs = System.getTimer() + seconds * 1000;
        _lastBeep = -1;
        _onDone = onDone;
        _timer.start(method(:tick), 250, true);
    }

    function remaining() as Number {
        var ms = _endMs - System.getTimer();
        return ms <= 0 ? 0 : (ms + 999) / 1000;
    }

    function adjust(deltaSeconds as Number) as Void { _endMs += deltaSeconds * 1000; }

    function stop() as Void { _timer.stop(); }

    function tick() as Void {
        var left = remaining();
        if (left <= 5 && left > 0 && left != _lastBeep) {
            _lastBeep = left;
            if (Attention has :playTone) { Attention.playTone(Attention.TONE_KEY); }
            if (Attention has :vibrate) { Attention.vibrate([new Attention.VibeProfile(50, 150)]); }
        }
        if (left == 0) {
            _timer.stop();
            if (Attention has :playTone) { Attention.playTone(Attention.TONE_LOUD_BEEP); }
            if (Attention has :vibrate) { Attention.vibrate([new Attention.VibeProfile(100, 800)]); }
            if (Attention has :backlight) { Attention.backlight(true); }
            _onDone.invoke();
        }
        WatchUi.requestUpdate();
    }
}
```

```monkeyc
// Saving state
using Toybox.Application.Storage;
Storage.setValue("groups", { "Pull-ups" => 11, "Push-ups" => 20, "Squats" => 30 });
var groups = Storage.getValue("groups");
```

The UI is one `WatchUi.View` per screen (Exercise list, Set, Rest, Summary). Each has a `WatchUi.BehaviorDelegate` that handles `onSelect` (START), `onNextPage` (DOWN), `onPreviousPage` (UP), and `onBack` (BACK). Switch screens with `WatchUi.switchToView`.

> The tone constant names and APIs above are from the Connect IQ API docs. Verify them against the SDK version you install (API docs → `Toybox.Attention`).

---

## 7. Possible problems and risks

| Risk | Impact | Mitigation |
|---|---|---|
| **New language (Monkey C) and a limited API** | Slower start | Start from the SDK's samples. Keep the MVP small. |
| **Two separate apps** (Flutter + Monkey C) | Table or rules could drift apart | Generate the watch table from the Dart table. Keep the rules in CLAUDE.md. |
| **Data not shared** without Option C | Groups differ between phone and watch | Treat one device as the "master" for training. Copy groups by hand after each group change. |
| **Linux sideloading (MTP)** | Copying fails or hangs; no Garmin Express on Linux | Use Nautilus/gio, replug, change cable or port. Or publish as a beta and install via the phone. |
| **SDK Manager/simulator libraries on Ubuntu 26.04** | Simulator won't start | Install the missing `.so` packages. Worst case, run it in a container or VM of an older Ubuntu. |
| **Multiple fenix 7 variants** (7S/7/7X/Pro) | Wrong device id → the app doesn't appear | Include every variant in the manifest. Build for your exact model. |
| **Watch tones are quiet** and can't duck phone music | You might miss beeps with headphones on | Rely on wrist vibration. Optionally keep the phone app running as well for the audio. |
| **Watch tones or vibration turned off** in system settings | No alert | The app shows a visual flash plus the backlight. Check the watch's *System → Sounds & Vibration*. |
| **Battery** | A long session with the backlight on uses battery | Backlight only at rest end. The MIP display is efficient. |
| **Sync (Option C) complexity** | Messages only go through the Garmin Connect app, may arrive late, and need a native Android plugin | Do it last. Queue on the watch and retry. Make messages idempotent (session ids). |
| **Store review** (if published) | Delays of days | Sideload or use a private beta while developing. |
| **Signing key loss** | You can't update a published app | Back up `developer_key.der` outside the repo. |

---

## 8. Effort and roadmap

| Phase | Content | Estimate | Difficulty |
|---|---|---|---|
| 0 | Try Garmin Connect strength workouts (no code) | 30 min | ⭐ |
| 1 | Setup: SDK, VS Code, key, "Hello World" on simulator + real watch | 1 evening | ⭐⭐ |
| 2 | **MVP watch app** (Option A: table, sets, rest with beeps, summary, storage) | 3–5 evenings | ⭐⭐⭐ |
| 3 | Record a Garmin strength activity (Option B) | 1 evening | ⭐⭐ |
| 4 | Phone ↔ watch sync (Option C: Kotlin plugin + Communications API) | 1–2 weeks | ⭐⭐⭐⭐⭐ |

**Suggested order:** 0 → 1 → 2, then use it for a few weeks before deciding on 3 and 4.

### Proposed repo layout
```
simple_strength_training/
  lib/ ...                    # Flutter app (unchanged)
  garmin/GoliazWatch/         # Connect IQ project
    manifest.xml
    monkey.jungle
    resources/
    source/GoliazTable.mc     # generated
    source/...
  tool/generate_garmin_table.dart   # Dart table → GoliazTable.mc
```

---

## 9. References
- Connect IQ developer portal (SDK Manager, getting started): https://developer.garmin.com/connect-iq/
- API documentation (Toybox modules): https://developer.garmin.com/connect-iq/api-docs/
- Device reference (screen sizes, memory, API level per device): https://developer.garmin.com/connect-iq/device-reference/
- Monkey C VS Code extension: search "Monkey C" by Garmin in the VS Code marketplace
- Connect IQ Mobile SDK for Android (for sync): https://developer.garmin.com/connect-iq/core-topics/mobile-sdk-for-android/ and https://github.com/garmin/connectiq-android-sdk
