#!/usr/bin/env python3
"""Clean Phone — a small local web page for picking what to remove.

Usage: python3 ui.py [--port 8765] [--no-browser] [--adb /path/to/adb]

The page shows the apps on the plugged-in phone, ticked according to lists/,
and removes the ones you tick. Everything stays on this computer: the page talks
to this script on 127.0.0.1, and this script talks to the phone over adb.
No dependencies beyond Python 3.9+.
"""

import argparse
import json
import re
import secrets
import shutil
import subprocess
import sys
import threading
import webbrowser
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parent
LIST_DIR = ROOT / "lists"
PAGE = ROOT / "ui" / "index.html"
LOG_DIR = Path.home() / "boring-phone-logs"

PKG_RE = re.compile(r"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$")
COMPONENT_RE = re.compile(r"^\s*([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+)/[A-Za-z0-9_.$]+\s*$")

# App rules shared with the hosted page (web/): essentials, locked apps, what removing
# a kept app costs, and names for common apps adb can't name. See ui/apps.json.
APPS = json.loads((ROOT / "ui" / "apps.json").read_text(encoding="utf-8"))
# Checked after every run. Any one package per row counts.
ESSENTIALS = [(e["name"], e["packages"]) for e in APPS["essentials"]]
# Never removed: losing these can stop the phone booting, or break calls (emergency calls too) and texts.
LOCKED_ESSENTIALS = tuple(APPS["locked_essentials"])
PROTECTED = set(APPS["core_protected"]) | {pkg for name, pkgs in ESSENTIALS if name in LOCKED_ESSENTIALS for pkg in pkgs}
# The other essentials are kept unless you tick them on the page.
KEPT = {pkg: (k["label"], k["note"]) for pkg, k in APPS["kept"].items()}
# Which brand list (Stage 2) goes with which manufacturer. Other phones get Stage 1 only.
BRANDS = APPS["brands"]
KNOWN_NAMES = APPS["known_names"]

ADB = None
TOKEN = secrets.token_urlsafe(16)
SESSION = datetime.now().strftime("%Y%m%d_%H%M%S")
LOG_LOCK = threading.Lock()
PROPS_CACHE = {}


# --- adb ---------------------------------------------------------------------

def find_adb(explicit):
    if explicit:
        return explicit
    found = shutil.which("adb")
    if found:
        return found
    home = Path.home()
    for candidate in (Path("/opt/homebrew/bin/adb"), Path("/usr/local/bin/adb"),
                      home / "platform-tools" / "adb", home / "platform-tools" / "adb.exe",
                      home / "Library" / "Android" / "sdk" / "platform-tools" / "adb",
                      home / "Android" / "Sdk" / "platform-tools" / "adb",
                      Path("C:/adb/platform-tools/adb.exe")):
        if candidate.exists():
            return str(candidate)
    return None


def adb(*args, serial=None, timeout=60):
    cmd = [ADB] + (["-s", serial] if serial else []) + list(args)
    try:
        done = subprocess.run(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                              stderr=subprocess.STDOUT, text=True, timeout=timeout)
    except subprocess.TimeoutExpired:
        return "error: adb timed out"
    return done.stdout.replace("\r", "")


def package_set(serial, *flags):
    out = adb("shell", "pm", "list", "packages", *flags, serial=serial)
    return {line[len("package:"):].strip() for line in out.splitlines() if line.startswith("package:")}


def handlers(serial, *intent):
    """Packages with an activity matching the intent (disabled apps don't count)."""
    out = adb("shell", "cmd", "package", "query-activities", "--brief", *intent, serial=serial)
    found = set()
    for line in out.splitlines():
        match = COMPONENT_RE.match(line)
        if match:
            found.add(match.group(1))
    return found


def browsers(serial):
    return sorted(handlers(serial, "-a", "android.intent.action.VIEW",
                           "-c", "android.intent.category.BROWSABLE", "-d", "https://example.com"))


def device_status():
    if not ADB:
        return {"state": "no-adb"}
    lines = adb("devices", timeout=15).splitlines()
    devices = []
    for line in lines:
        parts = line.split()
        if len(parts) >= 2 and parts[0] not in ("List", "*"):
            devices.append({"serial": parts[0], "state": parts[1]})
    if not devices:
        return {"state": "none"}
    if len(devices) > 1:
        return {"state": "multiple", "devices": devices}
    serial, state = devices[0]["serial"], devices[0]["state"]
    if state != "device":
        return {"state": state, "serial": serial}
    if serial not in PROPS_CACHE:
        def prop(name):
            return adb("shell", "getprop", name, serial=serial).strip()
        PROPS_CACHE[serial] = {
            "manufacturer": prop("ro.product.manufacturer"),
            # Xiaomi's model is a code like 2510DRA23E; marketname is "REDMI Note 15".
            "model": prop("ro.product.marketname") or prop("ro.product.model"),
            "android": prop("ro.build.version.release"),
            "os": prop("ro.build.version.incremental"),
        }
    return dict({"state": "device", "serial": serial}, **PROPS_CACHE[serial])


def current_serial():
    status = device_status()
    return status["serial"] if status["state"] == "device" else None


# --- lists and logs ----------------------------------------------------------

def split_note(text):
    """'Joyose (why it matters)' -> ('Joyose', 'why it matters')."""
    match = re.match(r"^(.*?)\s*\((.*)\)\s*$", text)
    return (match.group(1), match.group(2)) if match else (text, "")


def brand_for(manufacturer):
    return next((b for b in BRANDS if manufacturer.lower() in b["manufacturers"]), None)


def lists_for(serial):
    """distractions.txt for every phone, plus the brand's own list when there is one."""
    brand = brand_for(PROPS_CACHE.get(serial, {}).get("manufacturer", ""))
    return lists_for_brand(brand["id"] if brand else None)


def lists_for_brand(brand_id):
    lists = [("distractions", LIST_DIR / "distractions.txt")]
    brand = next((b for b in BRANDS if b["id"] == brand_id), None)
    if brand:
        lists.append((brand["id"], LIST_DIR / brand["list"]))
    return lists


def read_lists(lists):
    """Groups from the list files. A commented-out package line is shown but not ticked."""
    groups = []
    for stage, path in lists:
        current = None
        for raw in path.read_text(encoding="utf-8").splitlines():
            line = raw.strip()
            if line.startswith("## "):
                title, note = split_note(line[3:].strip().split(". ")[0])
                current = {"stage": stage, "title": title, "note": note, "apps": []}
                groups.append(current)
                continue
            ticked = not line.startswith("#")
            parts = line.lstrip("#").split(None, 1)
            if not parts or not PKG_RE.match(parts[0]):
                continue
            if current is None:
                current = {"stage": stage, "title": stage.title(), "note": "", "apps": []}
                groups.append(current)
            label, note = split_note(parts[1].strip() if len(parts) > 1 else parts[0])
            current["apps"].append({"package": parts[0], "label": label, "note": note, "ticked": ticked})
    return groups


def logged_history():
    """From every log in ~/boring-phone-logs (script or page): packages ever removed or disabled,
    and packages whose latest attempt the phone refused."""
    removed, last = set(), {}
    logs = sorted(LOG_DIR.glob("*.log"), key=lambda p: p.stat().st_mtime) if LOG_DIR.exists() else []
    for log_file in logs:
        for line in log_file.read_text(encoding="utf-8", errors="replace").splitlines():
            action = line.split(": ", 1)[0]
            if action in ("REMOVED", "DISABLED", "FAILED", "RESTORED"):
                pkg = line.split()[1]
                last[pkg] = action
                if action in ("REMOVED", "DISABLED"):
                    removed.add(pkg)
    return removed, {pkg for pkg, action in last.items() if action == "FAILED"}


def log(line, serial=None):
    with LOG_LOCK:
        LOG_DIR.mkdir(exist_ok=True)
        log_file = LOG_DIR / ("ui_%s.log" % SESSION)
        if not log_file.exists():
            snapshot = LOG_DIR / ("packages_before_%s.txt" % SESSION)
            if serial and not snapshot.exists():
                snapshot.write_text("".join("package:%s\n" % p for p in sorted(package_set(serial))), encoding="utf-8")
            info = PROPS_CACHE.get(serial, {})
            log_file.write_text("Clean Phone — page log\nTimestamp: %s\nDevice: %s %s (%s), Android %s, %s\n---\n" % (
                SESSION, info.get("manufacturer", ""), info.get("model", ""), serial,
                info.get("android", ""), info.get("os", "")), encoding="utf-8")
        with log_file.open("a", encoding="utf-8") as f:
            f.write(line + "\n")


def friendly_name(pkg):
    if pkg in KNOWN_NAMES:
        return KNOWN_NAMES[pkg]
    parts = [p for p in pkg.split(".") if p not in ("com", "org", "net", "android", "app", "apps", "mobile", "client", "global")]
    word = parts[-1] if parts else pkg
    return word[:1].upper() + word[1:]


# --- actions -----------------------------------------------------------------

def phone_overview(serial):
    installed = package_set(serial)
    disabled = package_set(serial, "-d")
    everything = package_set(serial, "-u")
    active = installed - disabled
    groups = read_lists(lists_for(serial))
    listed = {app["package"]: app for group in groups for app in group["apps"]}
    names = {pkg: app["label"] for pkg, app in listed.items()}
    ever_removed, refused = logged_history()

    shown_groups = []
    for group in groups:
        apps = []
        for app in group["apps"]:
            if app["package"] not in active or app["package"] in PROTECTED:
                continue
            if app["package"] in refused:
                # Ticking it again would just fail again.
                app = dict(app, ticked=False, refused=True)
            apps.append(app)
        if apps:
            shown_groups.append(dict(group, apps=apps))

    kept = [{"package": p, "label": label, "note": note, "ticked": False}
            for p, (label, note) in KEPT.items() if p in active and p not in listed]
    if kept:
        shown_groups.append({"stage": "kept", "title": "Your essentials", "note": "", "apps": kept})
    names.update({p: label for p, (label, _) in KEPT.items()})

    launcher = handlers(serial, "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER")
    other = sorted(({"package": p, "label": friendly_name(p)} for p in launcher & active
                    if p not in listed and p not in KEPT and p not in PROTECTED), key=lambda a: a["label"].lower())

    gone = (everything - installed) | disabled
    ours = set(listed) | set(KEPT) | ever_removed
    removed = sorted(({"package": p, "label": names.get(p) or friendly_name(p),
                       "state": "disabled" if p in disabled else "removed"} for p in gone & ours),
                     key=lambda a: a["label"].lower())

    essentials = [{"name": name, "installed": any(p in active for p in pkgs), "locked": name in LOCKED_ESSENTIALS}
                  for name, pkgs in ESSENTIALS]
    return {"groups": shown_groups, "other": other, "removed": removed,
            "essentials": essentials, "browsers": browsers(serial)}


def preview(brand_id):
    """A sample of what the page shows once a phone is connected, built from the lists alone:
    a few well-known apps per group (APPS["preview"]), and how many more each group holds."""
    picks = set(APPS["preview"]["common"]) | set(APPS["preview"].get(brand_id, []))
    groups = []
    for group in read_lists(lists_for_brand(brand_id)):
        ticked = [app for app in group["apps"] if app["ticked"]]
        sample = [app for app in ticked if app["package"] in picks]
        if sample:
            groups.append(dict(group, apps=sample, more=len(ticked) - len(sample)))
    kept = [{"package": p, "label": KEPT[p][0], "note": KEPT[p][1], "ticked": False} for p in APPS["preview"]["kept"]]
    groups.append({"stage": "kept", "title": "Your essentials", "note": "", "apps": kept, "more": 0})
    browsers = ["com.android.chrome"] + [p for p in APPS["preview"].get(brand_id, []) if p in ("com.mi.globalbrowser", "com.sec.android.app.sbrowser")]
    return {"preview": True, "groups": groups, "other": [], "removed": [], "browsers": browsers,
            "essentials": [{"name": n, "installed": True, "locked": n in LOCKED_ESSENTIALS} for n, _ in ESSENTIALS]}


def remove_app(serial, pkg, label):
    if pkg in PROTECTED:
        return {"status": "protected", "detail": "Protected — never removed."}
    out = adb("shell", "pm", "uninstall", "-k", "--user", "0", pkg, serial=serial).strip()
    if "Success" in out:
        log("REMOVED: %s — %s" % (pkg, label), serial)
        return {"status": "removed"}
    if "not installed for" in out:
        return {"status": "skipped", "detail": "Already gone."}
    # Some system apps refuse to uninstall (Mi Browser has, since MIUI 12). Disabling hides them just as well.
    disable_out = adb("shell", "pm", "disable-user", "--user", "0", pkg, serial=serial).strip()
    if "new state: disabled-user" in disable_out:
        log("DISABLED: %s — %s (uninstall said: %s)" % (pkg, label, " ".join(out.split())), serial)
        return {"status": "disabled"}
    log("FAILED: %s — %s | uninstall: %s | disable: %s" % (pkg, label, " ".join(out.split()), " ".join(disable_out.split())), serial)
    return {"status": "failed", "detail": out or disable_out}


def restore_app(serial, pkg):
    if pkg in package_set(serial, "-d"):
        out = adb("shell", "pm", "enable", pkg, serial=serial).strip()
        ok = "new state: enabled" in out
    else:
        out = adb("shell", "cmd", "package", "install-existing", pkg, serial=serial).strip()
        ok = "installed for user" in out
    if ok:
        log("RESTORED: %s" % pkg, serial)
        return {"status": "restored"}
    log("RESTORE FAILED: %s | %s" % (pkg, " ".join(out.split())), serial)
    return {"status": "failed", "detail": "Couldn't bring it back. If you installed it yourself, reinstall it from the Play Store."}


# --- web server --------------------------------------------------------------

class Handler(BaseHTTPRequestHandler):
    server_version = "CleanPhone"

    def log_message(self, fmt, *args):
        pass

    def send(self, code, body, content_type="application/json"):
        data = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", content_type + "; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def json(self, obj, code=200):
        self.send(code, json.dumps(obj))

    def allowed(self, api):
        # Only this machine, and for the API only the page we served (it carries the token).
        # The custom header also makes browsers refuse cross-site requests to it.
        port = self.server.server_address[1]
        if self.headers.get("Host") not in ("127.0.0.1:%d" % port, "localhost:%d" % port):
            return False
        return not api or secrets.compare_digest(self.headers.get("X-Boring-Token", ""), TOKEN)

    def do_GET(self):
        if self.path == "/":
            if not self.allowed(api=False):
                return self.send(403, "Forbidden", "text/plain")
            return self.send(200, PAGE.read_text(encoding="utf-8").replace("__TOKEN__", TOKEN), "text/html")
        if not self.allowed(api=True):
            return self.json({"error": "forbidden"}, 403)
        if self.path == "/api/status":
            return self.json(device_status())
        if self.path.startswith("/api/preview"):
            brand = parse_qs(urlparse(self.path).query).get("brand", [""])[0]
            return self.json(preview(brand))
        if self.path == "/api/phone":
            serial = current_serial()
            if not serial:
                return self.json({"error": "No phone connected."}, 409)
            return self.json(dict(phone_overview(serial), serial=serial))
        return self.json({"error": "not found"}, 404)

    def do_POST(self):
        if not self.allowed(api=True):
            return self.json({"error": "forbidden"}, 403)
        try:
            body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))) or b"{}")
        except ValueError:
            return self.json({"error": "bad json"}, 400)
        pkg = str(body.get("package", ""))
        if not PKG_RE.match(pkg):
            return self.json({"error": "bad package name"}, 400)
        serial = current_serial()
        if not serial or body.get("serial") != serial:
            return self.json({"error": "The phone changed or was unplugged. Reload the page."}, 409)
        if self.path == "/api/remove":
            return self.json(remove_app(serial, pkg, str(body.get("label", pkg))[:120]))
        if self.path == "/api/restore":
            return self.json(restore_app(serial, pkg))
        return self.json({"error": "not found"}, 404)


def main():
    global ADB
    parser = argparse.ArgumentParser(description="Clean Phone — pick what to remove, in your browser.")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--no-browser", action="store_true", help="don't open the browser")
    parser.add_argument("--adb", help="path to adb, if it's not on PATH or in ~/platform-tools")
    args = parser.parse_args()

    ADB = find_adb(args.adb)
    if ADB:
        adb("start-server", timeout=30)
    else:
        print("⚠️  adb not found — the page will show how to install it.")

    server = None
    for port in (args.port, args.port + 1, args.port + 2, 0):
        try:
            server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
            break
        except OSError:
            continue
    url = "http://127.0.0.1:%d/" % server.server_address[1]
    print("📱 Clean Phone is running at %s" % url)
    print("   Keep this window open while you use it. Press Ctrl+C to quit.")
    if not args.no_browser:
        threading.Timer(0.5, webbrowser.open, [url]).start()
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nBye. Your phone is as clean as you left it.")
    finally:
        server.server_close()


if __name__ == "__main__":
    sys.exit(main())
