#!/usr/bin/env bash
# Boring Phone — Debloat Script (Mac/Linux)
# https://github.com/siragnabih/boring-phone
#
# Usage: bash debloat.sh [--dry-run] [--yes] [--distractions-only]
# Tested on: Redmi Note 15 (HyperOS 2 / Android 15)
# Works on: Any Xiaomi / Redmi / POCO phone with MIUI or HyperOS
#
# What gets removed lives in lists/distractions.txt (Stage 1) and lists/xiaomi.txt (Stage 2).
# Put a # in front of a line there to keep that app.
#
# Written for bash 3.2 so it runs on the bash that ships with macOS.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
STAGE1_LIST="$SCRIPT_DIR/lists/distractions.txt"
STAGE2_LIST="$SCRIPT_DIR/lists/xiaomi.txt"

# --- Options ---
DRY_RUN=false
ASSUME_YES=false
DISTRACTIONS_ONLY=false

usage() {
    cat << 'EOF'
Usage: bash debloat.sh [options]

  -n, --dry-run            Show what would be removed. Changes nothing on the phone.
  -y, --yes                Don't pause between Stage 1 and Stage 2.
      --distractions-only  Run Stage 1 only (skip the Xiaomi bloatware).
  -h, --help               Show this help.

More than one phone plugged in? Pick one:
  ANDROID_SERIAL=<serial> bash debloat.sh
EOF
}

for arg in "$@"; do
    case "$arg" in
        -n|--dry-run)         DRY_RUN=true ;;
        -y|--yes)             ASSUME_YES=true ;;
        --distractions-only)  DISTRACTIONS_ONLY=true ;;
        -h|--help)            usage; exit 0 ;;
        *)                    echo "Unknown option: $arg"; echo ""; usage; exit 1 ;;
    esac
done

for list in "$STAGE1_LIST" "$STAGE2_LIST"; do
    if [ ! -f "$list" ]; then
        echo "❌ Missing $list"
        echo "   Run the script from the boring-phone folder, with the lists/ folder next to it."
        exit 1
    fi
done

# --- Find ADB ---
ADB=""
if command -v adb > /dev/null 2>&1; then
    ADB=adb
else
    for candidate in \
        "$HOME/platform-tools/adb" \
        "$HOME/platform-tools/adb.exe" \
        "$HOME/Library/Android/sdk/platform-tools/adb" \
        "$HOME/Android/Sdk/platform-tools/adb"; do
        if [ -x "$candidate" ]; then
            ADB="$candidate"
            break
        fi
    done
fi
if [ -z "$ADB" ]; then
    echo "❌ ADB not found. Install it or place platform-tools in your home directory."
    echo "   Download: https://developer.android.com/tools/releases/platform-tools"
    exit 1
fi

# stdin comes from /dev/null so adb can't eat the list file we're reading line by line.
adb_shell() {
    "$ADB" shell "$@" < /dev/null 2>&1 | tr -d '\r'
}

prop() {
    adb_shell getprop "$1"
}

# --- Essentials: never removed, checked before and after each stage ---
# Format: Name|package package ... (any one of them counts)
ESSENTIALS='WhatsApp|com.whatsapp com.whatsapp.w4b
Gmail|com.google.android.gm
Google Maps|com.google.android.apps.maps
Phone|com.google.android.dialer com.android.contacts com.android.dialer
Messages|com.google.android.apps.messaging com.android.mms
Camera|com.android.camera com.google.android.GoogleCamera
Play Store|com.android.vending'

# Removing these can break the phone. The script refuses even if you add them to a list.
PROTECTED=" com.android.systemui com.android.settings com.android.phone com.google.android.gms \
com.google.android.webview com.miui.home com.mi.android.globallauncher com.miui.securitycenter \
$(printf '%s\n' "$ESSENTIALS" | cut -d'|' -f2 | tr '\n' ' ') "

is_protected() {
    case "$PROTECTED" in
        *" $1 "*) return 0 ;;
    esac
    return 1
}

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="$HOME/boring-phone-logs"
LOG_FILE="$LOG_DIR/debloat_$TIMESTAMP.log"
RESTORE_FILE="$LOG_DIR/restore_$TIMESTAMP.sh"
SNAPSHOT_FILE="$LOG_DIR/packages_before_$TIMESTAMP.txt"

mkdir -p "$LOG_DIR"

log() {
    echo "$*" >> "$LOG_FILE"
}

# --- Connection check ---
echo ""
echo "  ┌──────────────────────────────────┐"
echo "  │         📱 Boring Phone          │"
echo "  │   Make your phone boring again   │"
echo "  └──────────────────────────────────┘"
echo ""
if $DRY_RUN; then
    echo "🔎 DRY RUN — nothing on the phone will be changed."
    echo ""
fi
echo "🔍 Checking phone connection..."
"$ADB" start-server > /dev/null 2>&1
DEVICES=$("$ADB" devices 2>/dev/null | tr -d '\r' | awk '$1 != "List" && $1 != "*" && NF >= 2 { print $1, $2 }')
if [ -n "$ANDROID_SERIAL" ]; then
    DEVICES=$(printf '%s\n' "$DEVICES" | awk -v s="$ANDROID_SERIAL" '$1 == s')
fi
DEVICE_COUNT=$(printf '%s' "$DEVICES" | grep -c .)

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "❌ Phone not detected."
    echo ""
    echo "   Checklist:"
    echo "   1. USB cable plugged in? (some cables only charge — try another)"
    echo "   2. 'File transfer' mode selected on phone?"
    echo "   3. USB debugging enabled? (Settings → Additional settings → Developer options)"
    echo "   4. Authorized this computer? (check for popup on phone)"
    exit 1
fi
if [ "$DEVICE_COUNT" -gt 1 ]; then
    echo "❌ More than one phone or emulator is connected:"
    printf '%s\n' "$DEVICES" | sed 's/^/      /'
    echo ""
    echo "   Pick one:  ANDROID_SERIAL=<serial> bash debloat.sh"
    exit 1
fi
SERIAL=${DEVICES%% *}
STATE=${DEVICES#* }
case "$STATE" in
    device) ;;
    unauthorized)
        echo "❌ Phone found, but this computer isn't authorized yet."
        echo "   Unlock the phone and tap 'Allow' on the USB debugging popup"
        echo "   (tick 'Always allow from this computer'), then run this again."
        exit 1 ;;
    *)
        echo "❌ Phone found, but its state is '$STATE'. Unplug it, plug it back in, and run this again."
        exit 1 ;;
esac
export ANDROID_SERIAL="$SERIAL"

MANUFACTURER=$(prop ro.product.manufacturer)
MODEL=$(prop ro.product.model)
ANDROID_VERSION=$(prop ro.build.version.release)
OS_VERSION=$(prop ro.build.version.incremental)   # HyperOS/MIUI build on Xiaomi, e.g. OS2.0.x.x
echo "✅ Connected: $MANUFACTURER $MODEL — Android $ANDROID_VERSION ($OS_VERSION)"
case "$MANUFACTURER" in
    [Xx]iaomi|[Rr]edmi|POCO|[Pp]oco) ;;
    *)
        echo "   ℹ️  Not a Xiaomi phone. Stage 1 still works; Stage 2 will mostly skip."
        echo "      See 'Adapting for Other Phones' in the README." ;;
esac
echo ""

# --- Snapshot ---
echo "📸 Saving snapshot of all installed packages..."
adb_shell pm list packages | sort > "$SNAPSHOT_FILE"
PACKAGE_COUNT=$(grep -c '^package:' "$SNAPSHOT_FILE")
if [ "$PACKAGE_COUNT" -eq 0 ]; then
    echo "❌ Couldn't read the package list from the phone:"
    sed 's/^/   /' "$SNAPSHOT_FILE"
    exit 1
fi
echo "   Saved $PACKAGE_COUNT packages to:"
echo "   $SNAPSHOT_FILE"
echo ""

ALREADY_DISABLED=$(adb_shell pm list packages -d)

is_installed() {
    grep -qxF "package:$1" "$SNAPSHOT_FILE"
}

# Disabled apps still show up as installed, so re-runs need this to skip them.
is_disabled() {
    printf '%s\n' "$ALREADY_DISABLED" | grep -qxF "package:$1"
}

# --- Initialize log ---
{
    echo "Boring Phone — Debloat log"
    echo "Timestamp: $TIMESTAMP"
    echo "Device: $MANUFACTURER $MODEL ($SERIAL), Android $ANDROID_VERSION, $OS_VERSION"
    echo "Packages before: $PACKAGE_COUNT"
    $DRY_RUN && echo "Mode: DRY RUN (nothing changed)"
    echo "---"
} > "$LOG_FILE"

# --- Initialize restore script ---
# Each removal appends a 'restore ...' line; the footer is added on exit, so the file
# works even if you stop after Stage 1.
finalize_restore() {
    cat >> "$RESTORE_FILE" << 'FOOTER'

echo ""
echo "Restored: $OK   Failed: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "Apps you installed yourself (not preinstalled) can't come back this way —"
    echo "reinstall those from the Play Store."
fi
FOOTER
}

if ! $DRY_RUN; then
    {
        echo "#!/usr/bin/env bash"
        echo "# Auto-generated by Boring Phone on $TIMESTAMP for $MANUFACTURER $MODEL ($SERIAL)."
        echo "# Reverses only what that run actually removed."
        echo "# Usage: bash $RESTORE_FILE"
    } > "$RESTORE_FILE"
    cat >> "$RESTORE_FILE" << 'HEADER'

if command -v adb > /dev/null 2>&1; then
    ADB=adb
elif [ -x "$HOME/platform-tools/adb" ]; then
    ADB="$HOME/platform-tools/adb"
else
    echo "❌ ADB not found."
    exit 1
fi

OK=0
FAIL=0
restore() {
    local out
    if [ "$1" = enable ]; then
        out=$("$ADB" shell pm enable "$2" < /dev/null 2>&1)
    else
        out=$("$ADB" shell cmd package install-existing "$2" < /dev/null 2>&1)
    fi
    case "$out" in
        *"installed for user"*|*"new state: enabled"*)
            echo "   ✅ $2"
            OK=$((OK + 1)) ;;
        *)
            echo "   ⚠️  $2: $out"
            FAIL=$((FAIL + 1)) ;;
    esac
}

echo "🔄 Restoring removed apps..."
HEADER
    chmod +x "$RESTORE_FILE"
    trap finalize_restore EXIT
fi

REMOVED_COUNT=0
DISABLED_COUNT=0
FAILED_COUNT=0
SKIPPED_COUNT=0

remove() {
    local pkg=$1 label=$2 out disable_out
    if ! is_installed "$pkg"; then
        log "SKIPPED: $pkg — $label (not on this phone)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        return
    fi
    if is_disabled "$pkg"; then
        log "SKIPPED: $pkg — $label (already disabled)"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
        return
    fi
    if is_protected "$pkg"; then
        echo "   🛑 $label ($pkg) — protected, not touching it"
        log "PROTECTED: $pkg — $label"
        return
    fi
    if $DRY_RUN; then
        echo "   🔎 $label  ($pkg)"
        log "WOULD REMOVE: $pkg — $label"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
        return
    fi

    out=$(adb_shell pm uninstall -k --user 0 "$pkg")
    case "$out" in
        *Success*)
            echo "   ✅ $label"
            log "REMOVED: $pkg — $label"
            echo "restore install-existing $pkg  # $label" >> "$RESTORE_FILE"
            REMOVED_COUNT=$((REMOVED_COUNT + 1))
            return ;;
        *"not installed for"*)
            log "SKIPPED: $pkg — $label (already removed)"
            SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
            return ;;
    esac

    # Some system apps refuse to uninstall (Mi Browser has, since MIUI 12). Disabling hides them just as well.
    disable_out=$(adb_shell pm disable-user --user 0 "$pkg")
    case "$disable_out" in
        *"new state: disabled-user"*)
            echo "   ✅ $label (disabled — Xiaomi blocks uninstalling it)"
            log "DISABLED: $pkg — $label (uninstall said: $(printf '%s' "$out" | tr '\n' ' '))"
            echo "restore enable $pkg  # $label" >> "$RESTORE_FILE"
            DISABLED_COUNT=$((DISABLED_COUNT + 1)) ;;
        *)
            echo "   ❌ $label ($pkg) — the phone refused. Details in the log."
            log "FAILED: $pkg — $label | uninstall: $(printf '%s' "$out" | tr '\n' ' ') | disable: $(printf '%s' "$disable_out" | tr '\n' ' ')"
            FAILED_COUNT=$((FAILED_COUNT + 1)) ;;
    esac
}

run_list() {
    local file=$1 pkg label skipped_before=$SKIPPED_COUNT
    while read -r pkg label <&3 || [ -n "$pkg" ]; do
        pkg=${pkg%$'\r'}
        label=${label%$'\r'}
        case "$pkg" in
            ''|'#'*) continue ;;
        esac
        remove "$pkg" "${label:-$pkg}"
    done 3< "$file"
    echo "   ⏭️  $((SKIPPED_COUNT - skipped_before)) other listed apps aren't on this phone (or are already gone)."
}

in_list() {
    awk -v p="$1" '$1 == p { found = 1 } END { exit !found }' "$2"
}

MISSING_BEFORE=""
check_essentials() {
    local current name pkgs pkg found missing=""
    current=$(adb_shell pm list packages)
    while IFS='|' read -r name pkgs; do
        found=false
        for pkg in $pkgs; do
            if printf '%s\n' "$current" | grep -qxF "package:$pkg"; then
                found=true
                break
            fi
        done
        if $found; then
            echo "   ✅ $name"
        else
            echo "   ⚠️  $name — not installed"
            missing="$missing|$name"
        fi
    done << EOF
$ESSENTIALS
EOF
    CHECK_MISSING="$missing"
}

sanity_check() {
    echo ""
    echo "   🩺 Sanity check..."
    check_essentials
    local lost="" name
    local IFS='|'
    for name in $CHECK_MISSING; do
        [ -z "$name" ] && continue
        case "$MISSING_BEFORE|" in
            *"|$name|"*) ;;
            *) lost="$lost $name," ;;
        esac
    done
    if [ -n "$lost" ]; then
        echo ""
        echo "   ⚠️  Missing now but present before:${lost%,}. Check your phone."
        echo "      Undo with: bash $RESTORE_FILE"
    else
        echo "   Everything you had before is still there."
    fi
}

# Anything that can still open a plain web link is a browser, whatever it calls itself.
browser_check() {
    local raw handlers pkg leftover=""
    echo ""
    echo "   🌐 Browser check..."
    raw=$(adb_shell cmd package query-activities --brief \
        -a android.intent.action.VIEW -c android.intent.category.BROWSABLE -d https://example.com)
    case "$raw" in
        *"No activities found"*|*"priority="*) ;;
        *)
            echo "   ⏭️  Skipped — this Android version can't answer the question."
            log "BROWSER CHECK: unsupported ($(printf '%s' "$raw" | head -n 1))"
            return ;;
    esac
    handlers=$(printf '%s\n' "$raw" \
        | grep -E '^[[:space:]]*[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+/[A-Za-z0-9_.$]+[[:space:]]*$' \
        | sed 's/^[[:space:]]*//; s|/.*||' | sort -u)
    for pkg in $handlers; do
        if $DRY_RUN && in_list "$pkg" "$STAGE1_LIST"; then
            continue
        fi
        leftover="$leftover $pkg"
    done
    if [ -z "$leftover" ]; then
        if $DRY_RUN; then
            echo "   ✅ Every app that opens web links today is on the list."
        else
            echo "   ✅ Nothing on this phone can open a web link anymore."
        fi
        log "BROWSER CHECK: clean"
    else
        echo "   ⚠️  These apps can still open web links:"
        for pkg in $leftover; do
            echo "      - $pkg"
        done
        echo "      Add them to lists/distractions.txt and run again to remove them."
        log "BROWSER CHECK: still handled by$leftover"
    fi
}

echo "🩺 Checking your essentials are installed..."
check_essentials
MISSING_BEFORE="$CHECK_MISSING"
if [ -n "$MISSING_BEFORE" ]; then
    echo ""
    echo "   ℹ️  Not installed yet:$(printf '%s' "$MISSING_BEFORE" | tr '|' ' ')"
    echo "      Install them from the Play Store (now or later — the Play Store stays)."
fi
echo ""

# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 STAGE 1: Removing distraction sources"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log ""
log "=== STAGE 1: Distraction sources ==="

run_list "$STAGE1_LIST"
browser_check
$DRY_RUN || sanity_check

if ! $DISTRACTIONS_ONLY; then
    if ! $DRY_RUN && ! $ASSUME_YES; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "⏸️  STAGE 1 COMPLETE"
        echo ""
        echo "   Pick up your phone and test:"
        echo "   • Open WhatsApp — send a message"
        echo "   • Open Gmail — check inbox loads"
        echo "   • Make a call, take a photo"
        echo ""
        echo "   All good? Press ENTER to continue to Stage 2."
        echo "   Something wrong? Press Ctrl+C to stop (the undo script is already saved)."
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        read -r
    fi

    # ============================================================
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🟡 STAGE 2: Removing Xiaomi bloatware"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log ""
    log "=== STAGE 2: Xiaomi bloatware ==="

    run_list "$STAGE2_LIST"
    $DRY_RUN || sanity_check
fi

# ============================================================
log ""
log "Removed: $REMOVED_COUNT  Disabled: $DISABLED_COUNT  Failed: $FAILED_COUNT  Not on phone: $SKIPPED_COUNT"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if $DRY_RUN; then
    echo "   🔎 Dry run finished. Nothing was changed."
    echo ""
    echo "   Would remove: $REMOVED_COUNT apps"
    echo "   Not on this phone: $SKIPPED_COUNT"
    echo ""
    echo "   Keep something? Put a # in front of its line in lists/."
    echo "   Ready? Run: bash debloat.sh"
    echo ""
    echo "   📸 Package snapshot: $SNAPSHOT_FILE"
else
    echo "   ✨ Your phone is now boring. That's the point."
    echo ""
    echo "   Removed:  $((REMOVED_COUNT + DISABLED_COUNT)) apps"
    if [ "$DISABLED_COUNT" -gt 0 ]; then
        echo "             ($DISABLED_COUNT of them disabled, because Xiaomi blocks uninstalling them)"
    fi
    if [ "$FAILED_COUNT" -gt 0 ]; then
        echo "   Failed:   $FAILED_COUNT (the phone refused — see FAILED lines in the log)"
    fi
    echo "   Skipped:  $SKIPPED_COUNT (not on this phone, or already gone)"
    echo ""
    echo "   Files saved in $LOG_DIR/:"
    echo "   📄 Log:       debloat_$TIMESTAMP.log"
    echo "   📸 Snapshot:  packages_before_$TIMESTAMP.txt"
    echo "   🔄 Undo:      restore_$TIMESTAMP.sh"
    echo ""
    echo "   To undo everything:"
    echo "   bash $RESTORE_FILE"
fi
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
