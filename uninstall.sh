#!/system/bin/sh
MODDIR="${0%/*}"
PROPS_FILE="$MODDIR/original_props"
LOGFILE="$MODDIR/Gpay-Spoofer.log"

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
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UNINSTALL] $1" >> "$LOGFILE" 2>/dev/null
}

restore_prop() {
    _prop="$1"
    _val="$2"
    if [ -n "$_val" ] && [ "$_val" != "Неизвестно" ]; then
        _set_prop "$_prop" "$_val"
    else
        _del_prop "$_prop"
    fi
}

if [ -f "$PROPS_FILE" ]; then
    ORIG_NUMERIC=$(grep '^ORIG_NUMERIC=' "$PROPS_FILE" | cut -d'"' -f2)
    ORIG_ISO=$(grep '^ORIG_ISO=' "$PROPS_FILE" | cut -d'"' -f2)
    ORIG_ALPHA=$(grep '^ORIG_ALPHA=' "$PROPS_FILE" | cut -d'"' -f2)
    ORIG_CDMA=$(grep '^ORIG_CDMA=' "$PROPS_FILE" | cut -d'"' -f2)
else
    ORIG_NUMERIC=$(getprop gsm.operator.numeric)
    ORIG_ISO=$(getprop gsm.operator.iso-country)
    ORIG_ALPHA=$(getprop gsm.operator.alpha)
    ORIG_CDMA=$(getprop ro.cdma.home.operator.numeric)
fi

restore_prop "gsm.operator.numeric" "$ORIG_NUMERIC"
restore_prop "gsm.operator.iso-country" "$ORIG_ISO"
restore_prop "gsm.operator.alpha" "$ORIG_ALPHA"
restore_prop "ro.cdma.home.operator.numeric" "$ORIG_CDMA"

for suffix in "" ".1" ".2"; do
    restore_prop "gsm.sim.operator.numeric$suffix" "$ORIG_NUMERIC"
    restore_prop "gsm.sim.operator.iso-country$suffix" "$ORIG_ISO"
    restore_prop "gsm.sim.operator.alpha$suffix" "$ORIG_ALPHA"
    restore_prop "gsm.operator.numeric$suffix" "$ORIG_NUMERIC"
    restore_prop "gsm.operator.iso-country$suffix" "$ORIG_ISO"
    restore_prop "gsm.operator.alpha$suffix" "$ORIG_ALPHA"
done

rm -f "$MODDIR/settings" "$MODDIR/carriers.db" "$MODDIR/original_props" 2>/dev/null
