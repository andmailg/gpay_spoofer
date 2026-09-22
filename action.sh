#!/system/bin/sh

# 1. Жестко определяем директорию модуля
MODDIR="/data/adb/modules/gpay-spoofer"
[ ! -d "$MODDIR" ] && MODDIR="${0%/*}"

SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="$MODDIR/Gpay-Spoofer.log"
PROPS_FILE="$MODDIR/original_props"

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

if [ ! -f "$CARRIERS_DB" ]; then
    echo "ОШИБКА: Файл базы данных не найден!"
    exit 1
fi

TOTAL_CARRIERS=$(grep -c "^[0-9]" "$CARRIERS_DB" 2>/dev/null | tr -d '\r')
case "$TOTAL_CARRIERS" in ''|*[!0-9]*) TOTAL_CARRIERS=0 ;; esac
TOTAL_STATES=$((TOTAL_CARRIERS + 1))

# Получаем текущее состояние
CURRENT=$(grep '^selected_carrier=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1 | tr -d '\r ')
case "$CURRENT" in *[!0-9]*|"") CURRENT=0 ;; esac

# Рассчитываем индекс следующего профиля по кругу
NEW_CARRIER=$(( (CURRENT + 1) % TOTAL_STATES ))

# Загружаем оригинальные пропсы для отката при переключении на режим Авто
if [ -f "$PROPS_FILE" ]; then
    ORIG_NUMERIC=$(grep '^ORIG_NUMERIC=' "$PROPS_FILE" | cut -d'"' -f2 | tr -d '\r')
    ORIG_ISO=$(grep '^ORIG_ISO=' "$PROPS_FILE" | cut -d'"' -f2 | tr -d '\r')
    ORIG_CDMA=$(grep '^ORIG_CDMA=' "$PROPS_FILE" | cut -d'"' -f2 | tr -d '\r')
else
    ORIG_NUMERIC="Неизвестно"
    ORIG_ISO="Неизвестно"
    ORIG_CDMA=""
fi

NEW_ISO=""
TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_NAME=""

# =========================================================================
# ПРИМЕНЕНИЕ ОБНОВЛЕННОЙ АРХИТЕКТУРЫ СИНХРОНИЗАЦИИ ПЕРЕМЕННЫХ
# =========================================================================
if [ "$NEW_CARRIER" -eq 0 ]; then
    TARGET_NAME="Спуфинг ОТКЛЮЧЕН (Режим Авто)"
    TARGET_NUMERIC="$ORIG_NUMERIC"
    TARGET_ISO="$ORIG_ISO"
    NEW_ISO="" # При выборе Авто переменная региона создается пустой
else
    _match=$(grep "^${NEW_CARRIER}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
    if [ -n "$_match" ]; then
        TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2 | tr -d '\r')
        TARGET_ISO=$(echo "$_match" | cut -d':' -f3 | tr -d '\r')
        TARGET_NAME=$(echo "$_match" | cut -d':' -f4 | tr -d '\r')
        NEW_ISO="$TARGET_ISO" # Автоматически принимает соответствующее значение профиля
    fi
fi

# Чистая перезапись структуры файла без накопления строкового мусора
printf "selected_carrier=%s\nlast_searched_iso=%s\n" "$NEW_CARRIER" "$NEW_ISO" > "$SETTINGS"
chmod 0600 "$SETTINGS"

# Мгновенное применение пропсов в текущей Android-сессии
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

# =========================================================================
# ВЫВОД ИНТЕРАКТИВНОГО СПИСКА (МОЛНИЕНОСНЫЙ ЧЕРЕЗ AWK)
# =========================================================================
echo "-----------------------------------"
echo "СПИСОК ПРОФИЛЕЙ:"

if [ "$NEW_CARRIER" -eq 0 ]; then
    echo "-> [0] Режим Авто (Используются родные пропсы) <-- АКТИВЕН"
else
    echo "   [0] Режим Авто (Используются родные пропсы)"
fi

# Обработка базы за один проход в памяти
awk -v active="$NEW_CARRIER" '
BEGIN { FS=":"; RS="\r?\n" }
/^[0-9]+/ {
    id = $1
    iso = $3
    name = $4
    if (id == active) {
        printf "-> [%s] %s (%s) <-- АКТИВЕН\n", id, name, iso
    } else {
        printf "   [%s] %s (%s)\n", id, name, iso
    }
}
' "$CARRIERS_DB"

# Вывод информации для пользователя в лог терминала Magisk
echo "-----------------------------------"
echo "УСПЕШНО ПЕРЕКЛЮЧЕНО!"
echo "Профиль: [$NEW_CARRIER] $TARGET_NAME"
echo "Numeric: $TARGET_NUMERIC | ISO: $TARGET_ISO"
echo "-----------------------------------"
log_msg "Переключение профиля: [$NEW_CARRIER] $TARGET_NAME"

# Асинхронный сброс кэша сервисов Google
(
    am force-stop com.android.vending
    am force-stop com.google.android.apps.walletnfcrel
    pm trim-caches 999G
) >/dev/null 2>&1 &

echo "Google сервисы перезапущены в фоне."
echo "=== РАБОТА ЗАВЕРШЕНА ==="
exit 0
