#!/system/bin/sh

# ============================================================
# GPay Spoofer — service.sh
# ============================================================

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="/sdcard/Gpay-Spoofer.log"
LOCKFILE="/data/adb/gpay-spoofer.lock"

if [ -e "$LOCKFILE" ]; then
    exit 0
fi

touch "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

IS_BOOTED="$(getprop sys.boot_completed)"

if [ "$IS_BOOTED" != "1" ]; then
    timeout=30
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 2
        timeout=$((timeout - 1))
        if [ "$timeout" -le 0 ]; then break; fi
    done
    sleep 10
else
    sleep 1
fi

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
    *[!0-9]*|"") SELECTED_CARRIER=0 ;;
esac

# --- Сохраняем оригинальные значения (только если файла еще нет) ---
if [ ! -f "$MODDIR/original_props" ] || [ "$SELECTED_CARRIER" -eq 0 ]; then
    ORIG_NUMERIC="$(getprop gsm.operator.numeric 2>/dev/null)"
    ORIG_ISO="$(getprop gsm.operator.iso-country 2>/dev/null)"
    
    if [ -n "$ORIG_NUMERIC" ] && [ "$SELECTED_CARRIER" -eq 0 ]; then
        cat << EOF > "$MODDIR/original_props"
ORIG_NUMERIC="$ORIG_NUMERIC"
ORIG_ISO="$ORIG_ISO"
EOF
    fi
fi

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

# --- Парсинг целевых значений из базы данных carriers.db ---
TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_NAME=""

if [ -f "$CARRIERS_DB" ]; then
    LINE="$(sed -n "/^${SELECTED_CARRIER}:/p" "$CARRIERS_DB" | head -n 1)"
    if [ -n "$LINE" ]; then
        IFS=":" read -r _ TARGET_NUMERIC TARGET_ISO TARGET_NAME << EOF
$LINE
EOF
    fi
fi

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
