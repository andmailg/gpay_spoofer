#!/system/bin/sh
# shellcheck shell=sh
# GPay-Spoofer: action.sh (переключение профилей по кругу)

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="$MODDIR/Gpay-Spoofer.log"
PROPS_FILE="$MODDIR/original_props"
SUFFIX=","   # должен совпадать со значением в service.sh

echo "=== GPAY SPOOFER ==="

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
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ACTION] $1" >> "$LOGFILE" 2>/dev/null
}

get_setting() {
    grep "^$1=" "$SETTINGS" 2>/dev/null | head -n 1 | cut -d'=' -f2- | tr -d '\r '
}

# Значение из бэкапа по ключу (пусто, если нет)
_orig() {
    grep "^$1=" "$PROPS_FILE" 2>/dev/null | head -n 1 | cut -d'"' -f2 | tr -d '\r'
}

# restore <prop> <ключ бэкапа>: возвращает свойство в исходное значение, если оно есть в бэкапе
restore() {
    _v=$(_orig "$2")
    if [ -n "$_v" ]; then
        _set_prop "$1" "${_v}${SUFFIX}"
        RESTORED=$((RESTORED + 1))
    fi
}

if [ ! -f "$CARRIERS_DB" ]; then
    echo "ОШИБКА: Файл базы данных не найден!"
    exit 1
fi

# Текущее состояние
CURRENT=$(get_setting selected_carrier)
case "$CURRENT" in *[!0-9]*|"") CURRENT=0 ;; esac

# Следующий id из БД по возрастанию; после последнего возвращаемся к 0 (Авто)
NEW_CARRIER=$(awk -F: -v c="$CURRENT" '
/^[0-9]+:/ { gsub(/\r/, ""); ids[++n] = $1 }
END {
    for (i = 1; i <= n; i++) if (ids[i] + 0 > c + 0) { print ids[i]; exit }
    print 0
}' "$CARRIERS_DB")
case "$NEW_CARRIER" in *[!0-9]*|"") NEW_CARRIER=0 ;; esac

NEW_ISO=""
TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_ALPHA=""
TARGET_NAME=""
RESTORED=0

if [ "$NEW_CARRIER" -eq 0 ]; then
    # ---------- Авто: откат к родным значениям ----------
    TARGET_NAME="Спуфинг ОТКЛЮЧЕН (Режим Авто)"
    NEW_ISO=""

    restore gsm.sim.operator.alpha       ORIG_ALPHA
    restore gsm.operator.alpha           ORIG_OPERATOR_ALPHA
    restore gsm.sim.operator.numeric     ORIG_SIM_NUMERIC
    restore gsm.operator.numeric         ORIG_NUMERIC
    restore gsm.sim.operator.iso-country ORIG_ISO
    restore gsm.operator.iso-country     ORIG_OPERATOR_ISO

    TARGET_NUMERIC=$(_orig ORIG_NUMERIC)
    TARGET_ISO=$(_orig ORIG_ISO)
    TARGET_ALPHA=$(_orig ORIG_ALPHA)
else
    # ---------- Статика: применяем профиль ----------
    _match=$(awk -F: -v i="$NEW_CARRIER" '{ gsub(/\r/, "") } $1==i { print; exit }' "$CARRIERS_DB")
    TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2)
    TARGET_ISO=$(echo "$_match" | cut -d':' -f3)
    TARGET_ALPHA=$(echo "$_match" | cut -d':' -f4)

    if [ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ]; then
        echo "ОШИБКА: профиль [$NEW_CARRIER] не найден или повреждён в БД. Настройки не изменены."
        log_msg "Ошибка: профиль [$NEW_CARRIER] не найден или повреждён"
        exit 1
    fi

    TARGET_NAME="${TARGET_ALPHA} ($(echo "$TARGET_ISO" | tr '[:lower:]' '[:upper:]'))"
    NEW_ISO="$TARGET_ISO"

    _set_prop "gsm.sim.operator.alpha"       "${TARGET_ALPHA}${SUFFIX}"
    _set_prop "gsm.operator.alpha"           "${TARGET_ALPHA}${SUFFIX}"
    _set_prop "gsm.sim.operator.numeric"     "${TARGET_NUMERIC}${SUFFIX}"
    _set_prop "gsm.operator.numeric"         "${TARGET_NUMERIC}${SUFFIX}"
    _set_prop "gsm.sim.operator.iso-country" "${TARGET_ISO}${SUFFIX}"
    _set_prop "gsm.operator.iso-country"     "${TARGET_ISO}${SUFFIX}"
fi

# Запись настроек: остальные ключи сохраняются
{
    grep -v -e '^selected_carrier=' -e '^last_searched_iso=' "$SETTINGS" 2>/dev/null
    printf "selected_carrier=%s\nlast_searched_iso=%s\n" "$NEW_CARRIER" "$NEW_ISO"
} > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
chmod 0600 "$SETTINGS" 2>/dev/null

# ==========================================
# СПИСОК ПРОФИЛЕЙ
# ==========================================
echo "-----------------------------------"
echo "СПИСОК ПРОФИЛЕЙ:"

if [ "$NEW_CARRIER" -eq 0 ]; then
    echo "-> Режим Авто (Используются родные пропсы) <-- АКТИВЕН"
else
    echo "   Режим Авто (Используются родные пропсы)"
fi

awk -F: -v active="$NEW_CARRIER" '
{ gsub(/\r/, "") }
/^[0-9]+:/ {
    id = $1
    iso = toupper($3)
    alpha = $4
    if (id == active) {
        printf "-> [%s] %s (%s) <-- АКТИВЕН\n", id, alpha, iso
    } else {
        printf "   [%s] %s (%s)\n", id, alpha, iso
    }
}
' "$CARRIERS_DB"

echo "-----------------------------------"
echo "УСПЕШНО ПЕРЕКЛЮЧЕНО!"
echo "Профиль: [$NEW_CARRIER] $TARGET_NAME"
if [ "$NEW_CARRIER" -eq 0 ]; then
    if [ "$RESTORED" -eq 0 ]; then
        echo "Внимание: бэкап оригинальных значений пуст, откат не выполнен."
        echo "Свойства вернутся к родным после перезагрузки."
    else
        echo "Восстановлено свойств: $RESTORED"
    fi
else
    echo "Numeric: $TARGET_NUMERIC | ISO: $TARGET_ISO | Alpha: $TARGET_ALPHA"
fi
echo "-----------------------------------"
log_msg "Переключение профиля: [$NEW_CARRIER] $TARGET_NAME (восстановлено: $RESTORED)"

# Асинхронный перезапуск сервисов Google
(
    am force-stop com.android.vending
    am force-stop com.google.android.apps.walletnfcrel
) >/dev/null 2>&1 &

echo "Google сервисы перезапущены в фоне."
echo "=== РАБОТА ЗАВЕРШЕНА ==="
exit 0
