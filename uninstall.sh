#!/system/bin/sh
# uninstall.sh — Удаление модуля и восстановление свойств
# Исправления: safe loading (sed вместо . "$FILE"), lock, trap

MODULE_DIR="${0%/*}"
LOGFILE="/data/adb/Gpay-Spoofer.log"
OLD_PROPS_FILE="$MODULE_DIR/old_props.dat"
LOCKFILE="/data/adb/gpay-spoofer-uninstall.lock"

# --- Обеспечиваем /data/adb ---
mkdir -p /data/adb

# --- Логирование ---
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

# --- Trap: очистка ---
cleanup() {
    rm -f "$LOCKFILE"
}
trap cleanup EXIT INT TERM HUP

# --- Блокировка ---
if [ -e "$LOCKFILE" ]; then
    log_msg "⚠️ uninstall.sh уже запущен. Выход."
    exit 1
fi
touch "$LOCKFILE"

log_msg "🔄 Удаление GPay-Spoofer..."

# Список свойств
PROPS=(
    "gsm.sim.operator.alpha"
    "gsm.operator.alpha"
    "gsm.sim.operator.numeric"
    "gsm.sim.operator.numeric"
    "gsm.sim.operator.iso-country"
    "gsm.operator.iso-country"
    "ro.cdma.home.operator.numeric"
)

# --- Безопасное восстановление из key=value файла ---
if [ -r "$OLD_PROPS_FILE" ]; then
    log_msg "♻️ Восстановление оригинальных параметров..."

    # Извлекаем значения через sed (безопасно, не shell-код)
    get_val() {
        sed -n "s/^${1}=//p" "$OLD_PROPS_FILE" 2>/dev/null
    }

    ORIG_ALPHA_SIM=$(get_val "gsm.sim.operator.alpha")
    ORIG_ALPHA_OP=$(get_val "gsm.operator.alpha")
    ORIG_NUMERIC_SIM=$(get_val "gsm.sim.operator.numeric")
    ORIG_NUMERIC_OP=$(get_val "gsm.operator.numeric")
    ORIG_ISO_SIM=$(get_val "gsm.sim.operator.iso-country")
    ORIG_ISO_OP=$(get_val "gsm.operator.iso-country")
    ORIG_CDMA=$(get_val "ro.cdma.home.operator.numeric")

    # Применяем сохранённые значения или удаляем
    if [ -n "$ORIG_ALPHA_SIM" ]; then
        resetprop gsm.sim.operator.alpha "$ORIG_ALPHA_SIM"
        log_msg "  Восстановлен: gsm.sim.operator.alpha = '$ORIG_ALPHA_SIM'"
    else
        resetprop --delete gsm.sim.operator.alpha
        log_msg "  Удалён: gsm.sim.operator.alpha"
    fi

    if [ -n "$ORIG_ALPHA_OP" ]; then
        resetprop gsm.operator.alpha "$ORIG_ALPHA_OP"
        log_msg "  Восстановлен: gsm.operator.alpha = '$ORIG_ALPHA_OP'"
    else
        resetprop --delete gsm.operator.alpha
        log_msg "  Удалён: gsm.operator.alpha"
    fi

    if [ -n "$ORIG_NUMERIC_SIM" ]; then
        resetprop gsm.sim.operator.numeric "$ORIG_NUMERIC_SIM"
        log_msg "  Восстановлен: gsm.sim.operator.numeric = '$ORIG_NUMERIC_SIM'"
    else
        resetprop --delete gsm.sim.operator.numeric
        log_msg "  Удалён: gsm.sim.operator.numeric"
    fi

    if [ -n "$ORIG_NUMERIC_OP" ]; then
        resetprop gsm.operator.numeric "$ORIG_NUMERIC_OP"
        log_msg "  Восстановлен: gsm.operator.numeric = '$ORIG_NUMERIC_OP'"
    else
        resetprop --delete gsm.operator.numeric
        log_msg "  Удалён: gsm.operator.numeric"
    fi

    if [ -n "$ORIG_ISO_SIM" ]; then
        resetprop gsm.sim.operator.iso-country "$ORIG_ISO_SIM"
        log_msg "  Восстановлен: gsm.sim.operator.iso-country = '$ORIG_ISO_SIM'"
    else
        resetprop --delete gsm.sim.operator.iso-country
        log_msg "  Удалён: gsm.sim.operator.iso-country"
    fi

    if [ -n "$ORIG_ISO_OP" ]; then
        resetprop gsm.operator.iso-country "$ORIG_ISO_OP"
        log_msg "  Восстановлен: gsm.operator.iso-country = '$ORIG_ISO_OP'"
    else
        resetprop --delete gsm.operator.iso-country
        log_msg "  Удалён: gsm.operator.iso-country"
    fi

    if [ -n "$ORIG_CDMA" ]; then
        resetprop ro.cdma.home.operator.numeric "$ORIG_CDMA"
        log_msg "  Восстановлен: ro.cdma.home.operator.numeric = '$ORIG_CDMA'"
    else
        resetprop --delete ro.cdma.home.operator.numeric
        log_msg "  Удалён: ro.cdma.home.operator.numeric"
    fi

    rm -f "$OLD_PROPS_FILE"
    log_msg "✅ Параметры восстановлены."
else
    log_msg "⚠️ Файл старых параметров не найден. Сброс свойств..."
    for prop in \
        gsm.sim.operator.alpha \
        gsm.operator.alpha \
        gsm.sim.operator.numeric \
        gsm.operator.numeric \
        gsm.sim.operator.iso-country \
        gsm.operator.iso-country \
        ro.cdma.home.operator.numeric; do
        resetprop --delete "$prop"
        log_msg "  Удалён: $prop"
    done
    log_msg "✅ Свойства сброшены."
fi

# Удаление маркера
rm -f "$MODULE_DIR/.spoof_applied"

log_msg "🛑 Удаление GPay-Spoofer завершено."

# Копирование лога (поздно, после монтирования)
(
    sleep 10
    cp "$LOGFILE" /sdcard/Gpay-Spoofer.log 2>/dev/null
) &
