#!/system/bin/sh
# shellcheck shell=sh
# GPay-Spoofer: customize.sh (выбор профиля при установке)

CARRIERS_DB="$MODPATH/carriers.db"
OLD_DB="/data/adb/modules/$MODID/carriers.db"
KEY_TIMEOUT=15   # секунд ожидания на каждый пункт меню

# Сохраняем пользовательскую базу при обновлении модуля
if [ ! -f "$CARRIERS_DB" ] && [ -f "$OLD_DB" ]; then
    cp "$OLD_DB" "$CARRIERS_DB"
fi

if [ ! -f "$CARRIERS_DB" ]; then
    cat << 'EOF' > "$CARRIERS_DB"
1:24701:lv:LMT
2:310410:us:AT&T
3:26201:de:Telekom
4:20801:fr:Orange
5:26002:pl:T-Mobile
6:24405:fi:Elisa
7:302720:ca:Rogers
8:52501:sg:Singtel
9:42402:ae:Etisalat
10:45005:kr:SKT
11:40101:kz:Beeline
12:37001:do:Orange
13:28601:tr:Turkcell
14:43211:ir:Hamrah-e-Avval
15:23410:gb:O2
16:22201:it:TIM
17:21401:es:Movistar
18:20404:nl:Vodafone
19:23201:at:A1
20:22801:ch:Swisscom
21:44010:jp:NTT Docomo
22:50501:au:Telstra
23:53001:nz:One NZ
24:72402:br:Claro
25:334020:mx:Telcel
26:73001:cl:Entel
27:40445:in:Airtel
28:45201:vn:Viettel
29:52001:th:AIS
30:51011:id:XL Axiata
31:42501:il:Partner
32:65501:za:Vodacom
EOF
fi

# Читает одно событие getevent максимум ~1 секунду (работает и без утилиты timeout)
_read_event() {
    _dir="${TMPDIR:-/dev/tmp}"
    mkdir -p "$_dir" 2>/dev/null
    _tmp="$_dir/gpay_ev.$$"
    : > "$_tmp"
    getevent -lqc 1 > "$_tmp" 2>/dev/null &
    _pid=$!
    _i=0
    while [ "$_i" -lt 10 ] && kill -0 "$_pid" 2>/dev/null; do
        sleep 0.1
        _i=$((_i + 1))
    done
    kill "$_pid" 2>/dev/null
    cat "$_tmp" 2>/dev/null
    rm -f "$_tmp"
}

# Возврат: 0 = громкость ПЛЮС, 1 = громкость МИНУС, 2 = таймаут
choose_key() {
    if command -v key_check >/dev/null 2>&1; then
        key_check; return $?
    fi
    if ! command -v getevent >/dev/null 2>&1; then
        ui_print "⚠️ getevent не найден! Выбран текущий пункт."
        return 2
    fi
    _end=$(( $(date +%s) + KEY_TIMEOUT ))
    while [ "$(date +%s)" -lt "$_end" ]; do
        _event=$(_read_event)
        case "$_event" in
            *KEY_VOLUMEUP*DOWN*)   return 0 ;;
            *KEY_VOLUMEDOWN*DOWN*) return 1 ;;
        esac
    done
    return 2
}

# Список реальных id: 0 (Авто) + все id из базы
IDS="0 $(awk -F: '/^[0-9]+:/ { gsub(/\r/, ""); printf "%s ", $1 }' "$CARRIERS_DB")"
TOTAL_STATES=$(echo "$IDS" | wc -w)

ui_print " "
ui_print "==================================="
ui_print " [Громкость МИНУС] — Далее"
ui_print " [Громкость ПЛЮС]  — Выбрать"
ui_print " (Нет нажатия ${KEY_TIMEOUT} с — выбран текущий пункт)"
ui_print "==================================="

POS=0
SELECTED_CARRIER=0

while true; do
    MENU_INDEX=$(echo "$IDS" | awk -v n="$((POS + 1))" '{ print $n }')

    if [ "$MENU_INDEX" -eq 0 ]; then
        CURRENT_NAME="Оригинальные значения (Режим Авто)"
    else
        CURRENT_NAME="Неизвестный профиль"
        _match=$(awk -F: -v i="$MENU_INDEX" '{ gsub(/\r/, "") } $1==i { print; exit }' "$CARRIERS_DB")
        if [ -n "$_match" ]; then
            _iso=$(echo "$_match" | cut -d':' -f3 | tr '[:lower:]' '[:upper:]')
            _alpha=$(echo "$_match" | cut -d':' -f4)
            CURRENT_NAME="${_alpha} (${_iso})"
        fi
    fi

    ui_print "-> Выбор: $CURRENT_NAME"
    choose_key
    _rc=$?
    case "$_rc" in
        0|2) SELECTED_CARRIER="$MENU_INDEX"; break ;;
        *)   POS=$(( (POS + 1) % TOTAL_STATES )) ;;
    esac
done

# Регион выбранного профиля для режима авто-подстановки
NEW_ISO=""
if [ "$SELECTED_CARRIER" -ne 0 ]; then
    _match=$(awk -F: -v i="$SELECTED_CARRIER" '{ gsub(/\r/, "") } $1==i { print; exit }' "$CARRIERS_DB")
    NEW_ISO=$(echo "$_match" | cut -d':' -f3 | tr -d '\r ')
fi

# Файл settings
printf 'selected_carrier=%s\nlast_searched_iso=%s\n' "$SELECTED_CARRIER" "$NEW_ISO" > "$MODPATH/settings"

# Права доступа
chmod 0600 "$MODPATH/settings" "$CARRIERS_DB"
chmod 0755 "$MODPATH/service.sh" "$MODPATH/action.sh" "$MODPATH/bin_checker.sh" 2>/dev/null

ui_print "==================================="
if [ "$SELECTED_CARRIER" -eq 0 ]; then
    ui_print "✅ Успешно! Модуль запущен в режиме Авто."
else
    ui_print "✅ Успешно! Зафиксирован профиль [$SELECTED_CARRIER] (Регион: $NEW_ISO)"
fi
ui_print "==================================="
