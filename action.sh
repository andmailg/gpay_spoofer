#!/system/bin/sh
MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="$MODDIR/Gpay-Spoofer.log"
PROPS_FILE="$MODDIR/original_props"

_set_prop() {
    if command -v resetprop >/dev/null 2>&1; then
        resetprop "$1" "$2"
    elif [ -x /data/adb/ap/bin/kpcli ]; then
        /data/adb/ap/bin/kpcli property set "$1" "$2"
    elif [ -x /data/adb/ksu/bin/kpcli ]; then
        /data/adb/ksu/bin/kpcli property set "$1" "$2"
    elif command -v kpcli >/dev/null 2>&1; then
        kpcli property set "$1" "$2"
    else
        setprop "$1" "$2"
    fi
}

_del_prop() {
    if command -v resetprop >/dev/null 2>&1; then
        resetprop --delete "$1" 2>/dev/null
    elif [ -x /data/adb/ap/bin/kpcli ]; then
        /data/adb/ap/bin/kpcli property set "$1" "" 2>/dev/null
    elif [ -x /data/adb/ksu/bin/kpcli ]; then
        /data/adb/ksu/bin/kpcli property set "$1" "" 2>/dev/null
    elif command -v kpcli >/dev/null 2>&1; then
        kpcli property set "$1" "" 2>/dev/null
    fi
}

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ACTION] $1" >> "$LOGFILE" 2>/dev/null
}

TOTAL_CARRIERS=$(grep -c "^[0-9]" "$CARRIERS_DB" 2>/dev/null || echo "0")
case "$TOTAL_CARRIERS" in ''|*[!0-9]*) TOTAL_CARRIERS=0 ;; esac
TOTAL_STATES=$((TOTAL_CARRIERS + 1))
CURRENT=$(grep '^selected_carrier=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1)
case "$CURRENT" in *[!0-9]*|"") CURRENT=0 ;; esac
NEW_CARRIER=$(( (CURRENT + 1) % TOTAL_STATES ))

echo "selected_carrier=$NEW_CARRIER" > "$SETTINGS"
chmod 0600 "$SETTINGS"

if [ -f "$PROPS_FILE" ]; then
    ORIG_NUMERIC=$(grep '^ORIG_NUMERIC=' "$PROPS_FILE" | cut -d'"' -f2)
    ORIG_ISO=$(grep '^ORIG_ISO=' "$PROPS_FILE" | cut -d'"' -f2)
    ORIG_CDMA=$(grep '^ORIG_CDMA=' "$PROPS_FILE" | cut -d'"' -f2)
else
    ORIG_NUMERIC="Неизвестно"
    ORIG_ISO="Неизвестно"
    ORIG_CDMA=""
fi

if [ "$NEW_CARRIER" -eq 0 ]; then
    TARGET_NAME="Спуфинг ОТКЛЮЧЕН"
    TARGET_NUMERIC="$ORIG_NUMERIC"
    TARGET_ISO="$ORIG_ISO"
else
    _match=$(grep "^${NEW_CARRIER}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
    if [ -n "$_match" ]; then
        TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2)
        TARGET_ISO=$(echo "$_match" | cut -d':' -f3)
        TARGET_NAME=$(echo "$_match" | cut -d':' -f4)
    fi
fi

if [ -n "$TARGET_NUMERIC" ] && [ -n "$TARGET_ISO" ] && [ "$TARGET_NUMERIC" != "Неизвестно" ]; then
    for suffix in "" ".1" ".2"; do
        _set_prop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
        _set_prop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
        _set_prop "gsm.operator.numeric$suffix" "$TARGET_NUMERIC"
        _set_prop "gsm.operator.iso-country$suffix" "$TARGET_ISO"
    done
    if [ "$NEW_CARRIER" -eq 0 ]; then
        if [ -n "$ORIG_CDMA" ]; then
            _set_prop "ro.cdma.home.operator.numeric" "$ORIG_CDMA"
        else
            _del_prop "ro.cdma.home.operator.numeric"
        fi
    else
        _set_prop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"
    fi
fi

am force-stop com.android.vending >/dev/null 2>&1
am force-stop com.google.android.apps.walletnfcrel >/dev/null 2>&1
pm trim-caches 999G >/dev/null 2>&1

echo "ПРИМЕНЁН ПРОФИЛЬ: [$NEW_CARRIER] $TARGET_NAME"
log_msg "Переключение профиля: [$NEW_CARRIER] $TARGET_NAME"
