#!/system/bin/sh
MODDIR=${0%/*}
# Путь к логу на внутренней памяти
LOGFILE="/sdcard/Gpay-Spoofer.log"
CONF="$MODDIR/config.txt"

# Попытка создать файл лога для проверки доступа
touch $LOGFILE 2>/dev/null

# Загрузка конфига
[ -f "$CONF" ] && . "$CONF"

# Увеличим паузу, чтобы память точно успела смонтироваться
sleep 15

SOURCE_ISO=$(getprop gsm.sim.operator.iso-country)
# Очистка от лишних символов (важно для вашего случая с 'ru,')
CHECK_ISO=$(echo "$SOURCE_ISO" | tr -d ',' | tr -d ' ')

if [ "$CHECK_ISO" = "ru" ]; then
    echo "[$(date)] 🇷🇺→🇺🇸 Обнаружена SIM ($SOURCE_ISO). Спуфинг запущен." > $LOGFILE
    
    resetprop gsm.sim.operator.numeric "$TARGET_NUMERIC"
    resetprop gsm.sim.operator.alpha "$TARGET_ALPHA"
    resetprop gsm.sim.operator.iso-country "$TARGET_ISO"
    
    # Дублируем для слотов
    resetprop gsm.sim.operator.numeric.1 "$TARGET_NUMERIC"
    resetprop gsm.sim.operator.iso-country.1 "$TARGET_ISO"
    resetprop gsm.sim.operator.numeric.2 "$TARGET_NUMERIC"
    resetprop gsm.sim.operator.iso-country.2 "$TARGET_ISO"
    
    echo "[$(date)] ✅ Параметры $TARGET_ISO применены." >> $LOGFILE
else
    # Если спуфинг не нужен, всё равно пишем в лог, чтобы вы видели статус
    echo "[$(date)] ℹ️ Спуфинг не применен. Текущий ISO: '$SOURCE_ISO'" > $LOGFILE
fi