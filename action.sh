#!/system/bin/sh
# GPay Spoofer — action.sh (Циклическое переключение профилей с логированием)

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="/sdcard/Gpay-Spoofer.log"

# --- Функция безопасного логирования ---
log_msg() {
    if [ -d "/sdcard" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ACTION] $1" >> "$LOGFILE" 2>/dev/null
    fi
}

# Считаем количество операторов в базе данных для вычисления лимита цикла
TOTAL_CARRIERS=0
if [ -f "$CARRIERS_DB" ]; then
    TOTAL_CARRIERS=$(sed '/^[[:space:]]*$/d' "$CARRIERS_DB" 2>/dev/null | wc -l | tr -d '[:space:]')
fi
case "$TOTAL_CARRIERS" in ''|*[!0-9]*) TOTAL_CARRIERS=0 ;; esac
TOTAL_STATES=$((TOTAL_CARRIERS + 1))

# Читаем текущий активный профиль
CURRENT="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"
case "$CURRENT" in *[!0-9]*|"") CURRENT=0 ;; esac

# Переключаем профиль на один шаг вперёд по кругу
NEW_CARRIER=$(( (CURRENT + 1) % TOTAL_STATES ))

# Запись нового состояния
echo "selected_carrier=$NEW_CARRIER" > "$SETTINGS"
chmod 0600 "$SETTINGS"

TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_NAME=""

if [ "$NEW_CARRIER" -eq 0 ]; then
    TARGET_NAME="Оригинальные значения (Спуфинг ОТКЛЮЧЕН)"
else
    if [ -f "$CARRIERS_DB" ]; then
        LINE="$(sed -n "/^${NEW_CARRIER}:/p" "$CARRIERS_DB" | head -n 1)"
        if [ -n "$LINE" ]; then
            TARGET_NUMERIC=$(echo "$LINE" | cut -d':' -f2)
            TARGET_ISO=$(echo "$LINE" | cut -d':' -f3)
            TARGET_NAME=$(echo "$LINE" | cut -d':' -f4)
        fi
    fi
fi

# Мгновенно применяем новые пропсы через resetprop
if [ -n "$TARGET_NUMERIC" ] && [ -n "$TARGET_ISO" ]; then
    for suffix in "" ".1" ".2"; do
        resetprop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
        resetprop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
    done
    resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
    resetprop "gsm.operator.iso-country" "$TARGET_ISO"
fi

# Уведомление в консоль менеджера Magisk
echo "=================================================="
echo "          GPAY SPOOFER CONFIGURATOR               "
echo "=================================================="
echo " Направление: Циклическое переключение"
echo " Применён профиль: [$NEW_CARRIER] $TARGET_NAME"
echo "=================================================="
echo "Обновляю конфигурацию сервисов Google..."

# Сброс процессов для применения региона Wallet без перезагрузки смартфона
am force-stop com.android.vending >/dev/null 2>&1
am force-stop com.google.android.apps.walletnfcrel >/dev/null 2>&1
pm trim-caches 999G >/dev/null 2>&1

echo "✅ Готово! Настройки успешно обновлены."
echo "=================================================="

log_msg "Ручное переключение профиля: [$NEW_CARRIER] $TARGET_NAME"
