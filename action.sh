#!/system/bin/sh
# GPay Spoofer — action.sh (Версия с выводом оригинальных свойств)

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="$MODDIR/Gpay-Spoofer.log"
PROPS_FILE="$MODDIR/original_props"

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ACTION] $1" >> "$LOGFILE" 2>/dev/null
}

TOTAL_CARRIERS=0
if [ -f "$CARRIERS_DB" ]; then
    TOTAL_CARRIERS=$(sed '/^[[:space:]]*$/d' "$CARRIERS_DB" 2>/dev/null | wc -l | tr -d '[:space:]')
fi
case "$TOTAL_CARRIERS" in ''|*[!0-9]*) TOTAL_CARRIERS=0 ;; esac
TOTAL_STATES=$((TOTAL_CARRIERS + 1))

CURRENT="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"
case "$CURRENT" in *[!0-9]*|"") CURRENT=0 ;; esac

NEW_CARRIER=$(( (CURRENT + 1) % TOTAL_STATES ))

echo "selected_carrier=$NEW_CARRIER" > "$SETTINGS"
chmod 0600 "$SETTINGS"

TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_NAME=""

# Читаем оригинальные свойства для вывода в консоль
# shellcheck disable=SC1090
if [ -f "$PROPS_FILE" ]; then
    . "$PROPS_FILE"
else
    ORIG_NUMERIC="Неизвестно"
    ORIG_ISO="Неизвестно"
    ORIG_CDMA="Неизвестно"
fi

if [ "$NEW_CARRIER" -eq 0 ]; then
    TARGET_NAME="Оригинальные значения (Спуфинг ОТКЛЮЧЕН)"
    TARGET_NUMERIC="$ORIG_NUMERIC"
    TARGET_ISO="$ORIG_ISO"
else
    if [ -f "$CARRIERS_DB" ]; then
        while IFS=":" read -r id numeric iso name; do
            if [ "$id" = "$NEW_CARRIER" ]; then
                TARGET_NUMERIC="$numeric"
                TARGET_ISO="$iso"
                TARGET_NAME="$name"
                break
            fi
        done < "$CARRIERS_DB"
    fi
fi

# Мгновенное применение новых пропсов (Dual-SIM + CDMA)
if [ -n "$TARGET_NUMERIC" ] && [ -n "$TARGET_ISO" ] && [ "$TARGET_NUMERIC" != "Неизвестно" ]; then
    for suffix in "" ".1" ".2"; do
        resetprop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
        resetprop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
        resetprop "gsm.operator.numeric$suffix" "$TARGET_NUMERIC"
        resetprop "gsm.operator.iso-country$suffix" "$TARGET_ISO"
    done
    
    if [ "$NEW_CARRIER" -eq 0 ]; then
        resetprop "ro.cdma.home.operator.numeric" "$ORIG_CDMA"
    else
        resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"
    fi
fi

# Уведомление в консоль менеджера Magisk/KernelSU
echo "=================================================="
echo "          GPAY SPOOFER CONFIGURATOR               "
echo "=================================================="
echo " Направление  : Циклическое переключение"
echo " Заводская SIM: MCCMNC='$ORIG_NUMERIC' | ISO='$(echo "$ORIG_ISO" | tr '[:lower:]' '[:upper:]')'"
echo "--------------------------------------------------"
echo " ПРИМЕНЁН ПРОФИЛЬ: [$NEW_CARRIER] $TARGET_NAME"
echo "=================================================="
echo "Обновляю конфигурацию сервисов Google..."

am force-stop com.android.vending >/dev/null 2>&1
am force-stop com.google.android.apps.walletnfcrel >/dev/null 2>&1
pm trim-caches 999G >/dev/null 2>&1

echo "✅ Готово! Настройки успешно обновлены."
echo "=================================================="

log_msg "Ручное переключение профиля: [$NEW_CARRIER] $TARGET_NAME"
