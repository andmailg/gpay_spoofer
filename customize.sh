#!/system/bin/sh
CARRIERS_DB="$MODPATH/carriers.db"

# 1. Генерация встроенной базы данных (если отсутствует в zip)
if [ ! -f "$CARRIERS_DB" ]; then
    cat << 'EOF' > "$CARRIERS_DB"
1:24701:lv:Latvia (LMT)
2:310410:us:USA (AT&T)
3:26201:de:Germany (Telekom)
4:20801:fr:France (Orange)
5:26002:pl:Poland (T-Mobile)
6:24405:fi:Finland (Elisa)
7:302720:ca:Canada (Rogers)
8:52501:sg:Singapore (Singtel)
9:42402:ae:UAE (Etisalat)
10:45005:kr:South Korea (SKT)
11:40101:kz:Kazakhstan (Beeline)
12:37001:do:Dominican Rep (Orange)
13:28601:tr:Turkey (Turkcell)
14:43211:ir:Iran (Hamrah-e-Avval)
15:23410:gb:United Kingdom (O2)
16:22201:it:Italy (TIM)
17:21401:es:Spain (Movistar)
18:20404:nl:Netherlands (Vodafone)
19:23201:at:Austria (A1)
20:22801:ch:Switzerland (Swisscom)
21:44010:jp:Japan (NTT Docomo)
22:50501:au:Australia (Telstra)
23:53001:nz:New Zealand (One NZ)
24:72402:br:Brazil (Claro)
25:334020:mx:Mexico (Telcel)
26:73001:cl:Chile (Entel)
27:40445:in:India (Airtel)
28:45201:vn:Vietnam (Viettel)
29:52001:th:Thailand (AIS)
30:51011:id:Indonesia (XL Axiata)
31:42501:il:Israel (Partner)
32:65501:za:South Africa (Vodacom)
EOF
fi

# Функция отслеживания нажатия кнопок (громкость + / громкость -)
choose_key() {
    if command -v key_check >/dev/null 2>&1; then
        key_check
        return $?
    fi

    if ! command -v getevent >/dev/null 2>&1; then
        ui_print "⚠️ getevent не найден! Автовыбор через 3 секунды..."
        sleep 3
        return 1
    fi

    _count=0
    while [ "$_count" -lt 150 ]; do
        _event=$(getevent -ql -c 1 2>/dev/null | head -n 1)
        if [ -z "$_event" ]; then
            _event=$(getevent -c 1 2>/dev/null | head -n 1)
        fi

        case "$_event" in
            *KEY_VOLUMEUP*DOWN* | *0001*0073*00000001*)
                return 0
                ;;
            *KEY_VOLUMEDOWN*DOWN* | *0001*0072*00000001*)
                return 1
                ;;
        esac
        
        sleep 0.1
        _count=$((_count + 1))
    done

    return 1
}

TOTAL_CARRIERS=$(grep -c "^[0-9]" "$CARRIERS_DB" 2>/dev/null || echo "32")
case "$TOTAL_CARRIERS" in ''|*[!0-9]*) TOTAL_CARRIERS=32 ;; esac
SELECTED_CARRIER=""

ui_print " "
ui_print "==================================="
ui_print " [Громкость МИНУС] — Далее"
ui_print " [Громкость ПЛЮС]  — Выбрать"
ui_print " (Таймаут автовыбора: 15 секунд)"
ui_print "==================================="

MENU_INDEX=0
TOTAL_STATES=$((TOTAL_CARRIERS + 1))

while true; do
    if [ "$MENU_INDEX" -eq 0 ]; then
        CURRENT_NAME="Оригинальные значения (Режим Авто)"
    else
        CURRENT_NAME="Неизвестный профиль"
        _match=$(grep "^${MENU_INDEX}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
        if [ -n "$_match" ]; then
            CURRENT_NAME=$(echo "$_match" | cut -d':' -f4)
        fi
    fi
    
    ui_print "-> Выбор: $CURRENT_NAME"
    
    if choose_key; then
        SELECTED_CARRIER="$MENU_INDEX"
        break
    else
        MENU_INDEX=$(( (MENU_INDEX + 1) % TOTAL_STATES ))
    fi
done

# =========================================================================
# НОВАЯ ЛОГИКА СИНХРОНИЗАЦИИ ПЕРЕМЕННЫХ НА ОСНОВЕ ВЫБОРА ПОЛЬЗОВАТЕЛЯ
# =========================================================================
NEW_ISO=""

if [ "$SELECTED_CARRIER" -eq 0 ]; then
    NEW_ISO="" # При выборе Авто (0) переменная региона создается пустой
else
    # При выборе статического профиля извлекаем его ISO из базы данных
    _match=$(grep "^${SELECTED_CARRIER}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
    if [ -n "$_match" ]; then
        NEW_ISO=$(echo "$_match" | cut -d':' -f3 | tr -d '\r ')
    fi
fi

# Инициализируем файл settings с жестко заданной двухстрочной структурой
printf 'selected_carrier=%s\nlast_searched_iso=%s\n' "$SELECTED_CARRIER" "$NEW_ISO" > "$MODPATH/settings"

# Настройка безопасных прав доступа (POSIX-стандарт Magisk BusyBox)
chmod 0600 "$MODPATH/settings" "$CARRIERS_DB"
chmod 0755 "$MODPATH/service.sh" "$MODPATH/action.sh" "$MODPATH/bin_checker.sh" 2>/dev/null

ui_print "==================================="
if [ "$SELECTED_CARRIER" -eq 0 ]; then
    ui_print "✅ Успешно! Модуль запущен в режиме Авто."
else
    ui_print "✅ Успешно! Зафиксирован профиль [$SELECTED_CARRIER] (Регион: $NEW_ISO)"
fi
ui_print "==================================="
