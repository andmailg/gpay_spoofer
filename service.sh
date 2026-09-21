#!/system/bin/sh
# GPay Spoofer — service.sh (Применение спуфинга при загрузке с проверкой SIM РФ)

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="/sdcard/Gpay-Spoofer.log"

# --- Функция безопасного логирования ---
log_msg() {
    if [ -d "/sdcard" ]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SERVICE] $1" >> "$LOGFILE" 2>/dev/null
    fi
}

# --- Ожидание завершения загрузки системы Android ---
timeout=20
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
    timeout=$((timeout - 1))
    [ "$timeout" -le 0 ] && break
done

# Дополнительное ожидание для стабилизации радиомодуля и монтирования /sdcard
sleep 3

# --- Умная проверка региона SIM-карт ---
# Получаем сырую строку (например: "ru", "ru,ru", "ru,", ",ru")
RAW_ISO="$(getprop gsm.sim.operator.iso-country 2>/dev/null | tr -d ' ' | tr '[:upper:]' '[:lower:]')"

# Если в строке вообще нет "ru", но при этом она не пустая — значит SIM точно иностранная
case "$RAW_ISO" in
    *ru*) 
        # Найдена российская SIM (в любом слоте) — продолжаем работу
        ;;
    "") 
        # SIM-карта отсутствует или еще не инициализировалась — 
        # разрешаем спуфинг на всякий случай (например, для планшетов без SIM)
        ;;
    *) 
        # В строке есть символы, но нет "ru" (например: "kz", "us,") — это иностранная SIM
        log_msg "Пропущен. Обнаружена иностранная SIM: '$RAW_ISO'. Спуфинг отключен."
        exit 0
        ;;
esac

# Чтение ранее выбранного профиля из настроек
SELECTED_CARRIER="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"
case "$SELECTED_CARRIER" in *[!0-9]*|"") SELECTED_CARRIER=0 ;; esac

# Если выбран профиль 0, то спуфинг отключен пользователем вручную
if [ "$SELECTED_CARRIER" -eq 0 ]; then
    log_msg "Профиль 0. Спуфинг отключен пользователем, оригинальные свойства сохранены."
    exit 0
fi

# Извлечение данных оператора из расширенной текстовой базы данных
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

# Прерываем работу, если данные для подмены не найдены в базе
if [ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ]; then
    log_msg "❌ Ошибка: Не удалось найти данные для профиля [$SELECTED_CARRIER] в carriers.db"
    exit 1
fi

# Применение подмены сотовых свойств через resetprop
for suffix in "" ".1" ".2"; do
    resetprop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
    resetprop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
done
resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
resetprop "gsm.operator.iso-country" "$TARGET_ISO"

log_msg "✅ Спуфинг успешно активирован для РФ SIM: профиль [$SELECTED_CARRIER] $TARGET_NAME ($TARGET_ISO)"
