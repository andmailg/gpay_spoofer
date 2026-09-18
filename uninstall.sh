#!/system/bin/sh
# GPay-Spoofer — скрипт удаления (v3.0)

MODULE_DIR=$(dirname "$0")
LOGFILE="/sdcard/GPay-Spoofer.log"
OLD_PROPS_FILE="$MODULE_DIR/old_props.txt"
PROPS=(
    "gsm.sim.operator.alpha"
    "gsm.operator.alpha"
    "gsm.sim.operator.numeric"
    "gsm.operator.numeric"
    "gsm.sim.operator.iso-country"
    "gsm.operator.iso-country"
    "ro.cdma.home.operator.numeric"
)

echo "[`date`] 🔄 Удаление GPay-Spoofer..." >> $LOGFILE

# 1. Считываем сохраненные старые значения, если они есть
if [ -f "$OLD_PROPS_FILE" ]; then
    echo "[`date`] ♻️ Восстановление оригинальных параметров..." >> $LOGFILE
    
    i=0
    while IFS= read -r old_value; do
        prop_name="${PROPS[$i]}"
        if [ -n "$old_value" ]; then
            # Восстанавливаем сохраненное значение
            resetprop "$prop_name" "$old_value"
            echo "[`date`] Восстановлен: $prop_name = '$old_value'" >> $LOGFILE
        else
            # Если старое значение было пустым, удаляем свойство
            resetprop --delete "$prop_name"
            echo "[`date`] Удален: $prop_name (ранее пуст)" >> $LOGFILE
        fi
        i=$((i+1))
    done < "$OLD_PROPS_FILE"
    
    rm "$OLD_PROPS_FILE"
    echo "[`date`] ✅ Параметры успешно восстановлены/сброшены." >> $LOGFILE

else
    echo "[`date`] ⚠️ Файл старых параметров не найден. Выполняется чистое удаление..." >> $LOGFILE
    # Если старых значений нет, просто удаляем все свойства
    for prop in "${PROPS[@]}"; do
        resetprop --delete "$prop"
    done
    echo "[`date`] ✅ Параметры spoof удалены." >> $LOGFILE
fi

echo "[`date`] 🛑 Удаление GPay-Spoofer завершено." >> $LOGFILE