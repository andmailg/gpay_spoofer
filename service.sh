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

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SERVICE] $1" >> "$LOGFILE" 2>/dev/null
}

timeout=30
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
    timeout=$((timeout - 1))
    [ "$timeout" -le 0 ] && break
done

RAW_ISO=$(getprop ril.operator.iso-country 2>/dev/null | tr -d ' ' | tr '[:upper:]' '[:lower:]')
[ -z "$RAW_ISO" ] && RAW_ISO=$(getprop gsm.sim.official_iso-country 2>/dev/null | tr -d ' ' | tr '[:upper:]' '[:lower:]')

case "$RAW_ISO" in
    *ru* | *by* | "") ;;
    *)
        log_msg "Пропущено. Иностранная SIM: '$RAW_ISO'."
        exit 0
        ;;
esac

CURRENT_SYSTEM_NUMERIC=$(getprop gsm.operator.numeric | cut -d',' -f1)
CURRENT_SYSTEM_ISO=$(getprop gsm.sim.operator.iso-country | cut -d',' -f1)
CURRENT_SYSTEM_CDMA=$(getprop ro.cdma.home.operator.numeric)

if [ -n "$CURRENT_SYSTEM_NUMERIC" ] && [ -n "$CURRENT_SYSTEM_ISO" ]; then
    LAST_SAVED_CARRIER=$(grep '^selected_carrier=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1)
    case "$LAST_SAVED_CARRIER" in *[!0-9]*|"") LAST_SAVED_CARRIER=0 ;; esac
    if [ "$LAST_SAVED_CARRIER" -eq 0 ] || [ ! -f "$PROPS_FILE" ]; then
        echo "ORIG_NUMERIC=\"$CURRENT_SYSTEM_NUMERIC\"" > "$PROPS_FILE"
        echo "ORIG_ISO=\"$CURRENT_SYSTEM_ISO\"" >> "$PROPS_FILE"
        echo "ORIG_CDMA=\"$CURRENT_SYSTEM_CDMA\"" >> "$PROPS_FILE"
        chmod 0600 "$PROPS_FILE"
    fi
fi

SELECTED_CARRIER=$(grep '^selected_carrier=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1)
case "$SELECTED_CARRIER" in *[!0-9]*|"") SELECTED_CARRIER=0 ;; esac
if [ "$SELECTED_CARRIER" -eq 0 ]; then
    exit 0
fi

TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_NAME=""
_match=$(grep "^${SELECTED_CARRIER}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
if [ -n "$_match" ]; then
    TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2)
    TARGET_ISO=$(echo "$_match" | cut -d':' -f3)
    TARGET_NAME=$(echo "$_match" | cut -d':' -f4)
fi

if [ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ]; then
    log_msg "❌ Ошибка: Профиль [$SELECTED_CARRIER] не найден."
    exit 1
fi

for suffix in "" ".1" ".2"; do
    _set_prop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
    _set_prop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
    _set_prop "gsm.operator.numeric$suffix" "$TARGET_NUMERIC"
    _set_prop "gsm.operator.iso-country$suffix" "$TARGET_ISO"
done
_set_prop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"

log_msg "✅ Спуфинг активирован: [$SELECTED_CARRIER] $TARGET_NAME"
