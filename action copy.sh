#!/system/bin/sh

# ============================================================
# GPay Spoofer — action.sh (С выводом карты профилей)
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

# Общее количество состояний = операторы + профиль "0"
TOTAL_STATES=$((TOTAL_CARRIERS + 1))

# --- Читаем текущий профиль ---
CURRENT="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"
case "$CURRENT" in
    *[!0-9]*|"") CURRENT=0 ;;
esac

# Циклически переключаем на следующий индекс
SELECTED_CARRIER=$(( (CURRENT + 1) % TOTAL_STATES ))

TARGET_NUMERIC=""
TARGET_ISO=""
TARGET_NAME=""

# --- Определяем целевые значения ---
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

# --- Записываем новый профиль в settings ---
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

# --- Логируем текущее состояние в файл ---
if [ -d "/sdcard" ]; then
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Profile changed via Action: $SELECTED_CARRIER — $TARGET_NAME"
        echo "Real SIM ISO: $(getprop gsm.sim.operator.iso-country 2>/dev/null)"
        echo "Real operator ISO: $(getprop gsm.operator.iso-country 2>/dev/null)"
    } >> "$LOGFILE"
    chmod 0600 "$LOGFILE"
fi

# --- Вывод интерфейса (карты профилей) для Magisk Manager ---
echo "=================================================="
echo "          СПИСОК ДОСТУПНЫХ ПРОФИЛЕЙ               "
echo "=================================================="

# Выводим профиль 0
if [ "$SELECTED_CARRIER" -eq 0 ]; then
    echo "--> [0] Оригинальные значения (Без спуфинга)"
else
    echo "    [0] Оригинальные значения (Без спуфинга)"
fi

# Динамически выводим все профили из базы данных
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
echo "🔄 Обновляю свойства в системе..."

# --- Фоновый запуск service.sh ---
rm -f "/data/adb/gpay-spoofer.lock"
sh "$MODDIR/service.sh" >/dev/null 2>&1 &

echo "✅ Успешно переключено на профиль [$SELECTED_CARRIER]"
echo "Прямо сейчас применен: $TARGET_NAME"
