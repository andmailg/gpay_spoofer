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

# Ожидание загрузки системы
timeout=30
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
    timeout=$((timeout - 1))
    if [ "$timeout" -le 0 ]; then break; fi
done
sleep 5

# Ожидание доступности хранилища для логов
storage_timeout=20
while [ ! -d "/sdcard/Android" ]; do
    sleep 2
    storage_timeout=$((storage_timeout - 1))
    if [ "$storage_timeout" -le 0 ]; then break; fi
done

if [ -d "/sdcard" ] && [ ! -f "$LOGFILE" ]; then
    touch "$LOGFILE" 2>/dev/null
fi

# --- СОЗДАНИЕ БЭКАПА (Строго один раз при первом старте модуля) ---
if [ ! -f "$MODDIR/original_props" ]; then
    ORIG_NUMERIC="$(getprop gsm.operator.numeric 2>/dev/null)"
    ORIG_ISO="$(getprop gsm.operator.iso-country 2>/dev/null)"
    
    # Если система вернула пустые значения во время бута, берем безопасный фоллбэк РФ
    [ -z "$ORIG_NUMERIC" ] && ORIG_NUMERIC="25001"
    [ -z "$ORIG_ISO" ] && ORIG_ISO="ru"

    cat << EOF > "$MODDIR/original_props"
ORIG_NUMERIC="$ORIG_NUMERIC"
ORIG_ISO="$ORIG_ISO"
EOF
fi

# --- Читаем сохраненный профиль ---
SELECTED_CARRIER="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"
case "$SELECTED_CARRIER" in
    *[!0-9]*|"") SELECTED_CARRIER=0 ;;
esac

if [ "$SELECTED_CARRIER" -eq 0 ]; then
    [ -f "$LOGFILE" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️ Профиль 0. Спуфинг отключен." >> "$LOGFILE"
    exit 0
fi

# --- Проверяем, что текущая SIM действительно российская ---
SOURCE_ISO="$(getprop gsm.sim.operator.iso-country 2>/dev/null | tr -d ' ' | cut -c1-2 | tr '[:upper:]' '[:lower:]')"
if [ "$SOURCE_ISO" != "ru" ] && [ -n "$SOURCE_ISO" ]; then
    [ -f "$LOGFILE" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ℹ️ Пропущен. SIM имеет ISO: '$SOURCE_ISO'" >> "$LOGFILE"
    exit 0
fi

# --- Получаем таргет-данные оператора ---
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

[ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ] && exit 1

# --- Применяем подмену ---
for suffix in "" ".1" ".2"; do
    resetprop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
    resetprop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
done
resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
resetprop "gsm.operator.iso-country" "$TARGET_ISO"
resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"

[ -f "$LOGFILE" ] && echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Спуфинг успешно активирован: $TARGET_NAME ($TARGET_ISO)" >> "$LOGFILE"
