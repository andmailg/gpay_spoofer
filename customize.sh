#!/system/bin/sh

choose_key() {
    while true; do
        /system/bin/getevent -lqc 1 -t 1 2>&1 | while read -r line; do
            case "$line" in
                *KEY_VOLUMEUP*DOWN*) return 0 ;;
                *KEY_VOLUMEDOWN*DOWN*) return 1 ;;
            esac
        done
    done
}

# --- Проверка и создание базы данных ---
CARRIERS_DB="$MODPATH/carriers.db"
if [ ! -f "$CARRIERS_DB" ]; then
    cat << 'EOF' > "$CARRIERS_DB"
1:24701:lv:LV Latvijas Mobilais
2:310094:us:US AT&T
3:310260:us:US T-Mobile
4:26201:de:DE Telekom (Germany)
5:20801:fr:FR Orange (France)
6:26002:pl:PL Polish T-Mobile
7:24405:fi:FI Elisa (Finland)
8:311480:us:US Verizon (USA)
9:302720:ca:CA Rogers (Canada)
10:52501:sg:SG Singtel (Singapore)
11:42402:ae:AE Etisalat (UAE)
12:45005:kr:KR SK Telecom (South Korea)
EOF
fi

TOTAL_CARRIERS="$(sed '/^\s*$/d' "$CARRIERS_DB" | wc -l | tr -d ' ')"
[ -z "$TOTAL_CARRIERS" ] && TOTAL_CARRIERS=0
SELECTED_CARRIER=""

ui_print " "
ui_print "==================================="
ui_print "    УМНАЯ НАСТРОЙКА ПО BIN КАРТЫ   "
ui_print "==================================="
ui_print " Введите первые 6-8 цифр карты,"
ui_print " чтобы автоматически подобрать"
ui_print " нужный профиль оператора."
ui_print " "
ui_print " Нажмите ENTER (оставьте пустым)"
ui_print " для ручного выбора кнопками."
ui_print "==================================="
ui_print " "

printf " Введите BIN карты: "
read -r USER_BIN
USER_BIN="$(echo "$USER_BIN" | tr -d ' ' | tr -d '-')"

if [ -n "$USER_BIN" ] && [ "$USER_BIN" != "0" ]; then
    BIN_8="$(echo "$USER_BIN" | cut -c1-8)"
    BIN_6="$(echo "$BIN_8" | cut -c1-6)"
    
    case "$BIN_8" in
        *[!0-9]*)
            ui_print "[!] Ошибка: BIN должен состоять только из цифр!"
            ;;
        *)
            ui_print "[*] Анализирую BIN: $BIN_8"
            TARGET_ISO=""
            
            case "$BIN_8" in
                53787211*|537872*) TARGET_ISO="lv" ;;
            esac
            
            if [ -z "$TARGET_ISO" ]; then
                ui_print "[*] Запрашиваю онлайн-базу..."
                RESPONSE="$(curl -sL --connect-timeout 5 "https://handyapi.com" 2>/dev/null)"
                TARGET_ISO="$(echo "$RESPONSE" | sed -n 's/.*"CountryCode":\s*"\([^"]*\)".*/\1/p' | tr '[:upper:]' '[:lower:]')"
            fi
            
            if [ -n "$TARGET_ISO" ]; then
                MATCH_LINE="$(sed -n "/:${TARGET_ISO}:/p" "$CARRIERS_DB" | head -n 1)"
                if [ -n "$MATCH_LINE" ]; then
                    SELECTED_CARRIER="$(echo "$MATCH_LINE" | cut -d':' -f1)"
                    ui_print "[+] Автоподбор успешен! Страна: $TARGET_ISO"
                else
                    ui_print "[!] Страна '$TARGET_ISO' найдена, но оператора нет в базе."
                    ui_print "[*] Применяю профиль 1 (Латвия)."
                    SELECTED_CARRIER=1
                fi
            else
                ui_print "[!] Не удалось определить страну (нет сети или неверный BIN)."
            fi
            ;;
    esac
fi

# ============================================================
# РЕЗЕРВНЫЙ РЕЖИМ (ВЫБОР КНОПКАМИ ГРОМКОСТИ)
# ============================================================
if [ -z "$SELECTED_CARRIER" ]; then
    ui_print " "
    ui_print "[*] Включаю ручной выбор профиля..."
    ui_print " [Громкость МИНУС] — Выбрать следующий"
    ui_print " [Громкость ПЛЮС]  — Подтвердить текущий"
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

        ui_print "-> Текущий пункт: $CURRENT_NAME"
        
        choose_key
        if [ $? -eq 0 ]; then
            SELECTED_CARRIER=$MENU_INDEX
            break
        else
            MENU_INDEX=$(( (MENU_INDEX + 1) % TOTAL_STATES ))
        fi
    done
fi

# --- Фиксация настроек ---
echo "selected_carrier=$SELECTED_CARRIER" > "$MODPATH/settings"
chmod 0600 "$MODPATH/settings"
chmod 0600 "$CARRIERS_DB"

chmod 0755 "$MODPATH/service.sh" 2>/dev/null
chmod 0755 "$MODPATH/action.sh" 2>/dev/null
chmod 0755 "$MODPATH/status.sh" 2>/dev/null

ui_print "==================================="
ui_print "✅ Модуль настроен на профиль [$SELECTED_CARRIER]"
ui_print "[*] GPay Spoofer успешно установлен!"
ui_print "==================================="
