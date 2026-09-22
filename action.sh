#!/system/bin/sh
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

# Загружаем оригинальные пропсы для отката
if [ -f "$PROPS_FILE" ]; then
    ORIG_NUMERIC=$(grep '^ORIG_NUMERIC=' "$PROPS_FILE" | cut -d'"' -f2 | tr -d '\r')
    ORIG_ISO=$(grep '^ORIG_ISO=' "$PROPS_FILE" | cut -d'"' -f2 | tr -d '\r')
else
    ORIG_NUMERIC="Неизвестно"
    ORIG_ISO="Неизвестно"
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
    NEW_ISO=""
else
    _match=$(grep "^${NEW_CARRIER}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
    if [ -n "$_match" ]; then
        TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2 | tr -d '\r')
        TARGET_ISO=$(echo "$_match" | cut -d':' -f3 | tr -d '\r')
        TARGET_NAME=$(echo "$_match" | cut -d':' -f4 | tr -d '\r')
        NEW_ISO="$TARGET_ISO"
    fi
fi

# Перезапись файла настроек
printf "selected_carrier=%s\nlast_searched_iso=%s\n" "$NEW_CARRIER" "$NEW_ISO" > "$SETTINGS"
chmod 0600 "$SETTINGS"

# Применение пропсов через спаренные строки (маскировка Dual SIM)
if [ -n "$TARGET_NUMERIC" ] && [ -n "$TARGET_ISO" ] && [ "$TARGET_NUMERIC" != "Неизвестно" ]; then
    _set_prop "gsm.sim.operator.numeric" "${TARGET_NUMERIC}"
    _set_prop "gsm.sim.operator.iso-country" "${TARGET_ISO}"
    _set_prop "gsm.operator.numeric" "${TARGET_NUMERIC}"
    _set_prop "gsm.operator.iso-country" "${TARGET_ISO}"
fi

# ==========================================
# ВЫВОД ИНТЕРАКТИВНОГО СПИСКА В ТЕРМИНАЛ
# ==========================================
echo "-----------------------------------"
echo "СПИСОК ПРОФИЛЕЙ:"

if [ "$NEW_CARRIER" -eq 0 ]; then
    echo "-> Режим Авто (Используются родные пропсы) <-- АКТИВЕН"
else
    echo "   Режим Авто (Используются родные пропсы)"
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
