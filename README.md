# Boring Phone (Proyecto Vorágine)

Get a cheap Android phone, and make it boring on purpose.

This is a one-command setup that strips a Xiaomi phone down to calls, messages, WhatsApp, Gmail, camera, and maps. No browser. No YouTube. No social media. No Xiaomi bloatware. No willpower required.

It still keeps the Play Store, because you should spend a few days with your new setup to find the apps you forgot you need (bank, library, gym, etc.). There are instructions below to disable it afterwards.

This project is called Proyecto Vorágine (Whirlpool Project) because it seems fitting and M. decided so.

## Why

For those of us who realistically need certain apps (WhatsApp, Maps, Gmail) and don't want to spend $1000 on a performatively minimalist phone.
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
- ✅ Any app you deliberately install before running the script (unless it's on one of the [lists](#customizing-what-gets-removed) — comment it out to keep it)

The script **refuses** to touch these essentials, and the core system apps, even if you add them to a list by mistake.

## What Gets Removed

**Stage 1 — distractions** ([`lists/distractions.txt`](lists/distractions.txt)):

- ❌ Every common browser (Mi Browser, Chrome, Opera, Edge, Firefox, Brave, …)
- ❌ The Google app (Search, Discover feed, Assistant, Circle to Search), Gemini, Google Lens, Google News
- ❌ YouTube, YouTube Music, Netflix, Prime Video, Spotify, Google TV
- ❌ Facebook, Instagram, TikTok, Snapchat, X, Reddit, LinkedIn, …
- ❌ The games and shopping apps Xiaomi preinstalls (Block Blast, Solitaire, Temu, AliExpress, Amazon, …)

**Stage 2 — Xiaomi bloatware** ([`lists/xiaomi.txt`](lists/xiaomi.txt)):

- ❌ Xiaomi ad engine, analytics, telemetry
- ❌ GetApps, App Vault, Xiaomi news feeds, Quick Apps, Mi Store, Mi Community
- ❌ Mi Video, Mi Music, Wallpaper Carousel, Game Center, Mi Credit, and more

Only apps that are actually on your phone get touched. Everything in Stage 2 is rated safe to remove by the [Universal Android Debloater](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation) community list. The riskier ones (Joyose, Xiaomi AI Engine) are in the list but commented out.

## Requirements

- Any Xiaomi / Redmi / POCO phone running MIUI or HyperOS (tested on Redmi Note 15 with HyperOS 2)
- A computer (Mac, Windows, or Linux)
- A USB-C cable that carries data (some only charge)
- 30 minutes

> **ADB works on any Android phone.** The script targets Xiaomi-specific bloatware, but the distraction removal (browsers, YouTube, social) works on Samsung, Pixel, OnePlus — anything. See [Adapting for Other Phones](#adapting-for-other-phones).

## Quick Start

### 0. Get the Files

Click **Code → Download ZIP** on GitHub and unzip it, or:

```bash
git clone https://github.com/siragnabih/boring-phone.git
```

Keep the `lists` folder next to the scripts — that's where the app lists live.

### 1. Enable USB Debugging on Your Phone

1. Go to **Settings → About phone**
2. Tap **"OS version"** (or "MIUI version" on older phones) **7 times** — you'll see "You are now a developer"
3. Go to **Settings → Additional settings → Developer options**
4. Enable **"USB debugging"**

You don't need "Install via USB" or "USB debugging (Security settings)" — those need a Xiaomi account, and this script doesn't use them.

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

(Or `brew install android-platform-tools` on a Mac with Homebrew.)

**Windows:**
Extract the zip and move the `platform-tools` folder to `C:\adb` (or to your user folder, `C:\Users\<you>\platform-tools`).

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

### 4. Do a Dry Run

Open a terminal in the `boring-phone` folder and see what the script *would* remove, without touching anything:

**Mac/Linux:**
```bash
bash debloat.sh --dry-run
```

**Windows** (in a Command Prompt opened in the folder):
```cmd
debloat.bat --dry-run
```

Anything on that list you want to keep? Comment it out in [`lists/`](#customizing-what-gets-removed).

### 5. Run the Script

**Mac/Linux:**
```bash
bash debloat.sh
```

**Windows:**
```cmd
debloat.bat
```

(Double-clicking `debloat.bat` works too.)

The script runs in two stages:

1. **Stage 1 — Distraction removal:** Strips browsers, YouTube, social media, then checks that nothing on the phone can still open a web link, and **pauses**. Pick up your phone. Test WhatsApp, Gmail, Camera. Everything working? Press Enter.
2. **Stage 2 — Bloatware removal:** Strips Xiaomi ads, analytics, telemetry, and junk apps.

That's it. Your phone is now boring.

#### Options

| Option | What it does |
|---|---|
| `--dry-run` / `-n` | Show what would be removed. Changes nothing on the phone. |
| `--yes` / `-y` | Don't pause between the stages. |
| `--distractions-only` | Run Stage 1 only and leave Xiaomi's apps alone. |

More than one phone plugged in? Pick one with its serial from `adb devices`:
`ANDROID_SERIAL=<serial> bash debloat.sh` (Windows: `set ANDROID_SERIAL=<serial>` first).

## Customizing What Gets Removed

Both scripts read the same two files:

- [`lists/distractions.txt`](lists/distractions.txt) — Stage 1
- [`lists/xiaomi.txt`](lists/xiaomi.txt) — Stage 2

Each line is a package name and a label:

```text
com.spotify.music                          Spotify
```

- **To keep an app**, put a `#` in front of its line.
- **To remove something else**, add a line. Find its package name with:
  ```bash
  ~/platform-tools/adb shell pm list packages | grep -i <part of the name>
  ```
  (Windows: `adb shell pm list packages | findstr /i <part of the name>`)

Don't use `! % ^ & | < >` in labels — they confuse the Windows script.

## What the Script Does (Transparently)

Before removing anything, the script:

1. **Snapshots every package on your phone** — saved to `~/boring-phone-logs/packages_before_[timestamp].txt` (Windows: `%USERPROFILE%\boring-phone-logs\`)
2. **Checks your essentials are installed** — WhatsApp, Gmail, Maps, Phone, Messages, Camera, Play Store — and tells you what's missing so you can install it first

Then, for each app on the lists that's actually on your phone:

3. **Uninstalls it for your user** with `pm uninstall -k --user 0`
4. **Falls back to disabling it** if Xiaomi blocks the uninstall (Mi Browser is known to do this). A disabled app is hidden and can't run — same effect.
5. **Reports it as FAILED** if the phone refuses both, with the phone's exact answer in the log

And afterwards it:

6. **Checks for leftover browsers** — asks the phone which apps can still open a web link, and names them
7. **Runs sanity checks** — verifies everything essential that was there before is still there, after each stage
8. **Logs every action** and **auto-generates a restore script** containing only the commands to undo what was *actually* removed. The restore script is valid even if you stop halfway.

`pm uninstall -k --user 0`:
- Removes the app **for your user only** (not from the system partition)
- **Keeps app data** (the `-k` flag)
- **Requires no root**
- **Is fully reversible** for preinstalled apps — see [Restoring Apps](#restoring-apps)

Running the script again is safe: apps that are already gone are skipped.

## Restoring Apps

### Restore everything at once

The script generates a timestamped restore file. Plug in your phone and run:

```bash
bash ~/boring-phone-logs/restore_[timestamp].sh
```

Windows: double-click `restore_[timestamp].bat` in `%USERPROFILE%\boring-phone-logs\`.

### Restore a single app

```bash
~/platform-tools/adb shell cmd package install-existing com.package.name
```

For example, to bring back Chrome:
```bash
~/platform-tools/adb shell cmd package install-existing com.android.chrome
```

If the log says the app was **DISABLED** rather than removed, bring it back with:
```bash
~/platform-tools/adb shell pm enable com.package.name
```

Apps you installed yourself from the Play Store (not preinstalled ones) can't be restored this way — just reinstall them from the Play Store.

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

**Want more friction?** Uninstall it for your user instead. Then only the laptop can bring it back:

```bash
~/platform-tools/adb shell pm uninstall -k --user 0 com.android.vending      # hide
~/platform-tools/adb shell cmd package install-existing com.android.vending  # bring back to update
```

## Turning Off the Ads ADB Can't Reach

Some Xiaomi ads live inside system apps you want to keep. Turn them off in Settings (names vary a little by region and HyperOS version):

- **Ad engine:** Settings → Passwords & security → Authorization & revocation → turn off **msa** (if it's still there)
- **Personalized ads:** Settings → Passwords & security → Privacy → Ad services → turn off **Personalized ad recommendations**
- **In each Xiaomi app** you keep (Security, File Manager, Downloads, Themes): open its settings and turn off **Recommendations** / **Show ads**

## Adapting for Other Phones

The Stage 1 list (browsers, YouTube, social media) works on **any Android phone**. The Stage 2 list is Xiaomi-specific — other manufacturers have their own bloatware packages. Run with `--distractions-only` to skip it, or replace `lists/xiaomi.txt` with your phone's packages.

**Samsung:** Common targets: Samsung Internet (`com.sec.android.app.sbrowser`), Samsung Free, Bixby, Galaxy Store.

**Pixel:** Stage 2 is mostly unnecessary — Pixels ship relatively clean. You may want to remove Google TV, Google One, and YouTube Music.

**OnePlus:** Look for `com.oneplus.*` and `com.heytap.*` packages.

To see every package on your phone:
```bash
~/platform-tools/adb shell pm list packages
```

## OTA Updates

Monthly security patches and minor updates **will not** reinstall removed apps. A major OS upgrade (e.g., HyperOS 2 → 3) **might** bring some back. If that happens, just run the script again — it only touches what came back, and takes 2 minutes. `--dry-run` first shows you what returned.

## FAQ

**Will this brick my phone?**
No. These commands remove apps at the user level, not the system level, and the script refuses to touch core system apps (System UI, Settings, Security, launcher, Play Services, WebView). The worst case is an app you need is gone — and you restore it with one command.

**Can I do this without a computer?**
There's an app called [Canta](https://github.com/samolego/Canta) that uses Shizuku to remove system apps directly from your phone. It works, but it also means you can easily undo everything *from your phone* — which defeats the purpose if your goal is behavioral friction.

**What about WhatsApp updates?**
WhatsApp will eventually stop working if it's too outdated. Keep the Play Store available (disable/enable as described above) and update every few weeks.

**I use passkeys. Is removing Chrome a problem?**
Possibly. On some phones Chrome stores passkeys. If you rely on them, comment out Chrome in `lists/distractions.txt` before running, or check that your passkeys still work afterwards (Google Play Services handles them on many phones).

**The script said "disabled" instead of "removed".**
Xiaomi blocks uninstalling some of its apps (Mi Browser, for one). Disabling hides the app and stops it from running, which is just as boring. It's recorded in the restore script like everything else.

**Some apps show as FAILED.**
The phone refused both uninstalling and disabling them. That's HyperOS protecting its own packages. Nothing was changed for those apps, and the log has the phone's exact error. If one of them bothers you, open an issue with that line.

**I use Second Space or a work profile.**
The script only cleans your main user (user 0). The other space keeps its own apps.

**My phone feels weird / notifications are broken after Stage 2.**
Run the restore script to undo everything, then re-run with `--distractions-only`. Most people only need Stage 1 (distraction removal). Stage 2 (Xiaomi bloatware) is a nice-to-have.

**I got through a week and I want the browser back.**
Ask yourself why. If it's for a genuine task, use your laptop. If you're just uncomfortable with boredom, that's the point. The discomfort fades. The attention span comes back.

## Contributing

This repo covers Xiaomi / Redmi / POCO phones. If you've done the same on Samsung, Pixel, OnePlus, or other manufacturers, open a PR with your bloatware list. Keep the same philosophy: remove distractions, keep essentials, make it reversible.

Found an app the lists missed? Open an issue with your phone model, OS version, and the package name (the dry-run snapshot in `~/boring-phone-logs/` has every package on your phone).

## License

MIT — do whatever you want with it.

## Credits

Built during a broader experiment in putting behavioral change on rails instead of relying on willpower. The opposite of "just have more discipline" is "design your environment so discipline is irrelevant."

Package notes come from the [Universal Android Debloater (Next Generation)](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation) community list.
