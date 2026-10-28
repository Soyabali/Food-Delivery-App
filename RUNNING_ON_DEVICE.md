# Running this Flutter app on an Emulator or a Real Phone (Windows + VS Code)

This guide shows two ways to run the app:

1. **Android Emulator**: a virtual phone on your PC
2. **Real Android phone**: connected by USB cable or over Wi‑Fi

> iPhone/iOS needs a Mac with Xcode, so it can't be done on Windows.

---

## 0. One-time checks

Open a terminal in VS Code (**Terminal → New Terminal**, or press ``Ctrl + ` ``) and run:

```powershell
flutter doctor
```

Every line should show `[√]`. The line that matters most here is **Android toolchain**.
If it shows `[!]` or `[X]`:

- Install **Android Studio** from https://developer.android.com/studio (it includes the Android SDK and the emulator).
- Open Android Studio once and finish the setup wizard.
- Run `flutter doctor --android-licenses` and type `y` to accept every license.

### VS Code extensions

Open the Extensions panel (`Ctrl + Shift + X`) and install:

- **Flutter** (by Dart Code). This also installs the **Dart** extension.

---

## 1. Option A: Android Emulator

### 1.1 Create an emulator (only once)

**The easy way (Android Studio):**

1. Open Android Studio → **More Actions** (or the ⋮ menu) → **Virtual Device Manager**.
2. Click **+ / Create Virtual Device**.
3. Pick a phone, for example **Medium Phone** or **Pixel 8** → **Next**.
4. Choose a system image (the newest API with a **download** icon). Download it, then click **Next**.
5. Click **Finish**.

**From the terminal:**

```powershell
flutter emulators --create --name my_phone
```

> This machine already has one: **`Medium_Phone_API_37.0`**.

### 1.2 Start the emulator

**From VS Code:**

1. Look at the **bottom-right status bar**. It shows the current device, for example `Windows (windows-x64)`.
2. Click it, or press `Ctrl + Shift + P` and type **Flutter: Select Device**.
3. Choose **Medium Phone API 37.0 (mobile emulator)**. The emulator window opens. The first boot takes 1–2 minutes.

**From the terminal:**

```powershell
flutter emulators                                   # list emulators
flutter emulators --launch Medium_Phone_API_37.0    # start one
flutter devices                                     # check that it shows up
```

### 1.3 Emulator tips

- If the emulator is slow, check that **virtualization** is on in BIOS. Also enable **Windows Hypervisor Platform** in *Windows Features*.
- Keep the emulator open between runs. You don't need to restart it each time.
- To wipe it: Android Studio → Device Manager → ⋮ → **Wipe Data**.

---

## 2. Option B: Real Android phone

### 2.1 Turn on Developer Options on the phone

1. Open **Settings → About phone**.
2. Tap **Build number** **7 times**. You'll see "You are now a developer!"
   - On Xiaomi/Redmi phones, tap **MIUI version** instead.
   - On Samsung phones, go to **About phone → Software information → Build number**.
3. Go back to **Settings → System → Developer options**.
4. Turn on **USB debugging**.
   - Xiaomi phones also need **Install via USB** turned on.

### 2.2 Connect with USB

1. Plug the phone in with a **data** USB cable. Some cables only charge the phone.
2. On the phone, choose the **File transfer / MTP** USB mode if it asks.
3. A popup **"Allow USB debugging?"** appears. Tick **Always allow** and press **Allow**.
4. Check the connection:

   ```powershell
   flutter devices
   ```

   Your phone should be in the list, for example `RMX3085 (mobile) • 1a2b3c4d • android-arm64`.

If the phone does **not** appear:

- Try another cable or USB port.
- Install your phone maker's USB driver (Samsung, Xiaomi, etc.), or the **Google USB Driver** from Android Studio → SDK Manager → SDK Tools.
- Restart adb:

  ```powershell
  adb kill-server
  adb start-server
  adb devices
  ```

  If the device shows as `unauthorized`, unlock the phone and accept the popup.

### 2.3 Connect over Wi‑Fi (Android 11+, no cable)

1. The phone and PC must be on the **same Wi‑Fi**.
2. On the phone, go to **Developer options → Wireless debugging → On**.
3. Tap **Pair device with pairing code**. Note the IP:port and the code.
4. On the PC:

   ```powershell
   adb pair 192.168.1.5:37123      # use the pairing IP:port, then enter the code
   adb connect 192.168.1.5:41234   # use the IP:port shown on the Wireless debugging screen
   flutter devices
   ```

---

## 3. Run the app

### From VS Code (recommended)

1. Open `lib/main.dart`.
2. Choose your device (emulator or phone) in the bottom-right status bar.
3. Press **F5** (Run → Start Debugging), or **Ctrl + F5** to run without debugging.

The first build takes a few minutes because Gradle downloads its files. Later builds are much faster.

### From the terminal

```powershell
cd F:\soyab\mobileapp
flutter pub get
flutter run                          # asks which device if several are connected
flutter run -d emulator-5554         # run on a specific device (ID from `flutter devices`)
```

### While the app is running

| Key (terminal) | VS Code | What it does |
|---|---|---|
| `r` | Save file / ⚡ button | **Hot reload**: shows your code changes in about 1 second |
| `R` | 🔄 button | **Hot restart**: restarts the app and resets its state |
| `q` | ⏹ button | Stop the app |

---

## 4. Build an APK to share or install manually

```powershell
flutter build apk --release
```

The file is created at `build\app\outputs\flutter-apk\app-release.apk`. Copy it to any Android phone and install it.

---

## 5. Common problems

| Problem | Fix |
|---|---|
| `No supported devices connected` | Start the emulator or plug in the phone, then run `flutter devices` |
| `Android license status unknown` | `flutter doctor --android-licenses` |
| Gradle build is very slow or fails the first time | Check your internet connection, then run it again. Also try `flutter clean` then `flutter pub get` |
| Emulator shows a black screen | Android Studio → Device Manager → ⋮ → **Cold Boot Now** |
| `INSTALL_FAILED_INSUFFICIENT_STORAGE` | Wipe the emulator's data, or free up space on the phone |
| Phone shows `unauthorized` | Unlock the phone and accept the "Allow USB debugging" popup |
