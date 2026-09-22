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

# Ожидание окончания загрузки системы
timeout=30
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
    timeout=$((timeout - 1))
    [ "$timeout" -le 0 ] && break
done

# Проверка региона текущей SIM-карты (защитный фильтр)
RAW_ISO=$(getprop ril.operator.iso-country 2>/dev/null | tr -d ' ' | tr '[:upper:]' '[:lower:]')
[ -z "$RAW_ISO" ] && RAW_ISO=$(getprop gsm.sim.official_iso-country 2>/dev/null | tr -d ' ' | tr '[:upper:]' '[:lower:]')

case "$RAW_ISO" in
    *ru* | *by* | "") ;;
    *)
        log_msg "Пропущено. Иностранная SIM: '$RAW_ISO'."
        exit 0
        ;;
esac

# Бэкап оригинальных системных пропсов оператора
CURRENT_SYSTEM_NUMERIC=$(getprop gsm.operator.numeric | cut -d',' -f1)
CURRENT_SYSTEM_ISO=$(getprop gsm.sim.operator.iso-country | cut -d',' -f1)

if [ -n "$CURRENT_SYSTEM_NUMERIC" ] && [ -n "$CURRENT_SYSTEM_ISO" ]; then
    LAST_SAVED_CARRIER=$(grep '^selected_carrier=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1)
    case "$LAST_SAVED_CARRIER" in *[!0-9]*|"") LAST_SAVED_CARRIER=0 ;; esac
    if [ "$LAST_SAVED_CARRIER" -eq 0 ] || [ ! -f "$PROPS_FILE" ]; then
        echo "ORIG_NUMERIC=\"$CURRENT_SYSTEM_NUMERIC\"" > "$PROPS_FILE"
        echo "ORIG_ISO=\"$CURRENT_SYSTEM_ISO\"" >> "$PROPS_FILE"
        chmod 0600 "$PROPS_FILE"
    fi
fi

# Получаем текущий выбранный профиль
SELECTED_CARRIER=$(grep '^selected_carrier=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1)
case "$SELECTED_CARRIER" in *[!0-9]*|"") SELECTED_CARRIER=0 ;; esac

TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_NAME=""

if [ "$SELECTED_CARRIER" -eq 0 ]; then
    # =========================================================================
    # ВЕТКА 1: SELECTED_CARRIER = 0 (РЕЖИМ АВТО)
    # =========================================================================
    LAST_SEARCHED_ISO=$(grep '^last_searched_iso=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1 | tr -d '\r ' | tr '[:upper:]' '[:lower:]')
    
    if [ -n "$LAST_SEARCHED_ISO" ]; then
        _match=$(grep ":${LAST_SEARCHED_ISO}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
        if [ -n "$_match" ]; then
            TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2)
            TARGET_ISO=$(echo "$_match" | cut -d':' -f3)
            TARGET_NAME=$(echo "$_match" | cut -d':' -f4)
            log_msg "🤖 Режим Авто: Найден профиль для региона [$LAST_SEARCHED_ISO] -> $TARGET_NAME"
        fi
    fi

    # Если last_searched_iso пуст или регион отсутствует в базе данных
    if [ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ]; then
        log_msg "ℹ️ Режим Авто: Регион пуст или не найден в БД. Спуфинг не применяется."
        exit 0
    fi
else
    # =========================================================================
    # ВЕТКА 2: SELECTED_CARRIER != 0 (СТАТИЧЕСКИЙ ВЫБОР)
    # =========================================================================
    _match=$(grep "^${SELECTED_CARRIER}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
    if [ -n "$_match" ]; then
        TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2)
        TARGET_ISO=$(echo "$_match" | cut -d':' -f3)
        TARGET_NAME=$(echo "$_match" | cut -d':' -f4)
    fi

    if [ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ]; then
        log_msg "❌ Ошибка: Статический профиль [$SELECTED_CARRIER] не найден в базе данных."
        exit 1
    fi
fi

# Применение пропсов спуфинга через спаренные строки (маскировка Dual SIM)
_set_prop "gsm.sim.operator.numeric" "${TARGET_NUMERIC},${TARGET_NUMERIC}"
_set_prop "gsm.sim.operator.iso-country" "${TARGET_ISO},${TARGET_ISO}"
_set_prop "gsm.operator.numeric" "${TARGET_NUMERIC},${TARGET_NUMERIC}"
_set_prop "gsm.operator.iso-country" "${TARGET_ISO},${TARGET_ISO}"

if [ "$SELECTED_CARRIER" -eq 0 ] ; then
    log_msg "✅ Спуфинг успешно запущен в режиме Авто: [$LAST_SEARCHED_ISO] $TARGET_NAME"
else
    log_msg "✅ Спуфинг успешно запущен по профилю [$SELECTED_CARRIER]: $TARGET_NAME"
fi
