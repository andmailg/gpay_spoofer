#!/system/bin/sh

# ============================================================
# GPay Spoofer — uninstall.sh
# Удаляет файлы модуля и восстанавливает оригинальные свойства.
# ============================================================

MODDIR="${0%/*}"
PROPS_FILE="$MODDIR/original_props"
LOGFILE="/sdcard/Gpay-Spoofer.log"
LOCKFILE="/data/adb/gpay-spoofer.lock"

# --- Функция логирования ---
log_msg() {
    msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    if [ -d "/sdcard" ]; then
        [ ! -f "$LOGFILE" ] && touch "$LOGFILE" 2>/dev/null
        [ -f "$LOGFILE" ] && echo "$msg" >> "$LOGFILE"
    fi
}

# --- Функция восстановления свойств ---
restore_prop() {
    _prop="$1"
    _val="$2"

    if [ -n "$_val" ]; then
        resetprop "$_prop" "$_val"
        log_msg "Восстановлен: $_prop = '$_val'"
    else
        resetprop --delete "$_prop" 2>/dev/null
        log_msg "Удалён: $_prop"
    fi
}

log_msg "--- НАЧАЛО ПРОЦЕССА УДАЛЕНИЯ МОДУЛЯ ---"

# --- Читаем сохранённые оригинальные значения из бэкапа ---
ORIG_NUMERIC=""
ORIG_ISO=""

if [ -f "$PROPS_FILE" ]; then
    # Подгружаем сохраненные при первом старте переменные ORIG_NUMERIC и ORIG_ISO
    . "$PROPS_FILE"
    log_msg "Файл бэкапа оригинальных свойств успешно прочитан."
else
    # Фоллбэк: если бэкапа нет, пытаемся взять текущие (минимальный шанс спасти свойства)
    ORIG_NUMERIC="$(getprop gsm.operator.numeric)"
    ORIG_ISO="$(getprop gsm.operator.iso-country)"
    log_msg "⚠️ Предупреждение: Файл бэкапа оригинальных свойств не найден!"
fi

# --- Восстанавливаем свойства ---
restore_prop "gsm.operator.numeric" "$ORIG_NUMERIC"
restore_prop "gsm.operator.iso-country" "$ORIG_ISO"
restore_prop "gsm.sim.operator.numeric" "$ORIG_NUMERIC"
restore_prop "gsm.sim.operator.iso-country" "$ORIG_ISO"
restore_prop "ro.cdma.home.operator.numeric" ""

# Мульти-SIM слоты
restore_prop "gsm.sim.operator.numeric.1" "$ORIG_NUMERIC"
restore_prop "gsm.sim.operator.iso-country.1" "$ORIG_ISO"
restore_prop "gsm.sim.operator.numeric.2" "$ORIG_NUMERIC"
restore_prop "gsm.sim.operator.iso-country.2" "$ORIG_ISO"

# --- Удаляем мусорные файлы данных ---
rm -f "$LOCKFILE"
rm -f "$MODDIR/my_card.bin.cache"

log_msg "Uninstall: свойства восстановлены, кэш очищен."
echo "GPay Spoofer удалён. Оригинальные свойства восстановлены."
