#!/system/bin/sh

# ============================================================
# GPay Spoofer — service.sh
# Запускается Magisk после загрузки.
# Подменяет свойства оператора только при обнаружении русской SIM.
# ============================================================

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
LOGFILE="/sdcard/gpay-spoofer.log"
LOCKFILE="/data/adb/gpay-spoofer.lock"

# --- Функция логирования ---
log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

# --- Блокировка: не запускать два экземпляра ---
if [ -e "$LOCKFILE" ]; then
    exit 0
fi

touch "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# --- Ждём завершения загрузки Android ---
timeout=60
elapsed=0

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
    elapsed=$((elapsed + 2))

    if [ "$elapsed" -ge "$timeout" ]; then
        break
    fi
done

# --- Даём telephony и SD-карте время инициализироваться ---
sleep 15

# --- Читаем выбранный профиль ---
SELECTED_CARRIER="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"

case "$SELECTED_CARRIER" in
    0|1|2|3) ;;
    *) SELECTED_CARRIER=0 ;;
esac

# --- Проверяем, что SIM — российская ---
SOURCE_ISO="$(getprop gsm.sim.operator.iso-country 2>/dev/null)"
CHECK_ISO="$(echo "$SOURCE_ISO" | tr -d ',' | tr -d ' ')"

if [ "$CHECK_ISO" != "ru" ] && [ "$CHECK_ISO" != "RU" ]; then
    log_msg "SIM не российская (ISO=$SOURCE_ISO). Подмена пропущена."
    exit 0
fi

# --- Определяем целевые значения ---
case "$SELECTED_CARRIER" in
    0)
        TARGET_ALPHA="Latvijas Mobilais"
        TARGET_NUMERIC="24701"
        TARGET_ISO="lv"
        TARGET_NAME="Latvijas Mobilais (Latvia)"
        ;;
    1)
        TARGET_ALPHA="ATT"
        TARGET_NUMERIC="310094"
        TARGET_ISO="us"
        TARGET_NAME="AT&T (USA)"
        ;;
    2)
        TARGET_ALPHA="T-Mobile"
        TARGET_NUMERIC="310260"
        TARGET_ISO="us"
        TARGET_NAME="T-Mobile (USA)"
        ;;
esac

# --- Проверяем, что все переменные определены ---
[ -n "$TARGET_ALPHA" ] || exit 1
[ -n "$TARGET_NUMERIC" ] || exit 1
[ -n "$TARGET_ISO" ] || exit 1

# --- Сохраняем оригинальные значения для uninstall ---
ORIG_ALPHA="$(getprop gsm.operator.alpha 2>/dev/null)"
ORIG_NUMERIC="$(getprop gsm.operator.numeric 2>/dev/null)"
ORIG_ISO="$(getprop gsm.operator.iso-country 2>/dev/null)"

# --- Подменяем свойства ---
resetprop "gsm.operator.alpha" "$TARGET_ALPHA"
resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
resetprop "gsm.operator.iso-country" "$TARGET_ISO"
resetprop "gsm.sim.operator.alpha" "$TARGET_ALPHA"
resetprop "gsm.sim.operator.numeric" "$TARGET_NUMERIC"
resetprop "gsm.sim.operator.iso-country" "$TARGET_ISO"
resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"

# --- Мульти-SIM слоты ---
resetprop "gsm.sim.operator.numeric.1" "$TARGET_NUMERIC"
resetprop "gsm.sim.operator.iso-country.1" "$TARGET_ISO"
resetprop "gsm.sim.operator.numeric.2" "$TARGET_NUMERIC"
resetprop "gsm.sim.operator.iso-country.2" "$TARGET_ISO"

log_msg "Подмена выполнена: $TARGET_NAME (selected=$SELECTED_CARRIER)"
log_msg "Оригинал: alpha=$ORIG_ALPHA numeric=$ORIG_NUMERIC iso=$ORIG_ISO"
