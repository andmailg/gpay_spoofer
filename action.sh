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
# РАЗБОР АРГУМЕНТОВ (Если скрипт запущен из Терминала/Termux)
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
            # 1. Локальное правило для вашего BIN
            case "$BIN_8" in
                53787211*|537872*) TARGET_ISO="lv" ;;
            esac
            
            # 2. Онлайн-запрос (данные в файл не сохраняются)
            if [ -z "$TARGET_ISO" ]; then
                echo "[*] Запрашиваю онлайн-базу..."
                BIN_6="$(echo "$BIN_8" | cut -c1-6)"
                RESPONSE="$(curl -s "https://handyapi.com" 2>/dev/null)"
                TARGET_ISO="$(echo "$RESPONSE" | sed -n 's/.*"CountryCode":\s*"\([^"]*\)".*/\1/p' | tr '[:upper:]' '[:lower:]')"
            fi
            
            # 3. Ищем соответствие в базе
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
# РЕЖИМ ОБЫЧНОГО КЛИКА (Если запущено кнопкой Action из Magisk)
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
TMPFILE="$SETTINGS.tmp.$$"
printf 'selected_carrier=%s\n' "$SELECTED_CARRIER" > "$TMPFILE"
chmod 0600 "$TMPFILE"
mv -f "$TMPFILE" "$SETTINGS"
chmod 0600 "$SETTINGS"

# --- Прописываем значения через resetprop ---
if [ -n "$TARGET_NUMERIC" ] && [ -n "$TARGET_ISO" ]; then
    resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
    resetprop "gsm.operator.iso-country" "$TARGET_ISO"
    resetprop "gsm.sim.operator.numeric" "$TARGET_NUMERIC"
    resetprop "gsm.sim.operator.iso-country" "$TARGET_ISO"
    resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"

    resetprop "gsm.sim.operator.numeric.1" "$TARGET_NUMERIC"
    resetprop "gsm.sim.operator.iso-country.1" "$TARGET_ISO"
    resetprop "gsm.sim.operator.numeric.2" "$TARGET_NUMERIC"
    resetprop "gsm.sim.operator.iso-country.2" "$TARGET_ISO"
fi

# --- Логируем операцию в файл на SD-карте ---
if [ -d "/sdcard" ]; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Activated Profile: $SELECTED_CARRIER ($TARGET_NAME) | Target ISO: $TARGET_ISO" >> "$LOGFILE"
    chmod 0600 "$LOGFILE"
fi

# --- Вывод интерфейса (карты профилей) ---
echo "=================================================="
echo "          ТЕКУЩИЙ СТАТУС МОДУЛЯ                   "
echo "=================================================="
if [ "$SELECTED_CARRIER" -eq 0 ]; then
    echo "--> Оригинальные значения (Без спуфинга)"
else
    echo "    Оригинальные значения (Без спуфинга)"
fi

i=1
while [ "$i" -le "$TOTAL_CARRIERS" ]; do
    if [ -f "$CARRIERS_DB" ]; then
        DB_LINE="$(sed -n "/^${i}:/p" "$CARRIERS_DB" | head -n 1)"
        if [ -n "$DB_LINE" ]; then
            IFS=":" read -r _ _ _ DB_NAME << EOF
$DB_LINE
EOF
            if [ "$i" -eq "$SELECTED_CARRIER" ]; then
                echo "--> [$i] $DB_NAME"
            else
                echo "    [$i] $DB_NAME"
            fi
        fi
    fi
    i=$((i + 1))
done
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
