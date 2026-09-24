#!/system/bin/sh
# shellcheck shell=sh

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="$MODDIR/Gpay-Spoofer.log"
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
    sleep 0.1 
}

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SERVICE] $1" >> "$LOGFILE" 2>/dev/null
}

# 1. Ждёт готовности пропса
# 2. Делает бэкап оригинального значения (если бэкап ещё не содержит ключ)
# 3. Сразу перезаписывает новым целевым значением
_process_prop() {
    _prop_name="$1"
    _key_name="$2"
    _target_val="$3"
    _sleep_count=0

    # Ожидание инициализации свойства
    while :; do
        _curr_val=$(getprop "$_prop_name" 2>/dev/null)
        if [ "$_curr_val" != "," ] && [ -n "$_curr_val" ]; then
            break
        fi
        sleep 1
        _sleep_count=$((_sleep_count + 1))
    done

    # Бэкап первого чистого значения
    _clean_orig=$(echo "$_curr_val" | cut -d',' -f1)
    if [ -n "$_clean_orig" ] && [ "$_clean_orig" != "," ]; then
        if ! grep -q "^${_key_name}=" "$PROPS_FILE" 2>/dev/null; then
            echo "${_key_name}=\"${_clean_orig}\"" >> "$PROPS_FILE"
            chmod 0600 "$PROPS_FILE" 2>/dev/null
        fi
    fi

    # Мгновенная перезапись целевым значением
    _set_prop "$_prop_name" "${_target_val},"
    log_msg "DEBUG: Prop '$_prop_name' готов (ждали ${_sleep_count}с). Спуф: '${_target_val},'"
}

# Определяем профиль для подмены
SELECTED_CARRIER=$(grep '^selected_carrier=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1)
case "$SELECTED_CARRIER" in *[!0-9]*|"") SELECTED_CARRIER=0 ;; esac

TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_ALPHA=""
TARGET_NAME=""

if [ "$SELECTED_CARRIER" -eq 0 ]; then
    # =========================================================================
    # ВЕТКА 1: РЕЖИМ АВТО
    # =========================================================================
    LAST_SEARCHED_ISO=$(grep '^last_searched_iso=' "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | head -n 1 | tr -d '\r ' | tr '[:upper:]' '[:lower:]')
    if [ -n "$LAST_SEARCHED_ISO" ]; then
        _match=$(grep ":${LAST_SEARCHED_ISO}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
        if [ -n "$_match" ]; then
            TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2)
            TARGET_ISO=$(echo "$_match" | cut -d':' -f3)
            TARGET_ALPHA=$(echo "$_match" | cut -d':' -f4)
            TARGET_ISO_UPPER=$(echo "$TARGET_ISO" | tr '[:lower:]' '[:upper:]')
            TARGET_NAME="${TARGET_ALPHA} (${TARGET_ISO_UPPER})"
            log_msg "🤖 Режим Авто: Нацелен регион [$LAST_SEARCHED_ISO] -> $TARGET_NAME"
        fi
    fi
    if [ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ]; then
        log_msg "ℹ️ Режим Авто: Список пуст или регион отсутствует в БД. Спуфинг спит."
        exit 0
    fi
else
    # =========================================================================
    # ВЕТКА 2: СТАТИКА
    # =========================================================================
    _match=$(grep "^${SELECTED_CARRIER}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
    if [ -n "$_match" ]; then
        TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2)
        TARGET_ISO=$(echo "$_match" | cut -d':' -f3)
        TARGET_ALPHA=$(echo "$_match" | cut -d':' -f4)
        TARGET_ISO_UPPER=$(echo "$TARGET_ISO" | tr '[:lower:]' '[:upper:]')
        TARGET_NAME="${TARGET_ALPHA} (${TARGET_ISO_UPPER})"
    fi
    if [ -z "$TARGET_NUMERIC" ] || [ -z "$TARGET_ISO" ]; then
        log_msg "❌ Ошибка: Статический профиль [$SELECTED_CARRIER] поврежден в БД."
        exit 1
    fi
fi

log_msg "DEBUG: Целевые значения -> NUMERIC='$TARGET_NUMERIC', ISO='$TARGET_ISO', ALPHA='$TARGET_ALPHA'"

# Создаем бэкап-файл, если его еще нет
[ ! -f "$PROPS_FILE" ] && touch "$PROPS_FILE"

# Поштучно ждем, бэкапим оригиналы и сразу перезаписываем
_process_prop "gsm.sim.operator.alpha" "ORIG_ALPHA" "$TARGET_ALPHA"
_process_prop "gsm.operator.alpha" "ORIG_OPERATOR_ALPHA" "$TARGET_ALPHA"
_process_prop "gsm.sim.operator.numeric" "ORIG_SIM_NUMERIC" "$TARGET_NUMERIC"
_process_prop "gsm.operator.numeric" "ORIG_NUMERIC" "$TARGET_NUMERIC"
_process_prop "gsm.sim.operator.iso-country" "ORIG_ISO" "$TARGET_ISO"
_process_prop "gsm.operator.iso-country" "ORIG_OPERATOR_ISO" "$TARGET_ISO"

if [ "$SELECTED_CARRIER" -eq 0 ]; then
    log_msg "🤖 [Авто-режим] Успешно применен профиль: $TARGET_NAME"
else
    log_msg "🚀 [Статика] Успешно применен профиль [$SELECTED_CARRIER]: $TARGET_NAME"
fi
