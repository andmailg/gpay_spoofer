#!/system/bin/sh
# GPay Spoofer — service.sh (Динамическая версия)

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="$MODDIR/Gpay-Spoofer.log"
PROPS_FILE="$MODDIR/original_props"

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

# --- Динамический бэкап чистых свойств (Выполняется строго до подмены) ---
CURRENT_SYSTEM_NUMERIC="$(getprop gsm.operator.numeric)"
CURRENT_SYSTEM_ISO="$(getprop gsm.sim.operator.iso-country)"
CURRENT_SYSTEM_CDMA="$(getprop ro.cdma.home.operator.numeric)"

if [ -n "$CURRENT_SYSTEM_NUMERIC" ] && [ -n "$CURRENT_SYSTEM_ISO" ]; then
    LAST_SAVED_CARRIER="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"
    case "$LAST_SAVED_CARRIER" in *[!0-9]*|"") LAST_SAVED_CARRIER=0 ;; esac
    
    # Обновляем оригинал, только если спуфинг спал ИЛИ файла бэкапа физически еще нет
    if [ "$LAST_SAVED_CARRIER" -eq 0 ] || [ ! -f "$PROPS_FILE" ]; then
        echo "ORIG_NUMERIC=\"$CURRENT_SYSTEM_NUMERIC\"" > "$PROPS_FILE"
        echo "ORIG_ISO=\"$CURRENT_SYSTEM_ISO\"" >> "$PROPS_FILE"
        echo "ORIG_CDMA=\"$CURRENT_SYSTEM_CDMA\"" >> "$PROPS_FILE"
        chmod 0600 "$PROPS_FILE"
        log_msg "🔄 Свойства SIM изменились или обновлены. Бэкап актуализирован."
    fi
fi

# Чтение текущего выбора профиля
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
