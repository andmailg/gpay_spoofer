#!/system/bin/sh
# GPay Spoofer — service.sh

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="$MODDIR/Gpay-Spoofer.log"
LOCKFILE="/data/adb/gpay-spoofer.lock"
BIN_CACHE="$MODDIR/my_card.bin.cache"

if [ -e "$LOCKFILE" ]; then exit 0; fi
touch "$LOCKFILE" && trap 'rm -f "$LOCKFILE"' EXIT

timeout=30
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
    timeout=$((timeout - 1))
    if [ "$timeout" -le 0 ]; then break; fi
done
sleep 5

# --- Динамический бэкап оригинальных свойств ---
if [ ! -f "$MODDIR/original_props" ]; then
    ORIG_NUMERIC="$(getprop gsm.operator.numeric 2>/dev/null)"
    ORIG_ISO="$(getprop gsm.operator.iso-country 2>/dev/null)"
    
    if [ -n "$ORIG_NUMERIC" ] && [ -n "$ORIG_ISO" ]; then
        cat << EOF > "$MODDIR/original_props"
ORIG_NUMERIC="$ORIG_NUMERIC"
ORIG_ISO="$ORIG_ISO"
EOF
    fi
fi

# --- Определение целевого профиля с учетом кэша BIN ---
SELECTED_CARRIER=""

if [ -f "$BIN_CACHE" ]; then
    CACHED_ISO="$(cut -d':' -f2 "$BIN_CACHE" 2>/dev/null)"
    if [ -n "$CACHED_ISO" ] && [ -f "$CARRIERS_DB" ]; then
        MATCH_LINE="$(sed -n "/:${CACHED_ISO}:/p" "$CARRIERS_DB" | head -n 1)"
        if [ -n "$MATCH_LINE" ]; then
            SELECTED_CARRIER="$(echo "$MATCH_LINE" | cut -d':' -f1)"
        else
            SELECTED_CARRIER=1  # Дефолт на Латвию, если ISO карты потерялся в базе
        fi
    fi
fi

# Если кэша карты нет, берем ранее выбранный вручную профиль
if [ -z "$SELECTED_CARRIER" ]; then
    SELECTED_CARRIER="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"
fi

case "$SELECTED_CARRIER" in *[!0-9]*|"") SELECTED_CARRIER=0 ;; esac

if [ "$SELECTED_CARRIER" -eq 0 ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️ Профиль 0. Спуфинг отключен." >> "$LOGFILE" 2>/dev/null
    exit 0
fi

# --- Проверка SIM-карты (пропускаем только РФ) ---
SOURCE_ISO="$(getprop gsm.sim.operator.iso-country 2>/dev/null | tr -d ' ' | cut -c1-2 | tr '[:upper:]' '[:lower:]')"
if [ "$SOURCE_ISO" != "ru" ] && [ -n "$SOURCE_ISO" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️ Пропущен. SIM имеет ISO: '$SOURCE_ISO'" >> "$LOGFILE" 2>/dev/null
    exit 0
fi

# --- Извлечение данных оператора ---
TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_NAME=""

if [ -f "$CARRIERS_DB" ]; then
    LINE="$(sed -n "/^${SELECTED_CARRIER}:/p" "$CARRIERS_DB" | head -n 1)"
    if [ -n "$LINE" ]; then
        TARGET_NUMERIC=$(echo "$LINE" | cut -d':' -f2)
        TARGET_ISO=$(echo "$LINE" | cut -d':' -f3)
        TARGET_NAME=$(echo "$LINE" | cut -d':' -f4)
    fi
fi

[ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ] && exit 1

# --- Применение подмены ---
for suffix in "" ".1" ".2"; do
    resetprop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
    resetprop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
done
resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
resetprop "gsm.operator.iso-country" "$TARGET_ISO"
resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Спуфинг успешно активирован: $TARGET_NAME ($TARGET_ISO)" >> "$LOGFILE" 2>/dev/null
