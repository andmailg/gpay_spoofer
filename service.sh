#!/system/bin/sh
# shellcheck shell=sh
# GPay-Spoofer: service.sh (экономичная версия)
# Сохраните в папку модуля как service.sh (права 755)

case "$0" in
    */*) MODDIR="${0%/*}" ;;
    *)   MODDIR="$(pwd)" ;;
esac
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="$MODDIR/Gpay-Spoofer.log"
PROPS_FILE="$MODDIR/original_props"

INTERVAL=30     # секунд между проверками
LOG_KEEP=200    # сколько строк лога оставлять при старте
SUFFIX=","      # формат значения; "" для одного слота (как в остальных скриптах)

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

log_msg() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SERVICE] $1" >> "$LOGFILE" 2>/dev/null
}

# Чтение settings без запуска внешних процессов
read_settings() {
    S_SEL=""; S_ISO=""
    [ -r "$SETTINGS" ] || return 0
    while IFS='=' read -r _k _v || [ -n "$_k" ]; do
        _v=${_v%"$CR"}
        case "$_k" in
            selected_carrier)  S_SEL=$_v ;;
            last_searched_iso) S_ISO=$_v ;;
        esac
    done < "$SETTINGS"
}

# Вызывается только при изменении settings. Заполняет MODE, SEL, TARGET_*
resolve_target() {
    TARGET_NUMERIC=""; TARGET_ISO=""; TARGET_ALPHA=""; TARGET_NAME=""; MODE=""
    case "$S_SEL" in
        *[!0-9]* | "") SEL=0 ;;
        *)             SEL=$S_SEL ;;
    esac

    if [ "$SEL" -eq 0 ]; then
        MODE="auto"
        _iso=$(echo "$S_ISO" | tr -d ' ' | tr '[:upper:]' '[:lower:]')
        [ -n "$_iso" ] || return 1
        _row=$(awk -F: -v i="$_iso" '{ gsub(/\r/, "") } tolower($3)==i { print; exit }' "$CARRIERS_DB" 2>/dev/null)
    else
        MODE="static"
        _row=$(awk -F: -v i="$SEL" '{ gsub(/\r/, "") } $1==i { print; exit }' "$CARRIERS_DB" 2>/dev/null)
    fi
    [ -n "$_row" ] || return 1

    TARGET_NUMERIC=$(echo "$_row" | cut -d':' -f2)
    TARGET_ISO=$(echo "$_row" | cut -d':' -f3)
    TARGET_ALPHA=$(echo "$_row" | cut -d':' -f4)
    [ -n "$TARGET_NUMERIC" ] && [ -n "$TARGET_ISO" ] || return 1

    _iso_up=$(echo "$TARGET_ISO" | tr '[:lower:]' '[:upper:]')
    TARGET_NAME="${TARGET_ALPHA} (${_iso_up})"
    return 0
}

# ensure_prop <prop> <ключ бэкапа> <целевое значение>
# Значение берётся из одного снимка getprop ($DUMP), без отдельных запусков на каждое свойство.
ensure_prop() {
    _p="$1"; _k="$2"; _want="${3}${SUFFIX}"

    _t=${DUMP#*"[$_p]: ["}
    [ "$_t" = "$DUMP" ] && return 1          # свойства нет
    _cur=${_t%%"]"*}
    if [ -z "$_cur" ] || [ "$_cur" = "," ]; then
        return 1                             # ещё нет SIM/сети
    fi
    [ "$_cur" = "$_want" ] && return 0

    # Бэкап первого «чистого» значения за эту загрузку
    if ! grep -q "^${_k}=" "$PROPS_FILE" 2>/dev/null; then
        _orig=${_cur%%,*}
        if [ -n "$_orig" ]; then
            echo "${_k}=\"${_orig}\"" >> "$PROPS_FILE"
            chmod 0600 "$PROPS_FILE" 2>/dev/null
        fi
    fi

    _set_prop "$_p" "$_want"
    CHANGED=$((CHANGED + 1))
    return 0
}

{
CR=$(printf '\r')

# Обрезаем лог
if [ -f "$LOGFILE" ]; then
    tail -n "$LOG_KEEP" "$LOGFILE" > "$LOGFILE.tmp" 2>/dev/null && mv "$LOGFILE.tmp" "$LOGFILE"
fi
log_msg "GPay-Spoofer запущен (экономичный режим, интервал ${INTERVAL}с)"

# Свойства сбрасываются при перезагрузке, бэкап ведём заново за каждую загрузку
: > "$PROPS_FILE"
chmod 0600 "$PROPS_FILE" 2>/dev/null

prev_key="unset"
have_target=0
last_msg=""

while :; do
    read_settings
    key="$S_SEL|$S_ISO"

    # Профиль пересчитываем только если изменился settings
    if [ "$key" != "$prev_key" ]; then
        prev_key="$key"
        if resolve_target; then
            have_target=1
            last_msg=""
            log_msg "Профиль: [$MODE] $TARGET_NAME"
        else
            have_target=0
            if [ "$SEL" -eq 0 ]; then
                _msg="ℹ️ Режим Авто: регион не задан или отсутствует в БД. Спуфинг спит."
            else
                _msg="❌ Статический профиль [$SEL] не найден или повреждён в БД."
            fi
            if [ "$_msg" != "$last_msg" ]; then
                log_msg "$_msg"
                last_msg="$_msg"
            fi
        fi
    fi

    if [ "$have_target" -eq 1 ]; then
        DUMP=$(getprop)
        CHANGED=0
        ensure_prop "gsm.sim.operator.alpha"        "ORIG_ALPHA"          "$TARGET_ALPHA"
        ensure_prop "gsm.operator.alpha"            "ORIG_OPERATOR_ALPHA" "$TARGET_ALPHA"
        ensure_prop "gsm.sim.operator.numeric"      "ORIG_SIM_NUMERIC"    "$TARGET_NUMERIC"
        ensure_prop "gsm.operator.numeric"          "ORIG_NUMERIC"        "$TARGET_NUMERIC"
        ensure_prop "gsm.sim.operator.iso-country"  "ORIG_ISO"            "$TARGET_ISO"
        ensure_prop "gsm.operator.iso-country"      "ORIG_OPERATOR_ISO"   "$TARGET_ISO"

        if [ "$CHANGED" -gt 0 ]; then
            log_msg "🚀 [$MODE] Применён профиль: $TARGET_NAME (обновлено свойств: $CHANGED)"
        fi
    fi

    sleep "$INTERVAL"
done
} &
