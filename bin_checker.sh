#!/system/bin/sh
MODDIR="${0%/*}"
[ "$MODDIR" = "." ] || [ -z "$MODDIR" ] && MODDIR="/data/adb/modules/GPay-Spoofer"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
PROPS_FILE="$MODDIR/original_props"

_set_prop() {
    if command -v resetprop >/dev/null 2>&1; then
        resetprop "$1" "$2"
    elif [ -x /data/adb/ap/bin/kpcli ]; then
        /data/adb/ap/bin/kpcli property set "$1" "$2"
    elif [ -x /data/adb/ksu/bin/kpcli ]; then
        /data/adb/ksu/bin/kpcli property set "$1" "$2"
    elif command -v kpcli >/dev/null 2>&1; then
        kpcli property set "$1" "$2"
    else
        setprop "$1" "$2"
    fi
}

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Ошибка: Нужны права root!"
    exit 1
fi

if [ ! -f "$CARRIERS_DB" ]; then
    echo "❌ Ошибка: База данных не найдена!"
    exit 1
fi

printf "\033[H\033[J"
echo "=== GPAY SPOOFER ==="
printf "Введите первые 6-8 цифр карты: "
read -r USER_INPUT

USER_BIN=$(echo "$USER_INPUT" | tr -d ' \t-')
case "$USER_BIN" in
    *[!0-9]* | "")
        echo "❌ Ошибка: Только цифры!"
        exit 1
        ;;
    [0-9]|[0-9][0-9]|[0-9][0-9][0-9]|[0-9][0-9][0-9][0-9]|[0-9][0-9][0-9][0-9][0-9])
        echo "❌ Ошибка: Минимум 6 цифр!"
        exit 1
        ;;
esac

BIN_8=$(echo "$USER_BIN" | cut -c1-8)
API_URL="https://data.handyapi.com/bin/$BIN_8"

RESPONSE=""
if command -v curl >/dev/null 2>&1; then
    RESPONSE=$(curl -fsSL --connect-timeout 5 --max-time 10 "$API_URL" 2>/dev/null)
elif command -v wget >/dev/null 2>&1; then
    RESPONSE=$(wget -qO- --timeout=10 "$API_URL" 2>/dev/null)
fi

if [ -z "$RESPONSE" ]; then
    echo "❌ Ошибка сети."
    exit 1
fi

# Очистка JSON от кавычек и пробелов
CLEAN_RESP=$(echo "$RESPONSE" | tr -d ' \t\n\r"')

TARGET_ISO=""
case "$CLEAN_RESP" in
    *A2:??*)
        TMP_ISO="${CLEAN_RESP#*A2:}"
        TARGET_ISO=$(echo "$TMP_ISO" | cut -c1-2 | tr '[:upper:]' '[:lower:]')
        ;;
esac

if [ -z "$TARGET_ISO" ]; then
    echo "❌ Регион не найден в ответе API."
    exit 1
fi

# Читаем активный режим из настроек
CURRENT_CARRIER=$(grep '^selected_carrier=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1 | tr -d '\r ')
case "$CURRENT_CARRIER" in *[!0-9]*|"") CURRENT_CARRIER=0 ;; esac

NEW_ID=""
TARGET_NUMERIC=""
TARGET_NAME=""

# Поиск соответствия региона карты в базе данных
_match=$(grep ":${TARGET_ISO}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
if [ -n "$_match" ]; then
    NEW_ID=$(echo "$_match" | cut -d':' -f1)
    TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2)
    TARGET_NAME=$(echo "$_match" | cut -d':' -f4)
else
    # Откат на Авто (ID=0), если БИН карты принадлежит региону, которого нет в базе
    echo "⚠️ Регион карты [$TARGET_ISO] не поддерживается базой данных."
    NEW_ID=0
    TARGET_NAME="Оригинальные значения (Спуфинг отключен)"
    
    if [ -f "$PROPS_FILE" ]; then
        TARGET_ISO=$(grep '^ORIG_ISO=' "$PROPS_FILE" | cut -d'"' -f2 | tr -d '\r ')
        TARGET_NUMERIC=$(grep '^ORIG_NUMERIC=' "$PROPS_FILE" | cut -d'"' -f2 | tr -d '\r ')
    else
        TARGET_ISO=$(getprop gsm.sim.operator.iso-country | cut -d',' -f1)
        TARGET_NUMERIC=$(getprop gsm.operator.numeric | cut -d',' -f1)
    fi
fi

# =========================================================================
# ИНТЕРАКТИВНАЯ ПРОВЕРКА СТАТИЧЕСКОГО РЕЖИМА
# =========================================================================
if [ "$CURRENT_CARRIER" -ne 0 ] && [ "$NEW_ID" -ne 0 ]; then
    echo "📍 Найдена карта региона: [$TARGET_ISO] ($TARGET_NAME)"
    echo "⚠️ Сейчас у вас принудительно зафиксирован статический профиль [$CURRENT_CARRIER]."
    printf "Включить режим 'Авто' для динамической подмены под эту карту? [y/n] (д/н): "
    read -r USER_CHOICE
    
    # Приведение ответа к нижнему регистру
    USER_CHOICE=$(echo "$USER_CHOICE" | tr '[:upper:]' '[:lower:]')
    
    case "$USER_CHOICE" in
        y | yes | д | да)
            # Переключаем сессию в режим Авто
            CURRENT_CARRIER=0
            echo "🤖 Переключаюсь в режим Авто..."
            ;;
        *)
            # Отказ: выводим текущие значения статического профиля и завершаем работу
            _static_match=$(grep "^${CURRENT_CARRIER}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
            if [ -n "$_static_match" ]; then
                _st_iso=$(echo "$_static_match" | cut -d':' -f3)
                _st_name=$(echo "$_static_match" | cut -d':' -f4)
                echo "ℹ️ Действие отменено. Сохраняется профиль [$CURRENT_CARRIER] ${_st_name} (${_st_iso})."
            else
                echo "ℹ️ Действие отменено. Активен неизвестный профиль [$CURRENT_CARRIER]."
            fi
            exit 0
            ;;
    esac
fi

# =========================================================================
# СОХРАНЕНИЕ НАСТРОЕК В SETTINGS
# =========================================================================
if [ "$CURRENT_CARRIER" -eq 0 ] || [ "$NEW_ID" -eq 0 ]; then
    # Если мы изначально в Авто (0), переключились на Авто (0) или ушли в откат (NEW_ID = 0)
    _actual_carrier="$CURRENT_CARRIER"
    [ "$NEW_ID" -eq 0 ] && _actual_carrier=0

    printf "selected_carrier=%s\nlast_searched_iso=%s\n" "$_actual_carrier" "$TARGET_ISO" > "$SETTINGS"
    echo "📝 Настройки обновлены. Авто-режим нацелен на регион [$TARGET_ISO]."
else
    # Если статика активна и пользователь отказался от Авто (сюда попадем только при NEW_ID=0/откатах региона карты)
    _current_iso_stored=$(grep '^last_searched_iso=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1 | tr -d '\r ')
    printf "selected_carrier=%s\nlast_searched_iso=%s\n" "$CURRENT_CARRIER" "$_current_iso_stored" > "$SETTINGS"
    
    # Подгружаем параметры жесткого профиля для сессии
    _static_match=$(grep "^${CURRENT_CARRIER}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
    if [ -n "$_static_match" ]; then
        TARGET_NUMERIC=$(echo "$_static_match" | cut -d':' -f2)
        TARGET_ISO=$(echo "$_static_match" | cut -d':' -f3)
        TARGET_NAME=$(echo "$_static_match" | cut -d':' -f4)
    fi
fi
chmod 0600 "$SETTINGS"

# =========================================================================
# ПРИМЕНЕНИЕ И ПЕРЕЗАПУСК Google
# =========================================================================
if [ -n "$TARGET_NUMERIC" ] && [ -n "$TARGET_ISO" ]; then
    _set_prop "gsm.sim.operator.numeric" "${TARGET_NUMERIC}"
    _set_prop "gsm.sim.operator.iso-country" "${TARGET_ISO}"
    _set_prop "gsm.operator.iso-country" "${TARGET_ISO}"
fi

(
    am force-stop com.android.vending
    am force-stop com.google.android.apps.walletnfcrel
    pm trim-caches 999G
) >/dev/null 2>&1 &

echo "Google сервисы перезапущены в фоне."
if [ "$CURRENT_CARRIER" -eq 0 ] && [ "$NEW_ID" -ne 0 ]; then
    echo "🚀 [Авто-режим] Динамически применен профиль: $TARGET_NAME ($TARGET_ISO)"
elif [ "$NEW_ID" -eq 0 ]; then
    echo "🚀 [Откат на Авто] Спуфинг отключен. Применены родные пропсы оператора ($TARGET_ISO)."
else
    echo "🚀 [Статика] Конфигурация сохранена без изменений. Активен: $TARGET_NAME"
fi
