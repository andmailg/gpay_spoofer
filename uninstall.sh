#!/system/bin/sh
# GPay Spoofer — uninstall.sh (Финальная версия)

MODDIR="${0%/*}"
PROPS_FILE="$MODDIR/original_props"
LOGFILE="$MODDIR/Gpay-Spoofer.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [UNINSTALL] $1" >> "$LOGFILE" 2>/dev/null
}

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

ORIG_NUMERIC=""
ORIG_ISO=""
ORIG_CDMA=""

if [ -f "$PROPS_FILE" ]; then
    . "$PROPS_FILE"
    log_msg "Файл оригинальных свойств успешно прочитан."
else
    ORIG_NUMERIC="$(getprop gsm.operator.numeric)"
    ORIG_ISO="$(getprop gsm.operator.iso-country)"
    ORIG_CDMA="$(getprop ro.cdma.home.operator.numeric)"
    log_msg "⚠️ Предупреждение: Файл оригинальных свойств не найден! Сняты текущие значения."
fi

# Восстановление CDMA-свойств и базовых значений
restore_prop "gsm.operator.numeric" "$ORIG_NUMERIC"
restore_prop "gsm.operator.iso-country" "$ORIG_ISO"
restore_prop "ro.cdma.home.operator.numeric" "$ORIG_CDMA"

# Восстановление мультисимовых слотов списком
for suffix in "" ".1" ".2"; do
    restore_prop "gsm.sim.operator.numeric$suffix" "$ORIG_NUMERIC"
    restore_prop "gsm.sim.operator.iso-country$suffix" "$ORIG_ISO"
    restore_prop "gsm.operator.numeric$suffix" "$ORIG_NUMERIC"
    restore_prop "gsm.operator.iso-country$suffix" "$ORIG_ISO"
done

rm -f "$MODDIR/my_card.bin.cache"

log_msg "Uninstall завершен: свойства возвращены к заводским."
echo "GPay Spoofer удалён. Оригинальные свойства восстановлены."
