#!/system/bin/sh
# GPay Spoofer — customize.sh (Финальная версия)

CARRIERS_DB="$MODPATH/carriers.db"

# Автонаполнение базы данных, если файла нет в архиве
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

# Исправленная функция фиксации кнопок громкости (игнорирует тачскрин и датчики)
choose_key() {
    while true; do
        _event=$(/system/bin/getevent -lqc 1 2>/dev/null)
        case "$_event" in
            *KEY_VOLUMEUP*DOWN*) return 0 ;;
            *KEY_VOLUMEDOWN*DOWN*) return 1 ;;
        esac
    done
}

# Безопасный подсчет строк без форков утилит
TOTAL_CARRIERS=0
while read -r line; do
    case "$line" in
        "" | [[:space:]]*) continue ;;
        *) TOTAL_CARRIERS=$((TOTAL_CARRIERS + 1)) ;;
    esac
done < "$CARRIERS_DB"

SELECTED_CARRIER=""

ui_print " "
ui_print "==================================="
ui_print "       ВЫБОР РЕГИОНА СПУФИНГА      "
ui_print "==================================="
ui_print " [Громкость МИНУС] — Следующий пункт"
ui_print " [Громкость ПЛЮС]  — Подтвердить выбор"
ui_print "==================================="
ui_print " "

MENU_INDEX=0
TOTAL_STATES=$((TOTAL_CARRIERS + 1))

while true; do
    if [ "$MENU_INDEX" -eq 0 ]; then
        CURRENT_NAME="Оригинальные значения (Без спуфинга)"
    else
        CURRENT_NAME="Неизвестный профиль"
        while IFS=":" read -r id _numeric _iso name; do
            [ -z "$id" ] && continue
            if [ "$id" -eq "$MENU_INDEX" ]; then
                CURRENT_NAME="$name"
                break
            fi
        done < "$CARRIERS_DB"
    fi

    ui_print "-> Текущий выбор: $CURRENT_NAME"
    
    choose_key
    if [ $? -eq 0 ]; then
        SELECTED_CARRIER="$MENU_INDEX"
        break
    else
        MENU_INDEX=$(( (MENU_INDEX + 1) % TOTAL_STATES ))
    fi
done

# --- Фиксация ОРИГИНАЛЬНЫХ пропсов при первой установке ---
PROPS_FILE="$MODPATH/original_props"
echo "ORIG_NUMERIC=\"$(getprop gsm.operator.numeric)\"" > "$PROPS_FILE"
echo "ORIG_ISO=\"$(getprop gsm.operator.iso-country)\"" >> "$PROPS_FILE"
echo "ORIG_CDMA=\"$(getprop ro.cdma.home.operator.numeric)\"" >> "$PROPS_FILE"

printf 'selected_carrier=%s\n' "$SELECTED_CARRIER" > "$MODPATH/settings"
chmod 0600 "$MODPATH/settings" "$CARRIERS_DB" "$PROPS_FILE"

chmod 0755 "$MODPATH/service.sh" 2>/dev/null
chmod 0755 "$MODPATH/action.sh" 2>/dev/null

ui_print "==================================="
ui_print "✅ Модуль настроен на профиль [$SELECTED_CARRIER]"
ui_print "[*] GPay Spoofer успешно установлен!"
ui_print "==================================="
