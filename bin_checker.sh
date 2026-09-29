#!/system/bin/sh
# shellcheck shell=sh
# GPay-Spoofer: bin_checker.sh (подбор профиля по BIN карты)

case "$0" in
    */*) MODDIR="${0%/*}" ;;
    *)   MODDIR="$(pwd)" ;;
esac
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
PROPS_FILE="$MODDIR/original_props"
SUFFIX=","   # должен совпадать со значением в service.sh и action.sh

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

get_setting() {
    grep "^$1=" "$SETTINGS" 2>/dev/null | head -n 1 | cut -d'=' -f2- | tr -d '\r '
}

_orig() {
    grep "^$1=" "$PROPS_FILE" 2>/dev/null | head -n 1 | cut -d'"' -f2 | tr -d '\r'
}

# restore <prop> <ключ бэкапа>
restore() {
    _v=$(_orig "$2")
    if [ -n "$_v" ]; then
        _set_prop "$1" "${_v}${SUFFIX}"
        RESTORED=$((RESTORED + 1))
    fi
}

# Пишет settings, сохраняя прочие ключи
write_settings() {
    {
        grep -v -e '^selected_carrier=' -e '^last_searched_iso=' "$SETTINGS" 2>/dev/null
        printf "selected_carrier=%s\nlast_searched_iso=%s\n" "$1" "$2"
    } > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
    chmod 0600 "$SETTINGS" 2>/dev/null
}

restart_google() {
    (
        am force-stop com.android.vending
        am force-stop com.google.android.apps.walletnfcrel
    ) >/dev/null 2>&1 &
    echo "Google сервисы перезапущены в фоне."
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
echo "Вводите только первые 6-8 цифр карты, не весь номер."
printf "Первые 6-8 цифр карты: "
read -r USER_INPUT

USER_BIN=$(echo "$USER_INPUT" | tr -d ' \t-')
USER_INPUT=""
case "$USER_BIN" in
    *[!0-9]* | "") echo "❌ Ошибка: Только цифры!"; exit 1 ;;
    [0-9]|[0-9][0-9]|[0-9][0-9][0-9]|[0-9][0-9][0-9][0-9]|[0-9][0-9][0-9][0-9][0-9])
        echo "❌ Ошибка: Минимум 6 цифр!"; exit 1 ;;
esac

BIN_8=$(echo "$USER_BIN" | cut -c1-8)
USER_BIN=""
API_URL="https://data.handyapi.com/bin/$BIN_8"

# ---------- Запрос к API ----------
RESPONSE=""
HTTP_CODE=""
if command -v curl >/dev/null 2>&1; then
    _out=$(curl -sL --connect-timeout 5 --max-time 10 -w '\n%{http_code}' "$API_URL" 2>/dev/null)
    _rc=$?
    HTTP_CODE=$(echo "$_out" | tail -n 1 | tr -d '\r ')
    RESPONSE=$(echo "$_out" | sed '$d')
elif command -v wget >/dev/null 2>&1; then
    RESPONSE=$(wget -T 10 -qO- "$API_URL" 2>/dev/null)
    _rc=$?
else
    echo "❌ Не найден ни curl, ни wget."
    exit 1
fi

if [ "$_rc" -ne 0 ]; then
    echo "❌ Ошибка сети (или HTTPS недоступен в этой утилите)."
    exit 1
fi
case "$HTTP_CODE" in
    "" | 2??) ;;
    404) echo "❌ BIN не найден в базе API."; exit 1 ;;
    *)   echo "❌ API вернул ошибку HTTP $HTTP_CODE."; exit 1 ;;
esac
if [ -z "$RESPONSE" ]; then
    echo "❌ Пустой ответ API."
    exit 1
fi

# ---------- Страна из ответа ----------
CLEAN_RESP=$(echo "$RESPONSE" | tr -d ' \t\n\r"')
CARD_ISO=""
case "$CLEAN_RESP" in
    *A2:??*)
        _tmp="${CLEAN_RESP#*A2:}"
        CARD_ISO=$(echo "$_tmp" | cut -c1-2 | tr '[:upper:]' '[:lower:]')
        ;;
esac
if [ -z "$CARD_ISO" ]; then
    echo "❌ Регион не найден в ответе API."
    exit 1
fi
CARD_ISO_UP=$(echo "$CARD_ISO" | tr '[:lower:]' '[:upper:]')

CURRENT_CARRIER=$(get_setting selected_carrier)
case "$CURRENT_CARRIER" in *[!0-9]*|"") CURRENT_CARRIER=0 ;; esac

# ---------- Поиск региона в базе (точное совпадение по ISO) ----------
_match=$(awk -F: -v i="$CARD_ISO" '{ gsub(/\r/, "") } tolower($3)==i { print; exit }' "$CARRIERS_DB")

RESTORED=0

if [ -z "$_match" ]; then
    # ---------- Регион не поддерживается ----------
    echo "⚠️ Регион карты [$CARD_ISO_UP] не поддерживается базой данных."

    if [ "$CURRENT_CARRIER" -ne 0 ]; then
        echo "ℹ️ Активен статический профиль [$CURRENT_CARRIER]. Настройки не изменены."
        exit 0
    fi

    # Авто-режим: отключаем спуфинг и возвращаем родные значения
    write_settings 0 ""
    restore gsm.sim.operator.alpha       ORIG_ALPHA
    restore gsm.operator.alpha           ORIG_OPERATOR_ALPHA
    restore gsm.sim.operator.numeric     ORIG_SIM_NUMERIC
    restore gsm.operator.numeric         ORIG_NUMERIC
    restore gsm.sim.operator.iso-country ORIG_ISO
    restore gsm.operator.iso-country     ORIG_OPERATOR_ISO

    restart_google
    if [ "$RESTORED" -gt 0 ]; then
        echo "🚀 [Откат на Авто] Спуфинг отключён, восстановлено свойств: $RESTORED."
    else
        echo "🚀 [Откат на Авто] Спуфинг отключён. Бэкап пуст, родные значения вернутся после перезагрузки."
    fi
    exit 0
fi

# ---------- Регион найден ----------
NEW_ID=$(echo "$_match" | cut -d':' -f1)
TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2)
TARGET_ISO=$(echo "$_match" | cut -d':' -f3 | tr '[:upper:]' '[:lower:]')
TARGET_ALPHA=$(echo "$_match" | cut -d':' -f4)
TARGET_NAME="${TARGET_ALPHA} ($CARD_ISO_UP)"

if [ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ]; then
    echo "❌ Запись [$NEW_ID] в базе повреждена. Настройки не изменены."
    exit 1
fi

if [ "$CURRENT_CARRIER" -ne 0 ]; then
    echo "📍 Найдена карта региона: [$CARD_ISO_UP] ($TARGET_NAME)"
    echo "⚠️ Сейчас зафиксирован статический профиль [$CURRENT_CARRIER]."
    printf "Включить режим 'Авто' для подмены под эту карту? [y/n] (д/н): "
    read -r USER_CHOICE
    USER_CHOICE=$(echo "$USER_CHOICE" | tr '[:upper:]' '[:lower:]')
    case "$USER_CHOICE" in
        y | yes | д | да)
            echo "🤖 Переключаюсь в режим Авто..."
            ;;
        *)
            _cur_row=$(awk -F: -v i="$CURRENT_CARRIER" '{ gsub(/\r/, "") } $1==i { print; exit }' "$CARRIERS_DB")
            if [ -n "$_cur_row" ]; then
                _st_iso=$(echo "$_cur_row" | cut -d':' -f3 | tr '[:lower:]' '[:upper:]')
                _st_alpha=$(echo "$_cur_row" | cut -d':' -f4)
                echo "ℹ️ Действие отменено. Сохраняется статический профиль: ${_st_alpha} (${_st_iso})."
            else
                echo "ℹ️ Действие отменено. Активен профиль [$CURRENT_CARRIER]."
            fi
            exit 0
            ;;
    esac
fi

# Авто-режим нацеливаем на регион карты
write_settings 0 "$TARGET_ISO"
echo "📝 Настройки обновлены. Авто-режим нацелен на регион [$CARD_ISO_UP]."

_set_prop "gsm.sim.operator.alpha"       "${TARGET_ALPHA}${SUFFIX}"
_set_prop "gsm.operator.alpha"           "${TARGET_ALPHA}${SUFFIX}"
_set_prop "gsm.sim.operator.numeric"     "${TARGET_NUMERIC}${SUFFIX}"
_set_prop "gsm.operator.numeric"         "${TARGET_NUMERIC}${SUFFIX}"
_set_prop "gsm.sim.operator.iso-country" "${TARGET_ISO}${SUFFIX}"
_set_prop "gsm.operator.iso-country"     "${TARGET_ISO}${SUFFIX}"

restart_google
echo "🚀 [Авто-режим] Динамически применён профиль: $TARGET_NAME"
