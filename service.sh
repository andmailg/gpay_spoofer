#!/system/bin/sh
# Автоспуфер оператора: Россия → Выбранный оператор (v4.0)

# 1. Настройка путей
LOGFILE="/data/adb/Gpay-Spoofer.log"
MODDIR="/data/adb/modules/GPay-Spoofer"
CONFIG="$MODDIR/config.txt"
SETTINGS="$MODDIR/settings"
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

# 4. Чтение выбранного оператора из Magisk Settings
SELECTED_CARRIER="0"  # Дефолт: Latvijas Mobilais
if [ -f "$SETTINGS" ]; then
    SELECTED_CARRIER=$(grep "^selected_carrier=" "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | tr -d '[:space:]')
    if [ -z "$SELECTED_CARRIER" ]; then
        SELECTED_CARRIER="0"
    fi
fi

echo "[$(date)] Выбранный оператор (ID): $SELECTED_CARRIER" >> $LOGFILE

# 5. Выбор параметров оператора на основе ID
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
        echo "[$(date)] ⚠️ Неизвестный ID оператора, используется Latvijas Mobilais по умолчанию" >> $LOGFILE
        ;;
esac

echo "[$(date)] ✅ Выбран оператор: $TARGET_NAME" >> $LOGFILE

# 6. Анализ SIM-карт
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
    echo "[$(date)] ⚠️ Обнаружена только RU SIM. Применяем спуф ($TARGET_NAME)." >> $LOGFILE

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

    # Применяем подмену выбранного оператора
    resetprop gsm.sim.operator.alpha "$TARGET_ALPHA"
    resetprop gsm.operator.alpha "$TARGET_ALPHA"
    resetprop gsm.sim.operator.numeric "$TARGET_NUMERIC"
    resetprop gsm.operator.numeric "$TARGET_NUMERIC"
    resetprop gsm.sim.operator.iso-country "$TARGET_ISO"
    resetprop gsm.operator.iso-country "$TARGET_ISO"
    resetprop ro.cdma.home.operator.numeric "$TARGET_NUMERIC"

    echo "[$(date)] ✅ Спуфинг применен: $SOURCE_ISO -> $TARGET_ISO ($TARGET_NAME)" >> $LOGFILE

elif [ "$has_ru" = "true" ] && [ "$only_ru" = "false" ]; then
    echo "[$(date)] ℹ️ Найдена комбинация SIM (RU + другая страна). Спуфинг отключен, чтобы GPay работал через иностранную карту." >> $LOGFILE
    [ -f "$OLD_PROPS_FILE" ] && rm "$OLD_PROPS_FILE"

else
    echo "[$(date)] ℹ️ Российских SIM не обнаружено. Спуфинг не требуется." >> $LOGFILE
    [ -f "$OLD_PROPS_FILE" ] && rm "$OLD_PROPS_FILE"
fi

# 7. Дублируем лог на внутреннюю память для удобного чтения пользователем
cp $LOGFILE /sdcard/Gpay-Spoofer.log 2>/dev/null
