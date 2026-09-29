#!/system/bin/sh
# shellcheck shell=sh
# GPay-Spoofer: uninstall.sh

case "$0" in
    */*) MODDIR="${0%/*}" ;;
    *)   MODDIR="$(pwd)" ;;
esac
PROPS_FILE="$MODDIR/original_props"
LOGFILE="$MODDIR/Gpay-Spoofer.log"
SUFFIX=","   # должен совпадать со значением в service.sh и action.sh

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
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UNINSTALL] $1" >> "$LOGFILE" 2>/dev/null
}

_orig() {
    grep "^$1=" "$PROPS_FILE" 2>/dev/null | head -n 1 | cut -d'"' -f2 | tr -d '\r'
}

# restore <prop> <ключ бэкапа>: возвращает только то, что модуль реально менял.
# Если значения в бэкапе нет, свойство не трогаем (ничего не удаляем).
restore() {
    _v=$(_orig "$2")
    if [ -n "$_v" ]; then
        _set_prop "$1" "${_v}${SUFFIX}"
        RESTORED=$((RESTORED + 1))
    fi
}

RESTORED=0

# Останавливаем фоновый цикл service.sh, иначе он вернёт подмену
pkill -f "$MODDIR/service.sh" 2>/dev/null

if [ -f "$PROPS_FILE" ]; then
    restore gsm.sim.operator.alpha       ORIG_ALPHA
    restore gsm.operator.alpha           ORIG_OPERATOR_ALPHA
    restore gsm.sim.operator.numeric     ORIG_SIM_NUMERIC
    restore gsm.operator.numeric         ORIG_NUMERIC
    restore gsm.sim.operator.iso-country ORIG_ISO
    restore gsm.operator.iso-country     ORIG_OPERATOR_ISO
    log_msg "Удаление модуля: восстановлено свойств: $RESTORED"
else
    log_msg "Удаление модуля: бэкап не найден, свойства вернутся после перезагрузки"
fi

rm -f "$MODDIR/settings" "$MODDIR/carriers.db" "$MODDIR/original_props" 2>/dev/null
