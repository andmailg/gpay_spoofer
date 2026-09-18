#!/system/bin/sh
# Автоспуфер оператора: Россия → Латвия (v2.2)

# 1. Настройка путей
LOGFILE="/data/adb/Gpay-Spoofer.log"
MODDIR="/data/adb/modules/GPay-Spoofer"
CONFIG="$MODDIR/config.txt"
OLD_PROPS_FILE="$MODDIR/old_props.txt"

# 2. Ожидание загрузки системы
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# Ждем инициализации данных SIM-карт
sleep 10

echo "--------------------------------------" >> $LOGFILE
echo "[$(date)] 🚀 GPay-Spoofer запущен" >> $LOGFILE

# 3. Загрузка конфигурации
if [ -f "$CONFIG" ]; then
    . "$CONFIG"
else
    echo "[$(date)] ❌ Ошибка: Конфиг не найден в $CONFIG" >> $LOGFILE
    exit 1
fi

# 4. Анализ SIM-карт
sim_country=$(getprop gsm.sim.operator.iso-country)
# Очищаем строку от пробелов и запятых для точной проверки
clean_sim_country=$(echo "$sim_country" | tr -d ' ,' )

echo "[$(date)] Статус SIM: '$sim_country'" >> $LOGFILE

# Проверка условий:
# - Содержит ли строка 'ru'
# - Есть ли в строке что-то КРОМЕ 'ru'
has_ru=$(echo "$sim_country" | grep -q "$SOURCE_ISO" && echo true || echo false)
only_ru=false
if [ "$clean_sim_country" = "$SOURCE_ISO" ] || [ "$clean_sim_country" = "${SOURCE_ISO}${SOURCE_ISO}" ]; then
    only_ru=true
fi

if [ "$has_ru" = "true" ] && [ "$only_ru" = "true" ]; then
    echo "[$(date)] ⚠️ Обнаружена только RU SIM. Применяем спуф." >> $LOGFILE

    # Сохраняем текущие значения перед подменой
    {
        getprop gsm.sim.operator.alpha
        getprop gsm.operator.alpha
        getprop gsm.sim.operator.numeric
        getprop gsm.operator.numeric
        getprop gsm.sim.operator.iso-country
        getprop gsm.operator.iso-country
        getprop ro.cdma.home.operator.numeric
    } > "$OLD_PROPS_FILE"

    # Применяем подмену на Латвию (из config.txt)
    resetprop gsm.sim.operator.alpha "$TARGET_ALPHA"
    resetprop gsm.operator.alpha "$TARGET_ALPHA"
    resetprop gsm.sim.operator.numeric "$TARGET_NUMERIC"
    resetprop gsm.operator.numeric "$TARGET_NUMERIC"
    resetprop gsm.sim.operator.iso-country "$TARGET_ISO"
    resetprop gsm.operator.iso-country "$TARGET_ISO"
    resetprop ro.cdma.home.operator.numeric "$TARGET_NUMERIC"

    echo "[$(date)] ✅ Спуфинг применен: $SOURCE_ISO -> $TARGET_ISO" >> $LOGFILE

elif [ "$has_ru" = "true" ] && [ "$only_ru" = "false" ]; then
    echo "[$(date)] ℹ️ Найдена комбинация SIM (RU + другая страна). Спуфинг отключен, чтобы GPay работал через иностранную карту." >> $LOGFILE
    [ -f "$OLD_PROPS_FILE" ] && rm "$OLD_PROPS_FILE"

else
    echo "[$(date)] ℹ️ Российских SIM не обнаружено. Спуфинг не требуется." >> $LOGFILE
    [ -f "$OLD_PROPS_FILE" ] && rm "$OLD_PROPS_FILE"
fi

# 5. Дублируем лог на внутреннюю память для удобного чтения пользователем
cp $LOGFILE /sdcard/Gpay-Spoofer.log 2>/dev/null
