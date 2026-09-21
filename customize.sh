#!/system/bin/sh

# Функция для фиксации нажатий кнопок громкости
# Возвращает 0 для Volume Plus, 1 для Volume Minus
choose_key() {
    while true; do
        /system/bin/getevent -lqc 1 2>&1 | while read -r line; do
            case "$line" in
                *KEY_VOLUMEUP*DOWN*) return 0 ;;
                *KEY_VOLUMEDOWN*DOWN*) return 1 ;;
            esac
        done
    done
}

# --- Проверка наличия базы данных в архиве ---
if [ ! -f "$MODPATH/carriers.db" ]; then
    cat << EOF > "$MODPATH/carriers.db"
1:24701:lv:🇱🇻 Latvijas Mobilais
2:310094:us:🇺🇸 AT&T
3:310260:us:🇺🇸 T-Mobile
4:26201:de:🇩🇪 Telekom (Germany)
5:20801:fr:🇫🇷 Orange (France)
6:26002:pl:🇵🇱 Polish T-Mobile
7:24405:fi:🇫🇮 Elisa (Finland)
8:311480:us:🇺🇸 Verizon (USA)
9:302720:ca:🇨🇦 Rogers (Canada)
10:52501:sg:🇸🇬 Singtel (Singapore)
11:42402:ae:🇦🇪 Etisalat (UAE)
12:45005:kr:🇰🇷 SK Telecom (South Korea)
EOF
fi

CARRIERS_DB="$MODPATH/carriers.db"

# Считаем количество доступных операторов
TOTAL_CARRIERS=0
if [ -f "$CARRIERS_DB" ]; then
    TOTAL_CARRIERS="$(sed '/^\s*$/d' "$CARRIERS_DB" | wc -l | tr -d ' ')"
fi
[ -z "$TOTAL_CARRIERS" ] && TOTAL_CARRIERS=0

# --- Интерактивное меню выбора ---
ui_print " "
ui_print "=== ВЫБОР ПРОФИЛЯ ПРИ УСТАНОВКЕ ==="
ui_print " Использовать кнопки громкости:"
ui_print " [Громкость МИНУС] — Следующий пункт"
ui_print " [Громкость ПЛЮС]  — Подтвердить выбор"
ui_print "==================================="
ui_print " "

MENU_INDEX=0
TOTAL_STATES=$((TOTAL_CARRIERS + 1))

while true; do
    if [ "$MENU_INDEX" -eq 0 ]; then
        CURRENT_NAME="Профиль 0: Оригинальные значения (Без спуфинга)"
    else
        LINE="$(sed -n "/^${MENU_INDEX}:/p" "$CARRIERS_DB" | head -n 1)"
        if [ -n "$LINE" ]; then
            IFS=":" read -r _ _ _ CURRENT_NAME << EOF
$LINE
EOF
        else
            CURRENT_NAME="Неизвестный профиль"
        fi
    fi

    ui_print "-> Текущий выбор: $CURRENT_NAME"
    ui_print "   [+ ПЛЮС] - Выбрать | [- МИНУС] - Дальше"
    ui_print " "

    choose_key
    KEY_RESULT=$?

    if [ "$KEY_RESULT" -eq 0 ]; then
        SELECTED_CARRIER=$MENU_INDEX
        break
    else
        MENU_INDEX=$(( (MENU_INDEX + 1) % TOTAL_STATES ))
    fi
done

# --- Запись выбранного профиля в settings ---
echo "selected_carrier=$SELECTED_CARRIER" > "$MODPATH/settings"
chmod 0600 "$MODPATH/settings"
chmod 0600 "$CARRIERS_DB"

# --- Выставление прав на исполняемые скрипты ---
chmod 0755 "$MODPATH/service.sh" 2>/dev/null
chmod 0755 "$MODPATH/action.sh" 2>/dev/null

ui_print "==================================="
ui_print "✅ Успешно выбран профиль: $SELECTED_CARRIER"
ui_print "[*] GPay Spoofer установлен!"
ui_print "[*] Вы можете изменить профиль позже через Action в Magisk"
ui_print "==================================="
