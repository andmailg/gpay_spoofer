#!/system/bin/sh
# uninstall.sh — Удаление модуля и восстановление свойств
# POSIX-совместимый: без массивов, safe loading через sed

MODDIR="${0%/*}"
LOGFILE="/data/adb/Gpay-Spoofer.log"
OLD_PROPS_FILE="$MODDIR/old_props.dat"
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

    # --- Восстановление каждого свойства ---
    restore_prop() {
        _prop="$1"
        _val="$2"
        if [ -n "$_val" ]; then
            resetprop "$_prop" "$_val"
            log_msg "  Восстановлен: $_prop = '$_val'"
        else
            resetprop --delete "$_prop"
            log_msg "  Удалён: $_prop"
        fi
    }

    restore_prop "gsm.sim.operator.alpha" "$ORIG_ALPHA_SIM"
    restore_prop "gsm.operator.alpha" "$ORIG_ALPHA_OP"
    restore_prop "gsm.sim.operator.numeric" "$ORIG_NUMERIC_SIM"
    restore_prop "gsm.operator.numeric" "$ORIG_NUMERIC_OP"
    restore_prop "gsm.sim.operator.iso-country" "$ORIG_ISO_SIM"
    restore_prop "gsm.operator.iso-country" "$ORIG_ISO_OP"
    restore_prop "ro.cdma.home.operator.numeric" "$ORIG_CDMA"

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
rm -f "$MODDIR/.spoof_applied"

log_msg "🛑 Удаление GPay-Spoofer завершено."

# Копирование лога (поздно, после монтирования)
(
    sleep 10
    cp "$LOGFILE" /sdcard/Gpay-Spoofer.log 2>/dev/null
) &
