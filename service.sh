#!/system/bin/sh
# GPay Spoofer — service.sh (Финальная версия)

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="$MODDIR/Gpay-Spoofer.log"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SERVICE] $1" >> "$LOGFILE" 2>/dev/null
}

# --- Ожидание завершения загрузки системы Android ---
timeout=30
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
    timeout=$((timeout - 1))
    [ "$timeout" -le 0 ] && break
done

# --- Проверка региона SIM-карт ---
RAW_ISO="$(getprop gsm.sim.operator.iso-country 2>/dev/null | tr -d ' ' | tr '[:upper:]' '[:lower:]')"

case "$RAW_ISO" in
    *ru* | *by*)
        # Найдена целевая SIM — продолжаем
        ;;
    "")
        # SIM отсутствует (разрешаем работу по Wi-Fi)
        ;;
    *)
        log_msg "Пропущен. Найдена иностранная SIM в системе: '$RAW_ISO'."
        exit 0
        ;;
esac

# Чтение выбранного профиля
SELECTED_CARRIER="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"
case "$SELECTED_CARRIER" in *[!0-9]*|"") SELECTED_CARRIER=0 ;; esac

if [ "$SELECTED_CARRIER" -eq 0 ]; then
    exit 0
fi

TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_NAME=""

if [ -f "$CARRIERS_DB" ]; then
    while IFS=":" read -r id numeric iso name; do
        if [ "$id" = "$SELECTED_CARRIER" ]; then
            TARGET_NUMERIC="$numeric"
            TARGET_ISO="$iso"
            TARGET_NAME="$name"
            break
        fi
    done < "$CARRIERS_DB"
fi

if [ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ]; then
    log_msg "❌ Ошибка: Не нашли профиль [$SELECTED_CARRIER] в carriers.db"
    exit 1
fi

# Применение подмены сотовых свойств (Полный Dual-SIM охват + CDMA)
for suffix in "" ".1" ".2"; do
    resetprop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
    resetprop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
    resetprop "gsm.operator.numeric$suffix" "$TARGET_NUMERIC"
    resetprop "gsm.operator.iso-country$suffix" "$TARGET_ISO"
done
resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"

log_msg "✅ Спуфинг успешно активирован: профиль [$SELECTED_CARRIER] $TARGET_NAME ($TARGET_ISO)"
