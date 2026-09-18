#!/system/bin/sh
# GPay-Spoofer — скрипт удаления

MODULE_DIR="${0%/*}"
LOGFILE="/data/adb/Gpay-Spoofer.log"
OLD_PROPS_FILE="$MODULE_DIR/old_props.txt"

echo "[$(date)] 🔄 Удаление GPay-Spoofer..." >> "$LOGFILE"

PROP1="gsm.sim.operator.alpha"
PROP2="gsm.operator.alpha"
PROP3="gsm.sim.operator.numeric"
PROP4="gsm.operator.numeric"
PROP5="gsm.sim.operator.iso-country"
PROP6="gsm.operator.iso-country"
PROP7="ro.cdma.home.operator.numeric"

if [ -f "$OLD_PROPS_FILE" ]; then
    echo "[$(date)] ♻️ Восстановление оригинальных параметров..." >> "$LOGFILE"
    
    # Безопасно загружаем сохраненные переменные
    . "$OLD_PROPS_FILE"

    set -- "$val1" "$val2" "$val3" "$val4" "$val5" "$val6" "$val7"
    for prop in "$PROP1" "$PROP2" "$PROP3" "$PROP4" "$PROP5" "$PROP6" "$PROP7"; do
        val="$1"
        shift

        if [ -n "$val" ]; then
            resetprop "$prop" "$val"
            echo "[$(date)] Восстановлен: $prop = '$val'" >> "$LOGFILE"
        else
            resetprop --delete "$prop"
            echo "[$(date)] Удален: $prop" >> "$LOGFILE"
        fi
    done
    
    rm -f "$OLD_PROPS_FILE"
    echo "[$(date)] ✅ Параметры успешно восстановлены." >> "$LOGFILE"
else
    echo "[$(date)] ⚠️ Файл старых параметров не найден. Очистка свойств..." >> "$LOGFILE"
    for prop in "$PROP1" "$PROP2" "$PROP3" "$PROP4" "$PROP5" "$PROP6" "$PROP7"; do
        resetprop --delete "$prop"
    done
    echo "[$(date)] ✅ Свойства сброшены." >> "$LOGFILE"
fi

echo "[$(date)] 🛑 Удаление GPay-Spoofer завершено." >> "$LOGFILE"
cp "$LOGFILE" /sdcard/Gpay-Spoofer.log 2>/dev/null