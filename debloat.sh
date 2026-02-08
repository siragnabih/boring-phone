#!/bin/bash
# Boring Phone — Debloat Script (Mac/Linux)
# https://github.com/YOUR_USERNAME/boring-phone
#
# Usage: bash debloat.sh
# Tested on: Redmi Note 15 (HyperOS 2 / Android 15)
# Works on: Any Xiaomi / Redmi / POCO phone with MIUI or HyperOS

# --- Config ---
# Detect OS and set ADB path
if [[ "$OSTYPE" == "darwin"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    if command -v adb &> /dev/null; then
        ADB=adb
    elif [ -f ~/platform-tools/adb ]; then
        ADB=~/platform-tools/adb
    else
        echo "❌ ADB not found. Install it or place platform-tools in your home directory."
        echo "   Download: https://developer.android.com/tools/releases/platform-tools"
        exit 1
    fi
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR=~/boring-phone-logs
LOG_FILE="$LOG_DIR/debloat_$TIMESTAMP.log"
RESTORE_FILE="$LOG_DIR/restore_$TIMESTAMP.sh"
SNAPSHOT_FILE="$LOG_DIR/packages_before_$TIMESTAMP.txt"

mkdir -p "$LOG_DIR"

# --- Connection check ---
echo ""
echo "  ┌──────────────────────────────────┐"
echo "  │         📱 Boring Phone          │"
echo "  │   Make your phone boring again   │"
echo "  └──────────────────────────────────┘"
echo ""
echo "🔍 Checking phone connection..."
if ! $ADB devices 2>/dev/null | grep -q "device$"; then
    echo "❌ Phone not detected."
    echo ""
    echo "   Checklist:"
    echo "   1. USB cable plugged in?"
    echo "   2. 'File transfer' mode selected on phone?"
    echo "   3. USB debugging enabled? (Settings → Developer options)"
    echo "   4. Authorized this computer? (check for popup on phone)"
    exit 1
fi
echo "✅ Phone connected."
echo ""

# --- Snapshot ---
echo "📸 Saving snapshot of all installed packages..."
$ADB shell pm list packages | sort > "$SNAPSHOT_FILE"
PACKAGE_COUNT=$(wc -l < "$SNAPSHOT_FILE" | tr -d ' ')
echo "   Saved $PACKAGE_COUNT packages to:"
echo "   $SNAPSHOT_FILE"
echo ""

# --- Initialize restore script ---
cat > "$RESTORE_FILE" << 'HEADER'
#!/bin/bash
# Auto-generated restore script — reverses only what was actually removed
# Usage: bash restore_TIMESTAMP.sh

if command -v adb &> /dev/null; then
    ADB=adb
elif [ -f ~/platform-tools/adb ]; then
    ADB=~/platform-tools/adb
else
    echo "❌ ADB not found."
    exit 1
fi

echo "🔄 Restoring removed apps..."
HEADER
chmod +x "$RESTORE_FILE"

# --- Initialize log ---
echo "Boring Phone — Debloat log" > "$LOG_FILE"
echo "Timestamp: $TIMESTAMP" >> "$LOG_FILE"
echo "Packages before: $PACKAGE_COUNT" >> "$LOG_FILE"
echo "---" >> "$LOG_FILE"

REMOVED_COUNT=0
SKIPPED_COUNT=0

remove() {
    local package=$1
    local label=$2
    result=$($ADB shell pm uninstall -k --user 0 "$package" 2>&1)
    if echo "$result" | grep -q "Success"; then
        echo "   ✅ $label"
        echo "REMOVED: $package — $label" >> "$LOG_FILE"
        echo "\$ADB shell cmd package install-existing $package  # $label" >> "$RESTORE_FILE"
        REMOVED_COUNT=$((REMOVED_COUNT + 1))
    else
        echo "   ⏭️  $label (not on this phone)"
        echo "SKIPPED: $package — $label" >> "$LOG_FILE"
        SKIPPED_COUNT=$((SKIPPED_COUNT + 1))
    fi
}

sanity_check() {
    echo ""
    echo "   🩺 Sanity check..."
    local failed=false
    
    declare -A essentials=(
        ["com.whatsapp"]="WhatsApp"
        ["com.google.android.gm"]="Gmail"
        ["com.android.dialer"]="Phone"
    )
    
    local installed_packages
    installed_packages=$($ADB shell pm list packages)
    
    for pkg in "${!essentials[@]}"; do
        if echo "$installed_packages" | grep -q "$pkg"; then
            echo "   ✅ ${essentials[$pkg]}"
        else
            echo "   ⚠️  ${essentials[$pkg]} ($pkg) — NOT FOUND"
            failed=true
        fi
    done
    
    # Camera package varies by device
    if echo "$installed_packages" | grep -qE "camera|Camera"; then
        echo "   ✅ Camera"
    else
        echo "   ⚠️  Camera — NOT FOUND"
        failed=true
    fi
    
    if [ "$failed" = true ]; then
        echo ""
        echo "   ⚠️  Something essential may be missing. Check your phone."
    else
        echo "   All essentials present."
    fi
}

# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 STAGE 1: Removing distraction sources"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "" >> "$LOG_FILE"
echo "=== STAGE 1: Distraction sources ===" >> "$LOG_FILE"

remove com.mi.globalbrowser            "Mi Browser"
remove com.android.chrome              "Chrome"
remove com.google.android.youtube      "YouTube"
remove com.google.android.googlequicksearchbox "Google Search / Discover"
remove com.google.android.apps.magazines       "Google News"
remove com.facebook.katana             "Facebook"
remove com.facebook.system             "Facebook System"
remove com.facebook.appmanager         "Facebook App Manager"
remove com.facebook.services           "Facebook Services"
remove com.zhiliaoapp.musically        "TikTok"
remove com.netflix.mediaclient         "Netflix"
remove com.spotify.music               "Spotify"
remove com.google.android.apps.tachyon "Google Duo / Meet"
remove com.google.android.videos       "Google TV"

sanity_check

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "⏸️  STAGE 1 COMPLETE"
echo ""
echo "   Pick up your phone and test:"
echo "   • Open WhatsApp — send a message"
echo "   • Open Gmail — check inbox loads"
echo "   • Try to find a browser — you shouldn't"
echo ""
echo "   All good? Press ENTER to continue to Stage 2."
echo "   Something wrong? Press Ctrl+C to stop."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -r

# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🟡 STAGE 2: Removing Xiaomi bloatware"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "" >> "$LOG_FILE"
echo "=== STAGE 2: Xiaomi bloatware ===" >> "$LOG_FILE"

# Ads & analytics
remove com.miui.msa.global             "Xiaomi Ad Engine (MSA)"
remove com.miui.analytics              "Xiaomi Analytics"
remove com.miui.systemAdSolution       "System Ad Solution"
remove com.xiaomi.joyose               "Joyose (Telemetry)"

# App stores & recommendations
remove com.xiaomi.mipicks              "GetApps (Xiaomi App Store)"
remove com.miui.contentcatcher         "Content Recommendations"
remove com.miui.personalassistant      "Personal Assistant"
remove com.mi.globalminusscreen        "App Vault"

# Media
remove com.miui.videoplayer            "Mi Video"
remove com.miui.player                 "Mi Music"
remove com.miui.android.fashiongallery "Wallpaper Carousel"

# AI & Assistant
remove com.xiaomi.aicr                 "Xiaomi AI Engine"
remove com.miui.voiceassist            "Mi Voice Assistant"

# Games
remove com.xiaomi.gamecenter.sdk.service "Game Center SDK"
remove com.xiaomi.gamecenter            "Game Center"

# Misc
remove com.miui.yellowpage             "Yellow Pages"
remove com.xiaomi.midrop               "ShareMe / Mi Drop"
remove com.miui.nextpay                "Mi Pay"
remove com.miui.bugreport              "Bug Report Tool"
remove com.miui.hybrid                 "Hybrid Apps Engine"
remove cn.wps.xiaomi.abroad.lite       "WPS Office Lite"

sanity_check

# --- Finalize restore script ---
echo "" >> "$RESTORE_FILE"
echo 'echo "✅ Restore complete. Removed apps should be back."' >> "$RESTORE_FILE"

# ============================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "   ✨ Your phone is now boring. That's the point."
echo ""
echo "   Removed: $REMOVED_COUNT apps"
echo "   Skipped: $SKIPPED_COUNT (not on this phone)"
echo ""
echo "   Files saved in ~/boring-phone-logs/:"
echo "   📄 Log:      debloat_$TIMESTAMP.log"
echo "   📸 Snapshot:  packages_before_$TIMESTAMP.txt"
echo "   🔄 Undo:     restore_$TIMESTAMP.sh"
echo ""
echo "   To undo everything:"
echo "   bash ~/boring-phone-logs/restore_$TIMESTAMP.sh"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
