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
    sleep 0.1 
}

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SERVICE] $1" >> "$LOGFILE" 2>/dev/null
}

until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
sleep 10

RAW_ISO=$(getprop ril.operator.iso-country 2>/dev/null | tr -d ' ' | tr '[:upper:]' '[:lower:]')
[ -z "$RAW_ISO" ] && RAW_ISO=$(getprop gsm.sim.official_iso-country 2>/dev/null | tr -d ' ' | tr '[:upper:]' '[:lower:]')

case "$RAW_ISO" in
    *ru* | *by* | "") ;;
    *) log_msg "Пропущено. Иностранная SIM: '$RAW_ISO'."; exit 0 ;;
esac

# Бэкап оригинальных системных пропсов оператора
CURRENT_SYSTEM_NUMERIC=$(getprop gsm.operator.numeric | cut -d',' -f1)
CURRENT_SYSTEM_ISO=$(getprop gsm.sim.operator.iso-country | cut -d',' -f1)
CURRENT_SYSTEM_ALPHA=$(getprop gsm.operator.alpha | cut -d',' -f1)

if [ -n "$CURRENT_SYSTEM_NUMERIC" ] && [ -n "$CURRENT_SYSTEM_ISO" ]; then
    LAST_SAVED_CARRIER=$(grep '^selected_carrier=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1)
    case "$LAST_SAVED_CARRIER" in *[!0-9]*|"") LAST_SAVED_CARRIER=0 ;; esac
    if [ "$LAST_SAVED_CARRIER" -eq 0 ] || [ ! -f "$PROPS_FILE" ]; then
        echo "ORIG_NUMERIC=\"$CURRENT_SYSTEM_NUMERIC\"" > "$PROPS_FILE"
        echo "ORIG_ISO=\"$CURRENT_SYSTEM_ISO\"" >> "$PROPS_FILE"
        echo "ORIG_ALPHA=\"$CURRENT_SYSTEM_ALPHA\"" >> "$PROPS_FILE"
        chmod 0600 "$PROPS_FILE"
    fi
fi

# Получаем текущий выбранный профиль
SELECTED_CARRIER=$(grep '^selected_carrier=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1)
case "$SELECTED_CARRIER" in *[!0-9]*|"") SELECTED_CARRIER=0 ;; esac

TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_ALPHA=""
TARGET_NAME=""

if [ "$SELECTED_CARRIER" -eq 0 ]; then
    # =========================================================================
    # ВЕТКА 1: РЕЖИМ АВТО
    # =========================================================================
    LAST_SEARCHED_ISO=$(grep '^last_searched_iso=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1 | tr -d '\r ' | tr '[:upper:]' '[:lower:]')
    if [ -n "$LAST_SEARCHED_ISO" ]; then
        _match=$(grep ":${LAST_SEARCHED_ISO}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
        if [ -n "$_match" ]; then
            TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2)
            TARGET_ISO=$(echo "$_match" | cut -d':' -f3)
            TARGET_ALPHA=$(echo "$_match" | cut -d':' -f4)
            TARGET_NAME="${TARGET_ALPHA} ($(echo "$TARGET_ISO" | tr '[:lower:]' '[:upper:]'))"
            log_msg "🤖 Режим Авто: Нацелен регион [$LAST_SEARCHED_ISO] -> $TARGET_NAME"
        fi
    fi
    if [ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ]; then
        log_msg "ℹ️ Режим Авто: Список пуст или регион отсутствует в БД. Спуфинг спит."
        exit 0
    fi
else
    # =========================================================================
    # ВЕТКА 2: СТАТИКА
    # =========================================================================
    _match=$(grep "^${SELECTED_CARRIER}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
    if [ -n "$_match" ]; then
        TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2)
        TARGET_ISO=$(echo "$_match" | cut -d':' -f3)
        TARGET_ALPHA=$(echo "$_match" | cut -d':' -f4)
        TARGET_NAME="${TARGET_ALPHA} ($(echo "$TARGET_ISO" | tr '[:lower:]' '[:upper:]'))"
    fi
    if [ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ]; then
        log_msg "❌ Ошибка: Статический профиль [$SELECTED_CARRIER] поврежден в БД."
        exit 1
    fi
fi

log_msg "DEBUG: NUMERIC='$TARGET_NUMERIC', ISO='$TARGET_ISO', ALPHA='$TARGET_ALPHA'"

_set_prop "gsm.sim.operator.alpha" "${TARGET_ALPHA},"
_set_prop "gsm.operator.alpha" "${TARGET_ALPHA},"
_set_prop "gsm.sim.operator.numeric" "${TARGET_NUMERIC},"
_set_prop "gsm.operator.numeric" "${TARGET_NUMERIC},"
_set_prop "gsm.sim.operator.iso-country" "${TARGET_ISO},"
_set_prop "gsm.operator.iso-country" "${TARGET_ISO},"

if [ "$SELECTED_CARRIER" -eq 0 ]; then
    log_msg "🤖 [Авто-режим] Успешно применен профиль: $TARGET_NAME"
else
    log_msg "🚀 [Статика] Успешно применен профиль [$SELECTED_CARRIER]: $TARGET_NAME"
fi

