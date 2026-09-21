#!/system/bin/sh
# GPay Spoofer — action.sh (Интерактивный терминальный режим)

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
PROPS_FILE="$MODDIR/original_props"
CARRIERS_DB="$MODDIR/carriers.db"
LOGFILE="$MODDIR/Gpay-Spoofer.log"
BIN_CACHE="$MODDIR/my_card.bin.cache"

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
# РАЗБОР АРГУМЕНТОВ (Передан конкретный профиль или новый BIN)
# ============================================================
if [ -n "$ARGUMENT" ]; then
    case "$ARGUMENT" in
        # Сценарий А: Передан конкретный номер профиля (сбрасывает кэш карты)
        [0-9]|[0-9][0-9])
            if [ "$ARGUMENT" -lt "$TOTAL_STATES" ]; then
                SELECTED_CARRIER="$ARGUMENT"
                rm -f "$BIN_CACHE"
                echo "[*] Получена команда: принудительный профиль [$SELECTED_CARRIER]. Кэш BIN сброшен."
            else
                echo "❌ Ошибка: Профиля $ARGUMENT не существует."
                exit 1
            fi
            ;;
        # Сценарий Б: Передан BIN карты (длина 6 и более цифр)
        [0-9][0-9][0-9][0-9][0-9][0-9]*)
            BIN_8="$(echo "$ARGUMENT" | cut -c1-8)"
            echo "=================================================="
            echo "🔍 АНАЛИЗ И ЗАПИСЬ НОВОГО BIN: $BIN_8"
            echo "=================================================="
            
            TARGET_ISO=""
            # 1. Локальные правила (без интернета)
            case "$BIN_8" in
                53787211*) TARGET_ISO="kz" ;;
                537872*)   TARGET_ISO="us" ;;
            esac
            
            # 2. Онлайн-запрос
            if [ -z "$TARGET_ISO" ]; then
                echo "[*] Запрашиваю онлайн-базу для BIN $BIN_8..."
                RESPONSE="$(curl -fsSL --connect-timeout 5 --max-time 10 "https://data.handyapi.com/bin/$BIN_8" 2>/dev/null)"
                TARGET_ISO="$(echo "$RESPONSE" | sed -n 's/.*"A2"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr '[:upper:]' '[:lower:]')"
            fi
            
            # 3. Обработка результата и сохранение кэша
            if [ -n "$TARGET_ISO" ]; then
                echo "✅ Регион карты успешно определен: $TARGET_ISO"
                echo "$BIN_8:$TARGET_ISO" > "$BIN_CACHE"
                chmod 0600 "$BIN_CACHE"
                
                # Ищем под него оператора
                MATCH_LINE="$(sed -n "/:${TARGET_ISO}:/p" "$CARRIERS_DB" | head -n 1)"
                if [ -n "$MATCH_LINE" ]; then
                    SELECTED_CARRIER="$(echo "$MATCH_LINE" | cut -d':' -f1)"
                else
                    echo "[!] Оператор для '$TARGET_ISO' отсутствует в базе. Применяю Латвию (1)."
                    SELECTED_CARRIER=1
                fi
            else
                echo "❌ Ошибка: Не удалось определить регион карты онлайн."
                exit 1
            fi
            ;;
        *)
            echo "❌ Ошибка: Неверный аргумент."
            exit 1
            ;;
    esac
fi

# ============================================================
# РЕЖИМ ОБЫЧНОГО КЛИКА (Кнопка Action или вызов без параметров)
# ============================================================
if [ -z "$SELECTED_CARRIER" ]; then
    # Если есть кэш BIN, динамически восстанавливаем привязку к нему
    if [ -f "$BIN_CACHE" ]; then
        CACHED_ISO="$(cut -d':' -f2 "$BIN_CACHE" 2>/dev/null)"
        CACHED_BIN="$(cut -d':' -f1 "$BIN_CACHE" 2>/dev/null)"
        if [ -n "$CACHED_ISO" ]; then
            echo "[*] Обнаружена привязка к карте (BIN: $CACHED_BIN, Страна: $CACHED_ISO)"
            MATCH_LINE="$(sed -n "/:${CACHED_ISO}:/p" "$CARRIERS_DB" | head -n 1)"
            if [ -n "$MATCH_LINE" ]; then
                SELECTED_CARRIER="$(echo "$MATCH_LINE" | cut -d':' -f1)"
            else
                SELECTED_CARRIER=1
            fi
        fi
    fi
    
    # Если кэша нет или он поврежден — работаем по стандартному циклическому переключению
    if [ -z "$SELECTED_CARRIER" ]; then
        CURRENT="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"
        case "$CURRENT" in *[!0-9]*|"") CURRENT=0 ;; esac
        SELECTED_CARRIER=$(( (CURRENT + 1) % TOTAL_STATES ))
    fi
fi

# --- Чтение параметров выбранного оператора ---
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
            TARGET_NUMERIC=$(echo "$LINE" | cut -d':' -f2)
            TARGET_ISO=$(echo "$LINE" | cut -d':' -f3)
            TARGET_NAME=$(echo "$LINE" | cut -d':' -f4)
        fi
    fi
fi

if [ -z "$TARGET_NAME" ]; then
    echo "❌ Ошибка: Профиль не найден в базе!"
    exit 1
fi

# --- Сохранение состояния ---
echo "selected_carrier=$SELECTED_CARRIER" > "$SETTINGS"
chmod 0600 "$SETTINGS"

# --- Применение resetprop ---
if [ -n "$TARGET_NUMERIC" ] && [ -n "$TARGET_ISO" ]; then
    for suffix in "" ".1" ".2"; do
        resetprop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
        resetprop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
    done
    resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
    resetprop "gsm.operator.iso-country" "$TARGET_ISO"
    resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"
fi

# --- Логирование ---
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Activated Profile: $SELECTED_CARRIER ($TARGET_NAME)" >> "$LOGFILE" 2>/dev/null

# --- Интерфейс вывода ---
echo "=================================================="
echo "          ТЕКУЩИЙ СТАТУС МОДУЛЯ                   "
echo "=================================================="
[ -f "$BIN_CACHE" ] && echo "💳 Привязан BIN: $(cut -d':' -f1 "$BIN_CACHE") ($(cut -d':' -f2 "$BIN_CACHE" | tr '[:lower:]' '[:upper:]'))"
echo "--------------------------------------------------"
[ "$SELECTED_CARRIER" -eq 0 ] && echo "--> Оригинальные значения" || echo "    Оригинальные значения"

if [ -f "$CARRIERS_DB" ]; then
    while IFS=":" read -r id numeric iso name; do
        [ -z "$id" ] && continue
        [ "$id" -eq "$SELECTED_CARRIER" ] && echo "--> [$id] $name" || echo "    [$id] $name"
    done < "$CARRIERS_DB"
fi
echo "=================================================="
echo "🔄 Обновляю конфигурацию системы..."

rm -f "/data/adb/gpay-spoofer.lock"
sh "$MODDIR/service.sh" >/dev/null 2>&1 &

am force-stop com.android.vending >/dev/null 2>&1
am force-stop com.google.android.apps.walletnfcrel >/dev/null 2>&1
pm trim-caches 999G >/dev/null 2>&1

echo "=================================================="
echo "✅ Успешно применен профиль [$SELECTED_CARRIER]"
echo "Текущий оператор: $TARGET_NAME"
echo "=================================================="
