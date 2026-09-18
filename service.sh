#!/system/bin/sh
# Автоспуфер оператора: Россия → Выбранный оператор

MODDIR="${0%/*}"
LOGFILE="/data/adb/Gpay-Spoofer.log"
CONFIG="$MODDIR/config.txt"
SETTINGS="$MODDIR/settings"
OLD_PROPS_FILE="$MODDIR/old_props.txt"

until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

sleep 5

echo "--------------------------------------" >> "$LOGFILE"
echo "[$(date)] 🚀 GPay-Spoofer запущен" >> "$LOGFILE"

if [ -f "$CONFIG" ]; then
    . "$CONFIG"
else
    echo "[$(date)] ❌ Ошибка: Конфиг не найден в $CONFIG" >> "$LOGFILE"
    exit 1
fi

SELECTED_CARRIER="0"
if [ -f "$SETTINGS" ]; then
    VAL=$(grep "^selected_carrier=" "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | tr -d '[:space:]')
    [ -n "$VAL" ] && SELECTED_CARRIER="$VAL"
fi

echo "[$(date)] Выбранный оператор (ID): $SELECTED_CARRIER" >> "$LOGFILE"

case "$SELECTED_CARRIER" in
    0)
        TARGET_ALPHA="$LM_ALPHA"
        TARGET_NUMERIC="$LM_NUMERIC"
        TARGET_ISO="$LM_ISO"
        TARGET_NAME="Latvijas Mobilais (Latvia)"
        ;;
    1)
        TARGET_ALPHA="$ATT_ALPHA"
        TARGET_NUMERIC="$ATT_NUMERIC"
        TARGET_ISO="$ATT_ISO"
        TARGET_NAME="AT&T (USA)"
        ;;
    2)
        TARGET_ALPHA="$TM_ALPHA"
        TARGET_NUMERIC="$TM_NUMERIC"
        TARGET_ISO="$TM_ISO"
        TARGET_NAME="T-Mobile (USA)"
        ;;
    *)
        TARGET_ALPHA="$LM_ALPHA"
        TARGET_NUMERIC="$LM_NUMERIC"
        TARGET_ISO="$LM_ISO"
        TARGET_NAME="Latvijas Mobilais (Latvia) [default]"
        ;;
esac

sim_country=$(getprop gsm.sim.operator.iso-country)
clean_sim_country=$(echo "$sim_country" | tr -d ' ,' )

echo "[$(date)] Статус SIM: '$sim_country'" >> "$LOGFILE"

has_ru=false
case "$sim_country" in
    *"$SOURCE_ISO"*) has_ru=true ;;
esac

only_ru=false
if [ "$clean_sim_country" = "$SOURCE_ISO" ] || [ "$clean_sim_country" = "${SOURCE_ISO}${SOURCE_ISO}" ]; then
    only_ru=true
fi

if [ "$has_ru" = "true" ] && [ "$only_ru" = "true" ]; then
    echo "[$(date)] ⚠️ Обнаружена только RU SIM. Применяем спуф ($TARGET_NAME)." >> "$LOGFILE"

    # Сохраняем свойства в формате переменная=значение для надежного восстановления
    {
        echo "val1='$(getprop gsm.sim.operator.alpha)'"
        echo "val2='$(getprop gsm.operator.alpha)'"
        echo "val3='$(getprop gsm.sim.operator.numeric)'"
        echo "val4='$(getprop gsm.operator.numeric)'"
        echo "val5='$(getprop gsm.sim.operator.iso-country)'"
        echo "val6='$(getprop gsm.operator.iso-country)'"
        echo "val7='$(getprop ro.cdma.home.operator.numeric)'"
    } > "$OLD_PROPS_FILE"

    resetprop gsm.sim.operator.alpha "$TARGET_ALPHA"
    resetprop gsm.operator.alpha "$TARGET_ALPHA"
    resetprop gsm.sim.operator.numeric "$TARGET_NUMERIC"
    resetprop gsm.operator.numeric "$TARGET_NUMERIC"
    resetprop gsm.sim.operator.iso-country "$TARGET_ISO"
    resetprop gsm.operator.iso-country "$TARGET_ISO"
    resetprop ro.cdma.home.operator.numeric "$TARGET_NUMERIC"

    echo "[$(date)] ✅ Спуфинг применен: $SOURCE_ISO -> $TARGET_ISO ($TARGET_NAME)" >> "$LOGFILE"
else
    echo "[$(date)] ℹ️ Условия для спуфинга не выполнены." >> "$LOGFILE"
    [ -f "$OLD_PROPS_FILE" ] && rm "$OLD_PROPS_FILE"
fi

cp "$LOGFILE" /sdcard/Gpay-Spoofer.log 2>/dev/null