# Boring Phone (Proyecto Vorágine)

Get a cheap Android phone, and make it boring on purpose.

This is a one-command setup that strips an Android phone (Xiaomi, Samsung, or Pixel) down to calls, messages, WhatsApp, Gmail, camera, and maps. No browser. No YouTube. No social media. No manufacturer bloatware. No willpower required.

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

None of these are on the lists, so they stay unless you choose otherwise (the [page](#4-the-easy-way-pick-apps-in-your-browser) lets you tick WhatsApp, Gmail, Maps, Camera, or the Play Store on purpose). **Phone and Messages are locked**, along with core system apps like Settings, Play Services, and the launcher: losing them can break calls (emergency calls included), texts, or the whole phone, so both the page and the scripts refuse to remove them.

## What Gets Removed

**Stage 1 — distractions** ([`lists/distractions.txt`](lists/distractions.txt)):

- ❌ Every common browser (Mi Browser, Chrome, Samsung Internet, Opera, Edge, Firefox, Brave, …)
- ❌ The Google app (Search, Discover feed, Assistant, Circle to Search), Gemini, Google Lens, Google News
- ❌ YouTube, YouTube Music, Netflix, Prime Video, Spotify, Google TV
- ❌ Facebook, Instagram, TikTok, Snapchat, X, Reddit, LinkedIn, …
- ❌ The games and shopping apps phone makers preinstall (Block Blast, Candy Crush, Solitaire, Temu, AliExpress, Amazon, …)

**Stage 2 — the phone maker's own clutter**, picked automatically from the brand:

- **Xiaomi / Redmi / POCO** ([`lists/xiaomi.txt`](lists/xiaomi.txt)): the ad engine, analytics and telemetry; GetApps, App Vault, Xiaomi news feeds, Quick Apps, Mi Store, Mi Community; Mi Video, Mi Music, Wallpaper Carousel, Game Center, Mi Credit, and more
- **Samsung Galaxy** ([`lists/samsung.txt`](lists/samsung.txt)): Bixby, the ad-profile Customization Service and analytics; Samsung Members, Tips, Samsung Shop; Game Launcher; AR Zone and AR Emoji; preloaded Microsoft apps
- **Google Pixel** ([`lists/pixel.txt`](lists/pixel.txt)): short on purpose. Pixels ship clean, and Stage 1 already covers YouTube, Google TV, and the Google app
- **Any other Android phone:** Stage 1 only, until someone adds a list (see [Adapting for Other Phones](#adapting-for-other-phones))

Only apps that are actually on your phone get touched. Everything ticked in Stage 2 is rated safe to remove by the [Universal Android Debloater](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation) community list. The riskier ones (Joyose, Xiaomi AI Engine, Galaxy Store) are in the lists but commented out.

## Requirements

- A Xiaomi / Redmi / POCO, Samsung Galaxy, or Google Pixel phone (tested on a Redmi Note 15 with HyperOS 3; Samsung and Pixel support is built from the UAD community list and hasn't been tried on a real one yet). Any other Android phone gets Stage 1.
- A computer (Mac, Windows, or Linux)
- A USB-C cable that carries data (some only charge)
- 30 minutes


## Quick Start

### 0. Get the Files

Click **Code → Download ZIP** on GitHub and unzip it, or:

```bash
git clone https://github.com/siragnabih/boring-phone.git
```

Keep the `lists` folder next to the scripts — that's where the app lists live.

### 1. Enable USB Debugging on Your Phone

| | Turn on developer mode (tap 7 times) | Then turn on USB debugging in |
|---|---|---|
| **Xiaomi** | Settings → About phone → **OS version** (MIUI version on older phones) | Settings → Additional settings → Developer options |
| **Samsung** | Settings → About phone → Software information → **Build number** | Settings → Developer options (at the very bottom) |
| **Pixel** | Settings → About phone → **Build number** | Settings → System → Developer options |

You'll see "You are now a developer" after the seventh tap. On Xiaomi you don't need "Install via USB" or "USB debugging (Security settings)". Those need a Xiaomi account, and nothing here uses them.

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

### 4. The Easy Way: Pick Apps in Your Browser

Prefer ticking boxes to editing text files? Run the page instead of the script:

```bash
python3 ui.py
```

On a Mac you can also double-click **Clean Phone.command** in Finder (the first time, right-click → Open, because macOS is wary of downloaded scripts).

It opens a page in your browser, called **Clean Phone** (a friendlier name for people setting up a phone for someone else, like a teenager), that:

- shows, before you plug anything in, a preview of what you'll see, behind a veil, so you know what you're getting into

- shows the apps it finds **on your phone**, grouped like the lists, with the recommended ones already ticked
- tells you whether the phone **can still browse the web**, and through which app
- lists every other app with an icon, unticked, in case you want more gone
- lets you remove your essentials too, Play Store included, with a warning first (Phone and Messages stay locked)
- removes what you tick, live, one app at a time
- has a **Removed** tab where anything can be brought back with one click

It uses the same lists, the same remove-or-disable approach, and the same `~/boring-phone-logs/` folder as the script. Everything stays on your computer: the page only talks to `ui.py` on `127.0.0.1`, and `ui.py` talks to the phone over USB. It needs Python 3.9 or newer, which every recent Mac and Linux has. Windows works too, with Python from python.org.

That's it — you can skip steps 5 and 6.

### 5. Or Use the Script: Do a Dry Run

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

### 6. Run the Script

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
2. **Stage 2 — Bloatware removal:** Strips the phone maker's ads, analytics, telemetry, and junk apps (Xiaomi, Samsung, or Pixel list).

That's it. Your phone is now boring.

#### Options

| Option | What it does |
|---|---|
| `--dry-run` / `-n` | Show what would be removed. Changes nothing on the phone. |
| `--yes` / `-y` | Don't pause between the stages. |
| `--distractions-only` | Run Stage 1 only and leave the phone maker's apps alone. |

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
4. **Falls back to disabling it** if the phone blocks the uninstall (Xiaomi's Mi Browser is known to do this). A disabled app is hidden and can't run — same effect.
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

**Want more friction?** Uninstall it for your user instead. Then only the laptop can bring it back. On the page, tick **Play Store** under *Kept by default*, and bring it back from the *Removed* tab when it's time to update. Or by hand:

```bash
~/platform-tools/adb shell pm uninstall -k --user 0 com.android.vending      # hide
~/platform-tools/adb shell cmd package install-existing com.android.vending  # bring back to update
```

## The Website Version

The same page also works as a website, with nothing to install: no adb, no Python. It talks to the phone straight from the browser over USB ([WebUSB](https://developer.mozilla.org/en-US/docs/Web/API/WebUSB_API), through the [Tango](https://tangoadb.dev) adb library). The phone still needs USB debugging on; the site walks people through it, and tells them when the phone is plugged in but debugging is still off.

- **Browsers:** Chrome, Edge, Brave, or Opera on a computer. Safari and Firefox can't talk to USB devices; the page says so and points to the [local version](#4-the-easy-way-pick-apps-in-your-browser).
- **If adb is installed on the computer**, run `adb kill-server` first: only one program can use the phone's debugging connection at a time.
- **Nothing is uploaded.** The site is static files; all the work happens in the browser tab. It loads nothing from other sites: even its fonts are served by the site itself. The browser keeps its own debugging key (so "Always allow" sticks) and a note of what it removed, for the *Removed* tab.
- **It explains itself.** A *How it works* section, linked from the top of the page, says in plain words what the tool does and never does, lists the exact commands it sends to the phone, and names every library it uses and its license.
- **English and Spanish.** The page picks the language from the browser's settings, and the EN · ES switch in the corner remembers a choice. Before a phone is connected, a "My phone:" switch shows the Developer options steps for Xiaomi, Samsung, Pixel, or other phones. The local page (`ui.py`) gets the same, since it's the same page.

The code is in [`web/`](web/): it builds [`ui/index.html`](ui/index.html), the same page `ui.py` serves, plus [`web/src/webusb.js`](web/src/webusb.js), which does what `ui.py` does but over WebUSB. Both read the same [`lists/`](lists/) and [`ui/apps.json`](ui/apps.json).

### Deploying It on Vercel

1. Push the repo to GitHub.
2. On [vercel.com](https://vercel.com), **Add New → Project** and import the repo.
3. Keep the defaults. [`vercel.json`](vercel.json) already sets the install command, build command, and output folder. They work whether the Root Directory is left empty or set to `web` (Vercel suggests `web` because it finds Vite there).
4. **Deploy.** Every push to `main` redeploys.

To work on it locally:

```bash
cd web
npm install
npm run dev
```

## Turning Off the Ads ADB Can't Reach

Some Xiaomi ads live inside system apps you want to keep. Turn them off in Settings (names vary a little by region and HyperOS version):

- **Ad engine:** Settings → Passwords & security → Authorization & revocation → turn off **msa** (if it's still there)
- **Personalized ads:** Settings → Passwords & security → Privacy → Ad services → turn off **Personalized ad recommendations**
- **In each Xiaomi app** you keep (Security, File Manager, Downloads, Themes): open its settings and turn off **Recommendations** / **Show ads**

## Adapting for Other Phones

Stage 1 (browsers, YouTube, social media) works on **any Android phone**. Stage 2 has lists for Xiaomi, Samsung, and Pixel. For any other brand it's skipped.

To add a brand (OnePlus, Motorola, …):

1. Write `lists/<brand>.txt` in the same format. The [UAD community list](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation) describes thousands of packages and rates how safe each is to remove; stick to its "Recommended" ones.
2. Add the brand to `"brands"` in [`ui/apps.json`](ui/apps.json) (the page and the website), and to the `case "$MANUFACTURER"` block in `debloat.sh` and the matching lines in `debloat.bat`. The manufacturer name is what `adb shell getprop ro.product.manufacturer` prints.
3. If the brand has its own Phone, Messages, Camera, launcher, or keyboard app, add those to `ui/apps.json` and the scripts too, so they're recognized as essentials and locked.

To see every package on your phone:
```bash
~/platform-tools/adb shell pm list packages
```

## OTA Updates

Monthly security patches and minor updates **will not** reinstall removed apps. A major OS upgrade (e.g., HyperOS 2 → 3, or a new One UI) **might** bring some back. If that happens, just run the script again — it only touches what came back, and takes 2 minutes. `--dry-run` first shows you what returned.

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
Some phones block uninstalling some of their own apps (Xiaomi's Mi Browser, for one). Disabling hides the app and stops it from running, which is just as boring. It's recorded in the restore script like everything else.

**Some apps show as FAILED.**
The phone refused both uninstalling and disabling them. That's HyperOS protecting its own packages. Nothing was changed for those apps, and the log has the phone's exact error. If one of them bothers you, open an issue with that line.

**I use Second Space or a work profile.**
The script only cleans your main user (user 0). The other space keeps its own apps.

**My phone feels weird / notifications are broken after Stage 2.**
Run the restore script to undo everything, then re-run with `--distractions-only`. Most people only need Stage 1 (distraction removal). Stage 2 (the maker's bloatware) is a nice-to-have.

**I got through a week and I want the browser back.**
Ask yourself why. If it's for a genuine task, use your laptop. If you're just uncomfortable with boredom, that's the point. The discomfort fades. The attention span comes back.

## Contributing

This repo covers Xiaomi / Redmi / POCO, Samsung, and Pixel phones. Tried it on a Samsung or Pixel? Tell us what it found. Got another brand? Open a PR with its list (see [Adapting for Other Phones](#adapting-for-other-phones)). Keep the same philosophy: remove distractions, keep essentials, make it reversible.

Found an app the lists missed? Open an issue with your phone model, OS version, and the package name (the dry-run snapshot in `~/boring-phone-logs/` has every package on your phone).

## License

MIT — do whatever you want with it.

## Credits

Built during a broader experiment in putting behavioral change on rails instead of relying on willpower. The opposite of "just have more discipline" is "design your environment so discipline is irrelevant."

Package notes come from the [Universal Android Debloater (Next Generation)](https://github.com/Universal-Debloater-Alliance/universal-android-debloater-next-generation) community list.
