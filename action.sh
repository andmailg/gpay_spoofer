#!/system/bin/sh

# ============================================================
# GPay Spoofer — action.sh (Интерактивный терминальный режим)
# ============================================================

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
PROPS_FILE="$MODDIR/original_props"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="/sdcard/Gpay-Spoofer.log"

# --- Считаем количество доступных операторов в базе ---
TOTAL_CARRIERS=0
if [ -f "$CARRIERS_DB" ]; then
    TOTAL_CARRIERS="$(sed '/^\s*$/d' "$CARRIERS_DB" | wc -l | tr -d ' ')"
fi
[ -z "$TOTAL_CARRIERS" ] || [ "$TOTAL_CARRIERS" -lt 1 ] && TOTAL_CARRIERS=0
TOTAL_STATES=$((TOTAL_CARRIERS + 1))

SELECTED_CARRIER=""
ARGUMENT="$(echo "$1" | tr -d ' ' | tr -d '-')"

# ============================================================
# РАЗБОР АРГУМЕНТОВ (Запуск из Терминала / Termux)
# ============================================================
if [ -n "$ARGUMENT" ]; then
    case "$ARGUMENT" in
        # Сценарий А: Передан конкретный номер профиля
        [0-9]|[0-9][0-9])
            if [ "$ARGUMENT" -lt "$TOTAL_STATES" ]; then
                SELECTED_CARRIER="$ARGUMENT"
                echo "[*] Получена команда: принудительно включить профиль [$SELECTED_CARRIER]"
            else
                echo "❌ Ошибка: В базе всего $TOTAL_CARRIERS операторов. Профиля $ARGUMENT не существует."
                exit 1
            fi
            ;;
        # Сценарий Б: Передан BIN карты (длина 6 и более цифр)
        [0-9][0-9][0-9][0-9][0-9][0-9]*)
            BIN_8="$(echo "$ARGUMENT" | cut -c1-8)"
            echo "=================================================="
            echo "🔍 РЕЖИМ ОДНОКРАТНОГО ОПРЕДЕЛЕНИЯ BIN: $BIN_8"
            echo "=================================================="
            
            TARGET_ISO=""
            # 1. Локальные правила (для быстрого ответа без интернета)
            case "$BIN_8" in
                53787211*) TARGET_ISO="kz" ;; # Карты Bybit (Казахстан)
                537872*)   TARGET_ISO="us" ;; # Старый макро-BIN Interaudi Bank (США)
            esac
            
            # 2. Онлайн-запрос (Используем ://handyapi.com с поддержкой до 8 цифр)
            if [ -z "$TARGET_ISO" ]; then
                echo "[*] Запрашиваю онлайн-базу для BIN $BIN_8..."

                RESPONSE="$(
                    curl -fsSL \
                        --connect-timeout 5 \
                        --max-time 10 \
                        "https://data.handyapi.com/bin/$BIN_8" \
                        2>/dev/null
                )"

                TARGET_ISO="$(
                    echo "$RESPONSE" |
                    sed -n 's/.*"A2"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
                    tr '[:upper:]' '[:lower:]'
                )"

                if [ -z "$TARGET_ISO" ]; then
                    echo "[!] Не удалось получить код страны из ответа API"
                    echo "[!] Ответ: $RESPONSE"
                fi
            fi
            
            # 3. Ищем соответствие в базе данных операторов
            if [ -n "$TARGET_ISO" ]; then
                MATCH_LINE="$(sed -n "/:${TARGET_ISO}:/p" "$CARRIERS_DB" | head -n 1)"
                if [ -n "$MATCH_LINE" ]; then
                    SELECTED_CARRIER="$(echo "$MATCH_LINE" | cut -d':' -f1)"
                    echo "✅ BIN успешно определен! Страна: $TARGET_ISO"
                else
                    echo "[!] Страна карты '$TARGET_ISO' найдена, но оператора нет в carriers.db."
                    echo "💡 Применяю универсальную Латвию (Профиль 1)."
                    SELECTED_CARRIER=1
                fi
            else
                echo "❌ Ошибка: Не удалось определить регион карты онлайн."
                exit 1
            fi
            ;;
        *)
            echo "❌ Ошибка: Неверный аргумент. Передайте номер профиля (например, 4) или BIN (например, 53787211)"
            exit 1
            ;;
    esac
fi

# ============================================================
# РЕЖИМ ОБЫЧНОГО КЛИКА (Кнопка Action в менеджере Magisk)
# ============================================================
if [ -z "$SELECTED_CARRIER" ]; then
    CURRENT="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"
    case "$CURRENT" in
        *[!0-9]*|"") CURRENT=0 ;;
    esac
    SELECTED_CARRIER=$(( (CURRENT + 1) % TOTAL_STATES ))
fi

# --- Считываем параметры выбранного оператора ---
TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_NAME=""

if [ "$SELECTED_CARRIER" -eq 0 ]; then
    TARGET_NAME="Оригинальные значения (Сброс)"
    if [ -f "$PROPS_FILE" ]; then
        . "$PROPS_FILE"
        TARGET_NUMERIC="$ORIG_NUMERIC"
        TARGET_ISO="$ORIG_ISO"
    fi
    [ -z "$TARGET_NUMERIC" ] && TARGET_NUMERIC="$(getprop gsm.operator.numeric)"
    [ -z "$TARGET_ISO" ] && TARGET_ISO="$(getprop gsm.operator.iso-country)"
else
    if [ -f "$CARRIERS_DB" ]; then
        LINE="$(sed -n "/^${SELECTED_CARRIER}:/p" "$CARRIERS_DB" | head -n 1)"
        if [ -n "$LINE" ]; then
            IFS=":" read -r _ TARGET_NUMERIC TARGET_ISO TARGET_NAME << EOF
$LINE
EOF
        fi
    fi
fi

if [ -z "$TARGET_NAME" ]; then
    echo "Ошибка: Не удалось прочитать профиль $SELECTED_CARRIER из базы данных!"
    exit 1
fi

# --- Сохраняем состояние в settings ---
echo "selected_carrier=$SELECTED_CARRIER" > "$SETTINGS"
chmod 0600 "$SETTINGS"

# --- Прописываем значения через resetprop ---
if [ -n "$TARGET_NUMERIC" ] && [ -n "$TARGET_ISO" ]; then
    for suffix in "" ".1" ".2"; do
        resetprop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
        resetprop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
    done
    resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
    resetprop "gsm.operator.iso-country" "$TARGET_ISO"
    resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"
fi

# --- Логируем операцию ---
if [ -d "/sdcard" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Activated Profile: $SELECTED_CARRIER ($TARGET_NAME) | Target ISO: $TARGET_ISO" >> "$LOGFILE" 2>/dev/null
fi

# --- Вывод интерфейса (Карта доступных профилей) ---
echo "=================================================="
echo "          ТЕКУЩИЙ СТАТУС МОДУЛЯ                   "
echo "=================================================="
[ "$SELECTED_CARRIER" -eq 0 ] && echo "--> Оригинальные значения (Без спуфинга)" || echo "    Оригинальные значения (Без спуфинга)"

if [ -f "$CARRIERS_DB" ]; then
    while IFS=":" read -r id numeric iso name; do
        [ -z "$id" ] && continue
        if [ "$id" -eq "$SELECTED_CARRIER" ]; then
            echo "--> [$id] $name"
        else
            echo "    [$id] $name"
        fi
    done < "$CARRIERS_DB"
fi
echo "=================================================="
echo "🔄 Обновляю конфигурацию системы..."

# --- Фоновый перезапуск service.sh ---
rm -f "/data/adb/gpay-spoofer.lock"
sh "$MODDIR/service.sh" >/dev/null 2>&1 &

# --- Форсированная очистка кэша Google ---
am force-stop com.android.vending >/dev/null 2>&1
am force-stop com.google.android.apps.walletnfcrel >/dev/null 2>&1
pm trim-caches 999G >/dev/null 2>&1

echo "=================================================="
echo "✅ Успешно применен профиль [$SELECTED_CARRIER]"
echo "Текущий оператор: $TARGET_NAME"
echo "Кэш очищен. Можете открывать Google Wallet!"
echo "=================================================="
