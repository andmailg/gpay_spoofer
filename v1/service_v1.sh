#!/system/bin/sh
# Автоспуфер оператора: Россия → Латвия (v2.1)

# Используем надежный путь для лога, который доступен всегда
LOGFILE="/data/adb/Gpay-Spoofer.log"
# Пытаемся найти папку модуля
MODDIR="/data/adb/modules/GPay-Spoofer"
CONFIG="$MODDIR/config.txt"
OLD_PROPS_FILE="$MODDIR/old_props.txt"

# 1. Ждем полной загрузки системы и монтирования данных
until [ "$(getprop sys.boot_completed)" = "1" ]; do
    sleep 2
done

# Ждем еще немного, чтобы точно подтянулись свойства SIM
sleep 10

echo "[$(date)] 🚀 GPay-Spoofer запущен" >> $LOGFILE

# 2. Проверка наличия конфига
if [ ! -f "$CONFIG" ]; then
    echo "[$(date)] ❌ Ошибка: Конфиг не найден в $CONFIG" >> $LOGFILE
    exit 1
fi

# Загружаем переменные
. "$CONFIG"

# Получаем данные SIM
sim_country=$(getprop gsm.sim.operator.iso-country)
echo "[$(date)] Текущий iso-country: $sim_country" >> $LOGFILE

if echo "$sim_country" | grep -q "$SOURCE_ISO"; then
    echo "[$(date)] 🇷🇺→🇱🇻 Обнаружена SIM '$SOURCE_ISO'. Применяем спуф." >> $LOGFILE

    # Сохраняем текущие значения
    {
        getprop gsm.sim.operator.alpha
        getprop gsm.operator.alpha
        getprop gsm.sim.operator.numeric
        getprop gsm.operator.numeric
        getprop gsm.sim.operator.iso-country
        getprop gsm.operator.iso-country
        getprop ro.cdma.home.operator.numeric
    } > "$OLD_PROPS_FILE"

    # Применяем подмену
    resetprop gsm.sim.operator.alpha "$TARGET_ALPHA"
    resetprop gsm.sim.operator.numeric "$TARGET_NUMERIC"
    resetprop gsm.sim.operator.iso-country "$TARGET_ISO"
    
    resetprop gsm.operator.alpha "$TARGET_ALPHA"
    resetprop gsm.operator.numeric "$TARGET_NUMERIC"
    resetprop gsm.operator.iso-country "$TARGET_ISO"

    resetprop ro.cdma.home.operator.numeric "$TARGET_NUMERIC"

    echo "[$(date)] ✅ Спуфинг успешно применен." >> $LOGFILE
else
    echo "[$(date)] ℹ️ SIM не '$SOURCE_ISO', действие не требуется." >> $LOGFILE
    [ -f "$OLD_PROPS_FILE" ] && rm "$OLD_PROPS_FILE"
fi

# Копируем лог на SD-карту для удобного чтения пользователем (если она уже доступна)
cp $LOGFILE /sdcard/Gpay-Spoofer.log 2>/dev/null
