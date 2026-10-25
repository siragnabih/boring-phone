// Clean Phone, hosted: the same page as ui/index.html, but instead of asking ui.py
// it talks to the phone itself over WebUSB (Chrome, Edge, Brave, Opera).
// It answers the same /api/* requests ui.py does, so the page doesn't need to know the difference.

import { Adb, AdbDaemonTransport } from "@yume-chan/adb";
import AdbWebCredentialStore from "@yume-chan/adb-credential-web";
import {
  AdbDaemonWebUsbDevice,
  AdbDaemonWebUsbDeviceManager,
  AdbDefaultInterfaceFilter,
  findUsbInterface,
} from "@yume-chan/adb-daemon-webusb";
import APPS from "../../ui/apps.json";
import distractions from "../../lists/distractions.txt?raw";
import xiaomi from "../../lists/xiaomi.txt?raw";
import samsung from "../../lists/samsung.txt?raw";
import pixel from "../../lists/pixel.txt?raw";

const LIST_FILES = { "xiaomi.txt": xiaomi, "samsung.txt": samsung, "pixel.txt": pixel };
const PKG_RE = /^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$/;
const COMPONENT_RE = /^\s*([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+)\/[A-Za-z0-9_.$]+\s*$/;

// Phone makers' USB vendor IDs, so the picker also lists phones whose USB debugging is still off
// and the page can say so, instead of the phone silently missing from the list.
const PHONE_VENDORS = [
  0x2717, // Xiaomi, Redmi, POCO
  0x18d1, // Google
  0x04e8, // Samsung
  0x2a70, // OnePlus
  0x22b8, // Motorola
  0x12d1, // Huawei
  0x22d9, // OPPO, realme
  0x2d95, // vivo
  0x0fce, // Sony
  0x1004, // LG
  0x0b05, // ASUS
  0x17ef, // Lenovo
  0x19d2, // ZTE
  0x2e04, // HMD (Nokia)
  0x2ae5, // Fairphone
];

const LOCKED = new Set(APPS.locked_essentials);
const PROTECTED = new Set([
  ...APPS.core_protected,
  ...APPS.essentials.filter((e) => LOCKED.has(e.name)).flatMap((e) => e.packages),
]);

const manager = AdbDaemonWebUsbDeviceManager.BROWSER;
const credentials = new AdbWebCredentialStore("Clean Phone");
// A link shared on WhatsApp usually gets opened on a phone, which can't plug into itself.
// (Android's Chrome has WebUSB, iPhones don't; either way the page should send them to a computer.)
const onPhone = navigator.userAgentData?.mobile ?? /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent);
let status = onPhone ? { state: "on-phone" } : manager ? { state: "none" } : { state: "unsupported" };
let adb = null;
let usbDevice = null;

function setStatus(next) {
  status = next;
  backend.onChange?.();
}

// --- connecting ----------------------------------------------------------

function hasAdbInterface(device) {
  return Boolean(findUsbInterface(device, AdbDefaultInterfaceFilter));
}

// Called from a click: the browser only opens its device picker in response to one.
async function connect() {
  let picked;
  try {
    picked = await navigator.usb.requestDevice({
      filters: [AdbDefaultInterfaceFilter, ...PHONE_VENDORS.map((vendorId) => ({ vendorId }))],
    });
  } catch {
    return; // picker closed without choosing
  }
  await open(picked);
}

async function open(device) {
  if (adb) return;
  if (!hasAdbInterface(device)) {
    // The phone is connected for file transfer only: no debugging channel to talk to.
    return setStatus({ state: "debugging-off" });
  }
  setStatus({ state: "connecting" });
  const wrapped = new AdbDaemonWebUsbDevice(device, findUsbInterface(device, AdbDefaultInterfaceFilter), navigator.usb);
  let connection;
  try {
    connection = await wrapped.connect();
  } catch (e) {
    if (e instanceof AdbDaemonWebUsbDevice.DeviceBusyError) return setStatus({ state: "busy" });
    return setStatus({ state: "error", message: e.message });
  }
  // A phone that already trusts this browser answers at once; otherwise it shows "Allow USB debugging?".
  const waiting = setTimeout(() => setStatus({ state: "unauthorized" }), 800);
  try {
    const transport = await AdbDaemonTransport.authenticate({
      serial: wrapped.serial,
      connection,
      credentialStore: credentials,
    });
    adb = new Adb(transport);
  } catch (e) {
    return setStatus({ state: "error", message: e.message });
  } finally {
    clearTimeout(waiting);
  }
  usbDevice = device;
  adb.disconnected.then(() => dropped(device));
  setStatus({
    state: "device",
    serial: adb.serial,
    manufacturer: await adb.getProp("ro.product.manufacturer"),
    // Xiaomi's model is a code like 2510DRA23E; marketname is "REDMI Note 15".
    model: (await adb.getProp("ro.product.marketname")) || (await adb.getProp("ro.product.model")),
    android: await adb.getProp("ro.build.version.release"),
    os: await adb.getProp("ro.build.version.incremental"),
  });
}

function dropped(device) {
  if (usbDevice !== device) return;
  adb = null;
  usbDevice = null;
  setStatus({ state: "none" });
}

if (manager && !onPhone) {
  // A phone this browser was already allowed to use connects without the picker.
  navigator.usb.getDevices().then((devices) => {
    const phone = devices.find(hasAdbInterface);
    if (phone) open(phone);
  });
  navigator.usb.addEventListener("connect", (e) => {
    if (hasAdbInterface(e.device)) open(e.device);
  });
  navigator.usb.addEventListener("disconnect", (e) => {
    if (e.device === usbDevice) adb?.close().catch(() => {});
    dropped(e.device);
  });
}

// --- the phone -------------------------------------------------------------

async function sh(command) {
  return (await adb.subprocess.noneProtocol.spawnWaitText(command)).replaceAll("\r", "");
}

async function packageSet(flags = "") {
  const out = await sh(`pm list packages ${flags}`);
  return new Set(out.split("\n").filter((l) => l.startsWith("package:")).map((l) => l.slice(8).trim()));
}

// Packages with an activity matching the intent (disabled apps don't count).
async function handlers(intent) {
  const out = await sh(`cmd package query-activities --brief ${intent}`);
  const found = new Set();
  for (const line of out.split("\n")) {
    const match = line.match(COMPONENT_RE);
    if (match) found.add(match[1]);
  }
  return found;
}

// --- lists and history -------------------------------------------------------

function splitNote(text) {
  const match = text.match(/^(.*?)\s*\((.*)\)\s*$/);
  return match ? [match[1], match[2]] : [text, ""];
}

// distractions.txt for every phone, plus the brand's own list when there is one.
function listsForPhone() {
  const maker = (status.manufacturer || "").toLowerCase();
  return listsForBrand(APPS.brands.find((b) => b.manufacturers.includes(maker))?.id);
}

function listsForBrand(brandId) {
  const brand = APPS.brands.find((b) => b.id === brandId);
  return [["distractions", distractions], ...(brand ? [[brand.id, LIST_FILES[brand.list]]] : [])];
}

// Groups from the list files. A commented-out package line is shown but not ticked.
function readLists(lists) {
  const groups = [];
  for (const [stage, text] of lists) {
    let current = null;
    for (const raw of text.split("\n")) {
      const line = raw.trim();
      if (line.startsWith("## ")) {
        const [title, note] = splitNote(line.slice(3).trim().split(". ")[0]);
        current = { stage, title, note, apps: [] };
        groups.push(current);
        continue;
      }
      const match = line.replace(/^#+/, "").trim().match(/^(\S+)\s*(.*)$/);
      if (!match || !PKG_RE.test(match[1])) continue;
      if (!current) {
        current = { stage, title: stage, note: "", apps: [] };
        groups.push(current);
      }
      const [label, note] = splitNote(match[2] || match[1]);
      current.apps.push({ package: match[1], label, note, ticked: !line.startsWith("#") });
    }
  }
  return groups;
}

function friendlyName(pkg) {
  if (APPS.known_names[pkg]) return APPS.known_names[pkg];
  const skip = new Set(["com", "org", "net", "android", "app", "apps", "mobile", "client", "global"]);
  const parts = pkg.split(".").filter((p) => !skip.has(p));
  const word = parts.at(-1) || pkg;
  return word[0].toUpperCase() + word.slice(1);
}

// What this browser did to each package on this phone, so the Removed tab and the
// "refused last time" note work across visits. ui.py keeps the same thing in its log files.
function history() {
  try {
    return JSON.parse(localStorage.getItem("boring-phone:" + status.serial)) || {};
  } catch {
    return {};
  }
}

function remember(pkg, action) {
  console.info(`Clean Phone: ${action} ${pkg}`);
  try {
    localStorage.setItem("boring-phone:" + status.serial, JSON.stringify({ ...history(), [pkg]: action }));
  } catch {
    // Private windows can refuse storage; history is a convenience, not a requirement.
  }
}

// --- actions -----------------------------------------------------------------

async function phoneOverview() {
  const installed = await packageSet();
  const disabled = await packageSet("-d");
  const everything = await packageSet("-u");
  const active = new Set([...installed].filter((p) => !disabled.has(p)));
  const groups = readLists(listsForPhone());
  const listed = new Map(groups.flatMap((g) => g.apps.map((a) => [a.package, a])));
  const names = new Map([...listed].map(([p, a]) => [p, a.label]));
  const past = history();

  const shown = [];
  for (const group of groups) {
    const apps = group.apps
      .filter((a) => active.has(a.package) && !PROTECTED.has(a.package))
      // Ticking it again would just fail again.
      .map((a) => (past[a.package] === "FAILED" ? { ...a, ticked: false, refused: true } : a));
    if (apps.length) shown.push({ ...group, apps });
  }

  const kept = Object.entries(APPS.kept)
    .filter(([p]) => active.has(p) && !listed.has(p))
    .map(([p, k]) => ({ package: p, label: k.label, note: k.note, ticked: false }));
  if (kept.length) shown.push({ stage: "kept", title: "Your essentials", note: "", apps: kept });
  for (const [p, k] of Object.entries(APPS.kept)) names.set(p, k.label);

  const launcher = await handlers("-a android.intent.action.MAIN -c android.intent.category.LAUNCHER");
  const other = [...launcher]
    .filter((p) => active.has(p) && !listed.has(p) && !(p in APPS.kept) && !PROTECTED.has(p))
    .map((p) => ({ package: p, label: friendlyName(p) }))
    .sort((a, b) => a.label.localeCompare(b.label));

  const ours = new Set([...listed.keys(), ...Object.keys(APPS.kept), ...Object.keys(past).filter((p) => past[p] !== "FAILED")]);
  const removed = [...everything]
    .filter((p) => (!installed.has(p) || disabled.has(p)) && ours.has(p))
    .map((p) => ({ package: p, label: names.get(p) || friendlyName(p), state: disabled.has(p) ? "disabled" : "removed" }))
    .sort((a, b) => a.label.localeCompare(b.label));

  const essentials = APPS.essentials.map((e) => ({
    name: e.name,
    installed: e.packages.some((p) => active.has(p)),
    locked: LOCKED.has(e.name),
  }));
  const browsers = [...(await handlers(
    "-a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d https://example.com",
  ))].sort();
  return { groups: shown, other, removed, essentials, browsers };
}

// A sample of what the page shows once a phone is connected, built from the lists alone:
// a few well-known apps per group (APPS.preview), and how many more each group holds.
function preview(brandId) {
  const picks = new Set([...APPS.preview.common, ...(APPS.preview[brandId] || [])]);
  const groups = [];
  for (const group of readLists(listsForBrand(brandId))) {
    const ticked = group.apps.filter((a) => a.ticked);
    const sample = ticked.filter((a) => picks.has(a.package));
    if (sample.length) groups.push({ ...group, apps: sample, more: ticked.length - sample.length });
  }
  const kept = APPS.preview.kept.map((p) => ({ package: p, label: APPS.kept[p].label, note: APPS.kept[p].note, ticked: false }));
  groups.push({ stage: "kept", title: "Your essentials", note: "", apps: kept, more: 0 });
  const browsers = ["com.android.chrome", ...(APPS.preview[brandId] || []).filter((p) => ["com.mi.globalbrowser", "com.sec.android.app.sbrowser"].includes(p))];
  const essentials = APPS.essentials.map((e) => ({ name: e.name, installed: true, locked: LOCKED.has(e.name) }));
  return { preview: true, groups, other: [], removed: [], browsers, essentials };
}

async function removeApp(pkg) {
  if (PROTECTED.has(pkg)) return { status: "protected", detail: "Protected — never removed." };
  const out = (await sh(`pm uninstall -k --user 0 ${pkg}`)).trim();
  if (out.includes("Success")) {
    remember(pkg, "REMOVED");
    return { status: "removed" };
  }
  if (out.includes("not installed for")) return { status: "skipped", detail: "Already gone." };
  // Some system apps refuse to uninstall (Mi Browser has, since MIUI 12). Disabling hides them just as well.
  const disableOut = (await sh(`pm disable-user --user 0 ${pkg}`)).trim();
  if (disableOut.includes("new state: disabled-user")) {
    remember(pkg, "DISABLED");
    return { status: "disabled" };
  }
  remember(pkg, "FAILED");
  console.warn(`Clean Phone: ${pkg} refused.`, { uninstall: out, disable: disableOut });
  return { status: "failed", detail: out || disableOut };
}

async function restoreApp(pkg) {
  const disabled = await packageSet("-d");
  const out = disabled.has(pkg)
    ? await sh(`pm enable ${pkg}`)
    : await sh(`cmd package install-existing ${pkg}`);
  if (out.includes("new state: enabled") || out.includes("installed for user")) {
    remember(pkg, "RESTORED");
    return { status: "restored" };
  }
  return { status: "failed", detail: "Couldn't bring it back. If you installed it yourself, reinstall it from the Play Store." };
}

async function request(path, body) {
  if (path === "/api/status") return status;
  if (path.startsWith("/api/preview")) return preview(new URL(path, location.href).searchParams.get("brand"));
  if (!adb || status.state !== "device") throw new Error("No phone connected.");
  if (path === "/api/phone") return { ...(await phoneOverview()), serial: status.serial };
  const pkg = String(body?.package ?? "");
  // Package names go into shell commands, so only accept real ones.
  if (!PKG_RE.test(pkg)) throw new Error("bad package name");
  if (body.serial !== status.serial) throw new Error("The phone changed or was unplugged. Reload the page.");
  if (path === "/api/remove") return removeApp(pkg);
  if (path === "/api/restore") return restoreApp(pkg);
  throw new Error("not found");
}

const backend = { request, connect, onChange: null };
window.boringBackend = backend;
