#!/system/bin/sh
# service.sh — Автоспуфер оператора: Россия → Выбранный оператор
# Исправления: валидация конфига, safe props, dual-SIM, lock, trap, timeout

MODDIR="${0%/*}"
LOGFILE="/data/adb/Gpay-Spoofer.log"
LOCKFILE="/data/adb/gpay-spoofer.lock"
CONFIG="$MODDIR/config.txt"
SETTINGS="$MODDIR/settings"
OLD_PROPS_FILE="$MODDIR/old_props.dat"
MARKER_FILE="$MODDIR/.spoof_applied"

# --- Обеспечиваем существование /data/adb ---
mkdir -p /data/adb
chmod 0700 /data/adb

# --- Логирование ---
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

# --- Trap: очистка при любом выходе ---
cleanup() {
    rm -f "$LOCKFILE"
}
trap cleanup EXIT INT TERM HUP

# --- Блокировка: не запускать дважды ---
if [ -e "$LOCKFILE" ]; then
    # Проверяем, не жив ли предыдущий процесс
    LOCK_PID=$(cat "$LOCKFILE" 2>/dev/null)
    if [ -n "$LOCK_PID" ] && [ -d "/proc/$LOCK_PID" ]; then
        log_msg "⚠️ GPay-Spoofer уже запущен (PID $LOCK_PID). Выход."
        exit 0
    else
        # Мёртвый lock — перезаписываем
        log_msg "⚠️ Найден мёртвый lock-файл. Перезапись."
    fi
fi
echo $$ > "$LOCKFILE"

# --- Лог ---
echo "--------------------------------------" > "$LOGFILE"
log_msg "🚀 GPay-Spoofer запущен (PID $$)"

# --- Ожидание завершения загрузки ---
boot_timeout=60
boot_elapsed=0
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
    boot_elapsed=$((boot_elapsed + 2))
    if [ "$boot_elapsed" -ge "$boot_timeout" ]; then
        log_msg "⚠️ Таймаут ожидания загрузки ($boot_timeout сек). Продолжаем."
        break
    fi
done

# --- Ожидание инициализации SIM (с таймаутом) ---
sim_timeout=30
sim_elapsed=0
while [ -z "$(getprop gsm.sim.operator.iso-country)" ] && [ "$sim_elapsed" -lt "$sim_timeout" ]; do
    sleep 2
    sim_elapsed=$((sim_elapsed + 2))
done
if [ "$sim_elapsed" -ge "$sim_timeout" ]; then
    log_msg "⚠️ SIM не определена за $sim_timeout сек. Продолжаем."
else
    log_msg "SIM определена за ${sim_elapsed} сек."
fi

sleep 3

# --- Валидация config.txt ---
if [ ! -r "$CONFIG" ]; then
    log_msg "❌ Конфиг не найден или не читается: $CONFIG"
    exit 1
fi

# Подключаем только если это доверенный статический файл
. "$CONFIG"

# Проверяем обязательные переменные
[ -n "$SOURCE_ISO" ] || { log_msg "❌ В конфиге отсутствует SOURCE_ISO"; exit 1; }
[ -n "$LM_ALPHA" ]    || { log_msg "❌ В конфиге отсутствует LM_ALPHA"; exit 1; }
[ -n "$LM_NUMERIC" ]  || { log_msg "❌ В конфиге отсутствует LM_NUMERIC"; exit 1; }
[ -n "$LM_ISO" ]      || { log_msg "❌ В конфиге отсутствует LM_ISO"; exit 1; }

log_msg "Конфиг загружен: SOURCE_ISO=$SOURCE_ISO"

# --- Чтение выбранного профиля ---
SELECTED_CARRIER="0"
if [ -r "$SETTINGS" ]; then
    VAL=$(grep "^selected_carrier=" "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | tr -d '[:space:]')
    case "$VAL" in
        0|1|2) SELECTED_CARRIER="$VAL" ;;
        *) log_msg "⚠️ Неверное значение в settings ($VAL), используем 0" ;;
    esac
fi

log_msg "Выбранный оператор (ID): $SELECTED_CARRIER"

# --- Определение целевого оператора ---
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

# --- Проверка SIM: точное сравнение, поддержка dual-SIM ---
# Проверяем все возможные слоты SIM
SIM_COUNTRIES=""
for slot_prop in \
    gsm.sim.operator.iso-country \
    gsm.sim.operator.iso-country.0 \
    gsm.sim.operator.iso-country.1 \
    gsm.sim.operator.iso-country.slot0 \
    gsm.sim.operator.iso-country.slot1; do
    VAL=$(getprop "$slot_prop" 2>/dev/null)
    if [ -n "$VAL" ]; then
        SIM_COUNTRIES="$SIM_COUNTRIES $VAL"
    fi
done

SOURCE_ISO_LC=$(echo "$SOURCE_ISO" | tr '[:upper:]' '[:lower:]' | tr -d ' ,')

has_ru=false
for sim_country in $SIM_COUNTRIES; do
    clean_sim=$(echo "$sim_country" | tr '[:upper:]' '[:lower:]' | tr -d ' ,')
    # Точное сравнение, не подстрока
    if [ "$clean_sim" = "$SOURCE_ISO_LC" ]; then
        has_ru=true
        break
    fi
done

log_msg "Статус SIM:$SIM_COUNTRIES has_ru=$has_ru"

if [ "$has_ru" = "true" ]; then
    log_msg "⚠️ Обнаружена RU SIM. Применяем спуф ($TARGET_NAME)."

    # --- Безопасное сохранение свойств (key=value, не shell-код) ---
    {
        echo "gsm.sim.operator.alpha=$(getprop gsm.sim.operator.alpha)"
        echo "gsm.operator.alpha=$(getprop gsm.operator.alpha)"
        echo "gsm.sim.operator.numeric=$(getprop gsm.sim.operator.numeric)"
        echo "gsm.operator.numeric=$(getprop gsm.operator.numeric)"
        echo "gsm.sim.operator.iso-country=$(getprop gsm.sim.operator.iso-country)"
        echo "gsm.operator.iso-country=$(getprop gsm.operator.iso-country)"
        echo "ro.cdma.home.operator.numeric=$(getprop ro.cdma.home.operator.numeric)"
    } > "$OLD_PROPS_FILE"
    chmod 0600 "$OLD_PROPS_FILE"

    # Помечаем, что спуф применён
    echo "applied" > "$MARKER_FILE"

    # --- Применение свойств ---
    resetprop gsm.sim.operator.alpha "$TARGET_ALPHA"
    resetprop gsm.operator.alpha "$TARGET_ALPHA"
    resetprop gsm.sim.operator.numeric "$TARGET_NUMERIC"
    resetprop gsm.operator.numeric "$TARGET_NUMERIC"
    resetprop gsm.sim.operator.iso-country "$TARGET_ISO"
    resetprop gsm.operator.iso-country "$TARGET_ISO"
    resetprop ro.cdma.home.operator.numeric "$TARGET_NUMERIC"

    log_msg "✅ Спуфинг применён: $SOURCE_ISO -> $TARGET_ISO ($TARGET_NAME)"
else
    log_msg "ℹ️ Условия для спуфинга не выполнены."
    # Если спуф не нужен — удаляем маркер, но старые свойства не трогаем
    rm -f "$MARKER_FILE"
fi

# --- Копирование лога в /sdcard (поздно, после монтирования) ---
# Пробуем один раз через 10 секунд, не блокируя основной поток
(
    sleep 10
    cp "$LOGFILE" /sdcard/Gpay-Spoofer.log 2>/dev/null
) &

log_msg "✅ service.sh завершён."
