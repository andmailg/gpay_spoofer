#!/system/bin/sh

# ============================================================
# GPay Spoofer — customize.sh (Инсталлятор модуля Magisk)
# ============================================================

# --- Функция фиксации нажатий кнопок громкости ---
# Работает через потоковый конвейер, не нагружает CPU в Recovery
choose_key() {
    /system/bin/getevent -lqc 1 -t 1 2>/dev/null | while read -r line; do
        case "$line" in
            *KEY_VOLUMEUP*DOWN*) return 0 ;;
            *KEY_VOLUMEDOWN*DOWN*) return 1 ;;
        esac
    done
}

# --- Проверка и автоматическое наполнение базы данных операторов ---
CARRIERS_DB="$MODPATH/carriers.db"
if [ ! -f "$CARRIERS_DB" ]; then
    cat << 'EOF' > "$CARRIERS_DB"
1:24701:lv:🇱🇻 Latvijas Mobilais (Latvia)
2:310094:us:🇺🇸 AT&T (USA)
3:310260:us:🇺🇸 T-Mobile (USA)
4:26201:de:🇩🇪 Telekom (Germany)
5:20801:fr:🇫🇷 Orange (France)
6:26002:pl:🇵🇱 Polish T-Mobile
7:24405:fi:🇫🇮 Elisa (Finland)
8:311480:us:🇺🇸 Verizon (USA)
9:302720:ca:🇨🇦 Rogers (Canada)
10:52501:sg:🇸🇬 Singtel (Singapore)
11:42402:ae:🇦🇪 Etisalat (UAE)
12:45005:kr:🇰🇷 SK Telecom (South Korea)
13:40101:kz:🇰🇿 Beeline (Kazakhstan)
EOF
fi

# Подсчет количества операторов в базе (без учета пустых строк)
TOTAL_CARRIERS="$(
    sed '/^[[:space:]]*$/d' "$CARRIERS_DB" 2>/dev/null |
    wc -l |
    tr -d '[:space:]'
)"

case "$TOTAL_CARRIERS" in
    ''|*[!0-9]*) TOTAL_CARRIERS=0 ;;
esac

SELECTED_CARRIER=""

# ============================================================
# ШАГ 1: УМНАЯ НАСТРОЙКА ПО BIN КАРТЫ
# ============================================================
ui_print " "
ui_print "==================================="
ui_print "    УМНАЯ НАСТРОЙКА ПО BIN КАРТЫ   "
ui_print "==================================="
ui_print " Вы можете ввести первые 6-8 цифр"
ui_print " вашей карты, чтобы скрипт сам"
ui_print " подобрал лучшего оператора."
ui_print " "
ui_print " Нажмите ENTER (оставьте пустым)"
ui_print " для ручного выбора оператора."
ui_print "==================================="
ui_print " "

printf " Введите BIN карты: "
read -r USER_BIN

# Очищаем пользовательский ввод от пробелов, дефисов и мусора
USER_BIN="$(echo "$USER_BIN" | tr -d '[:space:]' | tr -d '-')"

if [ -n "$USER_BIN" ] && [ "$USER_BIN" != "0" ]; then
    # Отсекаем максимум 8 символов для точной проверки
    BIN_8="$(echo "$USER_BIN" | cut -c1-8)"
    
    case "$BIN_8" in
        *[!0-9]*)
            ui_print "[!] Ошибка: BIN должен состоять только из цифр!"
            ;;
        *)
            ui_print "[*] Анализирую BIN: $BIN_8"
            TARGET_ISO=""
            
            # 1. Быстрые локальные правила (работают без интернета)
            case "$BIN_8" in
                53787211*) TARGET_ISO="kz" ;; # Пример: Bybit (Казахстан)
                537872*)   TARGET_ISO="us" ;; # Пример: Префикс Interaudi (США)
            esac
            
            # 2. Онлайн-запрос к API (Используем ://handyapi.com с поддержкой 8-значных BIN)
            if [ -z "$TARGET_ISO" ]; then
                ui_print "[*] Запрашиваю онлайн-базу..."
                RESPONSE="$(
                    curl -fsSL \
                        --connect-timeout 5 \
                        --max-time 10 \
                        "https://data.handyapi.com/bin/$BIN_8" \
                        2>/dev/null
                )"
                
                if [ -n "$RESPONSE" ]; then
                    # Извлекаем ISO код страны из ключа "A2", переводим в нижний регистр
                    TARGET_ISO="$(echo "$RESPONSE" | sed -n 's/.*"A2"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr '[:upper:]' '[:lower:]')"
                else
                    ui_print "[!] Сервер API недоступен или отсутствует подключение к сети."
                fi
            fi
            
            # 3. Поиск извлеченной страны в carriers.db
            if [ -n "$TARGET_ISO" ]; then
                MATCH_LINE="$(sed -n "/:${TARGET_ISO}:/p" "$CARRIERS_DB" | head -n 1)"
                if [ -n "$MATCH_LINE" ]; then
                    SELECTED_CARRIER="$(echo "$MATCH_LINE" | cut -d':' -f1)"
                    ui_print "[+] Автоподбор успешен! Регион карты: $TARGET_ISO"
                else
                    ui_print "[!] Страна '$TARGET_ISO' определена, но её оператора нет в базе."
                    ui_print "[*] Автоматически применяю Латвию (Профиль 1)."
                    SELECTED_CARRIER=1
                fi
            else
                ui_print "[!] Не удалось определить регион карты по BIN."
            fi
            ;;
    esac
fi

# ============================================================
# ШАГ 2: РЕЗЕРВНЫЙ РЕЖИМ (ВЫБОР КНОПКАМИ ГРОМКОСТИ)
# ============================================================
# Активируется, если пользователь пропустил ввод BIN или автоподбор не удался
if [ -z "$SELECTED_CARRIER" ]; then
    ui_print " "
    ui_print "[*] Включаю ручной выбор профиля..."
    ui_print " [Громкость МИНУС] — Следующий пункт"
    ui_print " [Громкость ПЛЮС]  — Подтвердить выбор"
    ui_print " "

    MENU_INDEX=0
    TOTAL_STATES=$((TOTAL_CARRIERS + 1))

    while true; do
        if [ "$MENU_INDEX" -eq 0 ]; then
            CURRENT_NAME="Оригинальные значения (Без спуфинга)"
        else
            # Ищем строку строго по начальному ID профиля
            LINE="$(sed -n "/^${MENU_INDEX}:/p" "$CARRIERS_DB" | head -n 1)"
            if [ -n "$LINE" ]; then
                CURRENT_NAME="$(printf '%s\n' "$LINE" | cut -d':' -f4)"
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
            SELECTED_CARRIER="$MENU_INDEX"
            break
        else
            MENU_INDEX=$(( (MENU_INDEX + 1) % TOTAL_STATES ))
        fi
    done
fi

# ============================================================
# ШАГ 3: СОХРАНЕНИЕ КОНФИГУРАЦИИ И ЗАВЕРШЕНИЕ УСТАНОВКИ
# ============================================================
# Надежная фиксация выбранного состояния в settings
printf 'selected_carrier=%s\n' "$SELECTED_CARRIER" > "$MODPATH/settings"
chmod 0600 "$MODPATH/settings"
chmod 0600 "$CARRIERS_DB"

# Назначаем права на исполнение остальным скриптам модуля
chmod 0755 "$MODPATH/service.sh" 2>/dev/null
chmod 0755 "$MODPATH/action.sh" 2>/dev/null
chmod 0755 "$MODPATH/status.sh" 2>/dev/null

ui_print "==================================="
ui_print "✅ Модуль настроен на профиль [$SELECTED_CARRIER]"
ui_print "[*] Сам BIN карты никуда не сохранен."
ui_print "[*] GPay Spoofer успешно установлен!"
ui_print "==================================="
