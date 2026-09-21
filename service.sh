#!/system/bin/sh

# ============================================================
# GPay Spoofer — service.sh
# ============================================================

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
LOGFILE="/sdcard/Gpay-Spoofer.log"
LOCKFILE="/data/adb/gpay-spoofer.lock"

# --- Блокировка: не запускать два экземпляра ---
if [ -e "$LOCKFILE" ]; then
    exit 0
fi

touch "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# --- Проверяем, это старт при загрузке или горячий перезапуск ---
IS_BOOTED="$(getprop sys.boot_completed)"

if [ "$IS_BOOTED" != "1" ]; then
    # Медленный режим: ждем загрузку ОС при включении телефона
    timeout=30
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 2
        timeout=$((timeout - 1))
        if [ "$timeout" -le 0 ]; then break; fi
    done
    sleep 10
else
    # Быстрый режим: система уже активна, микро-пауза для стабильности
    sleep 1
fi

# --- Ждем монтирования внутренней памяти ---
storage_timeout=30
while [ ! -d "/sdcard/Android" ]; do
    sleep 2
    storage_timeout=$((storage_timeout - 1))
    if [ "$storage_timeout" -le 0 ]; then break; fi
done

if [ -d "/sdcard" ]; then
    [ ! -f "$LOGFILE" ] && touch "$LOGFILE"
fi

# --- Читаем выбранный профиль ---
SELECTED_CARRIER="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"

case "$SELECTED_CARRIER" in
    0|1|2|3) ;;
    *) SELECTED_CARRIER=0 ;;
esac

# --- Сохраняем оригинальные значения (только если файла еще нет) ---
if [ ! -f "$MODDIR/original_props" ] || [ "$SELECTED_CARRIER" -eq 0 ]; then
    ORIG_NUMERIC="$(getprop gsm.operator.numeric 2>/dev/null)"
    ORIG_ISO="$(getprop gsm.operator.iso-country 2>/dev/null)"
    
    # Записываем бэкап, только если свойства не пустые (чтобы не забекапить чужой спуфинг)
    if [ -n "$ORIG_NUMERIC" ] && [ "$SELECTED_CARRIER" -eq 0 ]; then
        cat << EOF > "$MODDIR/original_props"
ORIG_NUMERIC="$ORIG_NUMERIC"
ORIG_ISO="$ORIG_ISO"
EOF
    fi
fi

# --- Если выбран профиль 0 (Оригинал), то спуфинг пропускаем ---
if [ "$SELECTED_CARRIER" -eq 0 ]; then
    [ -f "$LOGFILE" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️ Выбран профиль 0 (Оригинал). Спуфинг пропущен." >> "$LOGFILE"
    exit 0
fi

# --- Проверяем, что SIM — российская ---
SOURCE_ISO="$(getprop gsm.sim.operator.iso-country 2>/dev/null)"
CHECK_ISO="$(echo "$SOURCE_ISO" | tr -d ' ' | tr -d ',' | cut -c1-2 | tr '[:upper:]' '[:lower:]')"

if [ "$CHECK_ISO" != "ru" ]; then
    [ -f "$LOGFILE" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️ Спуфинг не применен. SIM не российская (ISO: '$SOURCE_ISO')" >> "$LOGFILE"
    exit 0
fi

# --- Определяем целевые значения ---
case "$SELECTED_CARRIER" in
    1)
        TARGET_NUMERIC="24701"
        TARGET_ISO="lv"
        TARGET_NAME="🇱🇻 Latvijas Mobilais"
        ;;
    2)
        TARGET_NUMERIC="310094"
        TARGET_ISO="us"
        TARGET_NAME="🇺🇸 AT&T"
        ;;
    3)
        TARGET_NUMERIC="310260"
        TARGET_ISO="us"
        TARGET_NAME="🇺🇸 T-Mobile"
        ;;
esac

[ -n "$TARGET_NUMERIC" ] || exit 1
[ -n "$TARGET_ISO" ] || exit 1

[ -f "$LOGFILE" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] Обнаружена SIM 🇷🇺 ($SOURCE_ISO). Спуфинг запущен: 🇷🇺→$TARGET_NAME" >> "$LOGFILE"

# --- Подменяем свойства ---
resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
resetprop "gsm.operator.iso-country" "$TARGET_ISO"
resetprop "gsm.sim.operator.numeric" "$TARGET_NUMERIC"
resetprop "gsm.sim.operator.iso-country" "$TARGET_ISO"
resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"

resetprop "gsm.sim.operator.numeric.1" "$TARGET_NUMERIC"
resetprop "gsm.sim.operator.iso-country.1" "$TARGET_ISO"
resetprop "gsm.sim.operator.numeric.2" "$TARGET_NUMERIC"
resetprop "gsm.sim.operator.iso-country.2" "$TARGET_ISO"

[ -f "$LOGFILE" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Параметры $TARGET_NAME применены: numeric=$TARGET_NUMERIC iso=$TARGET_ISO" >> "$LOGFILE"
