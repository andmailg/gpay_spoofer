#!/system/bin/sh

# ============================================================
# GPay Spoofer — uninstall.sh
# Удаляет файлы модуля и восстанавливает оригинальные свойства.
# ============================================================

LOGDIR="/data/adb"
LOGFILE="$LOGDIR/gpay-spoofer.log"

# --- Функция логирования ---
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

# --- Функция восстановления свойств ---
restore_prop() {
    _prop="$1"
    _val="$2"

    if [ -n "$_val" ]; then
        resetprop "$_prop" "$_val"
        log_msg "Восстановлен: $_prop = '$_val'"
    else
        resetprop --delete "$_prop"
        log_msg "Удалён: $_prop"
    fi
}

# --- Читаем сохранённые оригинальные значения ---
ORIG_ALPHA="$(getprop gsm.operator.alpha 2>/dev/null)"
ORIG_NUMERIC="$(getprop gsm.operator.numeric 2>/dev/null)"
ORIG_ISO="$(getprop gsm.operator.iso-country 2>/dev/null)"

# --- Восстанавливаем свойства ---
restore_prop "gsm.operator.alpha" "$ORIG_ALPHA"
restore_prop "gsm.operator.numeric" "$ORIG_NUMERIC"
restore_prop "gsm.operator.iso-country" "$ORIG_ISO"
restore_prop "gsm.sim.operator.alpha" "$ORIG_ALPHA"
restore_prop "gsm.sim.operator.numeric" "$ORIG_NUMERIC"
restore_prop "gsm.sim.operator.iso-country" "$ORIG_ISO"
restore_prop "ro.cdma.home.operator.numeric" ""

# --- Удаляем файлы данных ---
rm -f "$LOGDIR/gpay-spoofer.log"
rm -f "$LOGDIR/gpay-spoofer.lock"

log_msg "Uninstall: свойства восстановлены"

echo "GPay Spoofer удалён. Свойства восстановлены."
