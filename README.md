# Boring Phone (Proyecto Vorágine)

Get a cheap Android phone, and make it boring on purpose.

This is a one-command setup that strips a Xiaomi phone down to calls, messages, WhatsApp, Gmail, camera, and maps. No browser. No YouTube. No social media. No Xiaomi bloatware. No willpower required.

It will still keep the Play Store, as you should spend a few of days with your new setup to assess which apps you've probably forgotten were necessary (bank, library, gym, etc.). There are instructions below to disable it afterwards.'

This project is called Proyecto Vorágine (Whirpool Project) because it seems fitting and M. decided so. 

## Why

For those of us that realistically need certain apps (Whatsapp, Maps, Gmail) and don't want to spend 1000$ in a performative minimalistic phone. 
Just get a cheap Xiaomi (this script was tested with a 160 euro Redmi 15) and remove all the bloatware and toxic apps from it. 

Willpower is overrated. This approach is different. It removes the apps at the system level. There is no browser to open. There is no "just 5 minutes" of YouTube. You'd need to find your laptop, open a terminal, and type a command. That's enough friction to stop every impulsive reinstall while keeping everything fully reversible.

**The principle: put progress on rails instead of relying on discipline.**

You're not becoming a monk. You're still reachable. You still have WhatsApp, email, maps, and a camera. You just don't have a device that's engineered to harvest your attention in your pocket anymore.

## What You Keep

- ✅ Phone calls & SMS
- ✅ WhatsApp (messages, calls, media — everything)
- ✅ Gmail
- ✅ Camera & Gallery
- ✅ Google Maps
- ✅ Clock, Calculator, Contacts
- ✅ Any app you deliberately install before running the script

## What Gets Removed

- ❌ All browsers (Mi Browser, Chrome)
- ❌ YouTube
- ❌ Google Discover / Search feed
- ❌ Facebook, TikTok, Netflix, Spotify (if pre-installed)
- ❌ Xiaomi ad engine, analytics, telemetry
- ❌ Xiaomi bloatware (20+ apps including Game Center, App Vault, Mi Video, etc.)

## Requirements

- Any Xiaomi / Redmi / POCO phone running MIUI or HyperOS (tested on Redmi Note 15 with HyperOS 2)
- A computer (Mac, Windows, or Linux)
- A USB-C cable
- 30 minutes

> **ADB works on any Android phone.** The script targets Xiaomi-specific bloatware, but the distraction removal (browsers, YouTube, social) works on Samsung, Pixel, OnePlus — anything. See [Adapting for Other Phones](#adapting-for-other-phones).

## Quick Start

### 1. Enable USB Debugging on Your Phone

1. Go to **Settings → About phone**
2. Tap **"OS version"** (or "MIUI version" on older phones) **7 times** — you'll see "You are now a developer"
3. Go to **Settings → Additional settings → Developer options**
4. Enable **"USB debugging"**
5. Enable **"Install via USB"** (Xiaomi-specific, may not appear on all devices)

### 2. Install ADB on Your Computer

Download Android Platform Tools for your OS:

| OS | Download |
|---|---|
| macOS | [platform-tools-latest-darwin.zip](https://dl.google.com/android/repository/platform-tools-latest-darwin.zip) |
| Windows | [platform-tools-latest-windows.zip](https://dl.google.com/android/repository/platform-tools-latest-windows.zip) |
| Linux | [platform-tools-latest-linux.zip](https://dl.google.com/android/repository/platform-tools-latest-linux.zip) |

Unzip and move to your home directory:

**Mac/Linux:**
```bash
unzip ~/Downloads/platform-tools-latest-*.zip -d ~/
```

**Windows:**
Extract the zip and move the `platform-tools` folder to `C:\adb`

### 3. Connect Your Phone

1. Plug your phone into your computer with a USB-C cable
2. On the phone, select **"File transfer"** when prompted
3. Test the connection:

**Mac/Linux:**
```bash
~/platform-tools/adb devices
```

**Windows:**
```cmd
C:\adb\platform-tools\adb devices
```

4. On your phone, tap **"Always allow from this computer"** when the USB debugging prompt appears
5. Run the command again — you should see your device listed with `device` next to it

### 4. Run the Script

**Mac/Linux:**
```bash
bash debloat.sh
```

**Windows:**
```cmd
debloat.bat
```

The script runs in two stages:

1. **Stage 1 — Distraction removal:** Strips browsers, YouTube, social media, then **pauses**. Pick up your phone. Test WhatsApp, Gmail, Camera. Everything working? Press Enter.
2. **Stage 2 — Bloatware removal:** Strips Xiaomi ads, analytics, telemetry, and junk apps.

That's it. Your phone is now boring.

## What the Script Does (Transparently)

Before removing anything, the script:

1. **Snapshots every package on your phone** — saved to `~/redmi-debloat-logs/packages_before_[timestamp].txt`
2. **Logs every action** — what was removed, what was skipped (not found on your phone)
3. **Auto-generates a restore script** — contains only the commands to undo what was *actually* removed
4. **Runs sanity checks** — verifies WhatsApp, Gmail, Camera, and Phone are still present after each stage

Every removal uses `pm uninstall -k --user 0` which:
- Removes the app **for your user only** (not from the system partition)
- **Keeps app data** (the `-k` flag)
- **Requires no root**
- **Is fully reversible** — see [Restoring Apps](#restoring-apps)

## Restoring Apps

### Restore everything at once

The script generates a timestamped restore file. Plug in your phone and run:

```bash
bash ~/redmi-debloat-logs/restore_[timestamp].sh
```

### Restore a single app

```bash
~/platform-tools/adb shell cmd package install-existing com.package.name
```

For example, to bring back Chrome:
```bash
~/platform-tools/adb shell cmd package install-existing com.android.chrome
```

### Nuclear option

A factory reset restores the phone to its original state. Everything comes back.

## Managing the Play Store

The script **does not** disable the Play Store by default. This is deliberate — spend a few days with the debloated phone first and install anything you realize you need.

When you're ready to hide the Play Store:

```bash
~/platform-tools/adb shell pm disable-user --user 0 com.android.vending
```

To update apps (WhatsApp, Gmail, etc.) — no laptop needed:

1. Go to **Settings → Apps** → tap three dots → **Show system apps**
2. Find **Google Play Store** → tap **Enable**
3. Open Play Store, update your apps
4. Go back and disable it again

Do this every 2–3 weeks.

## Adapting for Other Phones

The Stage 1 removals (browsers, YouTube, social media) work on **any Android phone**. The Stage 2 removals are Xiaomi-specific — other manufacturers have their own bloatware packages.

**Samsung:** Replace Stage 2 with Samsung packages (`com.samsung.*`). Common targets: Samsung Internet, Samsung Free, Bixby, Galaxy Store.

**Pixel:** Stage 2 is mostly unnecessary — Pixels ship relatively clean. You may want to remove Google TV, Google One, and YouTube Music.

**OnePlus:** Replace with `com.oneplus.*` and `com.heytap.*` packages.

To see every package on your phone:
```bash
~/platform-tools/adb shell pm list packages
```

## OTA Updates

Monthly security patches and minor updates **will not** reinstall removed apps. A major OS upgrade (e.g., HyperOS 2 → 3) **might** bring some back. If that happens, just run the script again — takes 2 minutes the second time.

## FAQ

**Will this brick my phone?**
No. These commands remove apps at the user level, not the system level. The worst case is an app you need is gone — and you restore it with one command.

**Can I do this without a computer?**
There's an app called [Canta](https://github.com/samolego/Canta) that uses Shizuku to remove system apps directly from your phone. It works, but it also means you can easily undo everything *from your phone* — which defeats the purpose if your goal is behavioral friction.

**What about WhatsApp updates?**
WhatsApp will eventually stop working if it's too outdated. Keep the Play Store available (disable/enable as described above) and update every few weeks.

**My phone feels weird / notifications are broken after Stage 2.**
Run the restore script to undo everything, then re-run the debloat script but press Ctrl+C after Stage 1. Most people only need Stage 1 (distraction removal). Stage 2 (Xiaomi bloatware) is a nice-to-have.

**I got through a week and I want the browser back.**
Ask yourself why. If it's for a genuine task, use your laptop. If you're just uncomfortable with boredom, that's the point. The discomfort fades. The attention span comes back.

## Contributing

This repo covers Xiaomi / Redmi / POCO phones. If you've done the same on Samsung, Pixel, OnePlus, or other manufacturers, open a PR with your bloatware list. Keep the same philosophy: remove distractions, keep essentials, make it reversible.

## License

MIT — do whatever you want with it.

## Credits

Built during a broader experiment in putting behavioral change on rails instead of relying on willpower. The opposite of "just have more discipline" is "design your environment so discipline is irrelevant."
