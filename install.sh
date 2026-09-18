#!/system/bin/sh
# install.sh — Выбор профиля при установке модуля (кнопки громкости)

MODDIR="/data/adb/modules/GPay-Spoofer"
SETTINGS="$MODDIR/settings"

ui_print "========================================"
ui_print "  GPay-Spoofer — Выбор профиля"
ui_print "========================================"
ui_print ""
ui_print "Профиль 0: RU → Latvia (GPay)"
ui_print "Профиль 1: RU → AT&T  (Звонки)"
ui_print "Профиль 2: RU → T-Mobile (Общий)"
ui_print ""
ui_print "Громкость ВВЕРХ — следующий"
ui_print "Громкость ВНИЗ — предыдущий"
ui_print "Нажатие кнопки питания — подтвердить"
ui_print ""

# === Функция чтения событий ввода ===
find_volume_key() {
    # Volume Up = 115, Volume Down = 114
    for ev in /dev/input/event*; do
        if [ -r "$ev" ]; then
            # Ищем событие громкости (код 114 или 115, type=1=ключ)
            if dd if="$ev" bs=64 count=1 2>/dev/null | od -A n -t x1 | grep -q "0001 007[45]"; then
                echo "$ev"
                return 0
            fi
        fi
    done
    return 1
}

# === Находим event-устройство для громкости ===
EVENT_FILE=""
for i in $(seq 0 15); do
    ev="/dev/input/event$i"
    if [ -e "$ev" ] && [ -r "$ev" ]; then
        # Проверяем, есть ли в устройстве клавиши громкости
        if cat "$ev" 2>/dev/null | od -A n -t x1 | head -c 2048 | grep -q "0001 007[45]"; then
            EVENT_FILE="$ev"
            break
        fi
    fi
done

# Если не нашли через чтение — пробуем открыть любое доступное
if [ -z "$EVENT_FILE" ]; then
    for i in $(seq 0 15); do
        ev="/dev/input/event$i"
        if [ -e "$ev" ] && [ -r "$ev" ]; then
            EVENT_FILE="$ev"
            break
        fi
    done
fi

# === Цикл выбора профиля ===
PROFILE=0
MAX_PROFILE=2

if [ -n "$EVENT_FILE" ]; then
    ui_print "📡 Обнаружено устройство ввода: $EVENT_FILE"
    ui_print "Ожидание нажатия кнопки громкости..."
    ui_print ""

    # Читаем события по одному (64 байта = структура input_event)
    while true; do
        # Читаем одно событие (64 байта)
        EVENT=$(dd if="$EVENT_FILE" bs=64 count=1 2>/dev/null | od -A n -t x1 | tr -d ' \n')

        # Парсим: смещение 16-19 = time_sec, 20-23 = time_usec, 24-27 = type, 28-31 = code
        # type=0x01 (ключ), code=0x74 (volume down) или 0x75 (volume up)
        TYPE="${EVENT:48:8}"
        CODE="${EVENT:56:8}"

        # Преобразуем в десятичные
        TYPE_DEC=$((16#${TYPE}))
        CODE_DEC=$((16#${CODE}))

        if [ "$TYPE_DEC" -eq 1 ]; then
            if [ "$CODE_DEC" -eq 117 ]; then
                # Power button — подтвердить
                ui_print "✅ Профиль $PROFILE подтверждён"
                break
            elif [ "$CODE_DEC" -eq 115 ]; then
                # Volume UP — следующий
                PROFILE=$(( (PROFILE + 1) % (MAX_PROFILE + 1) ))
                ui_print "  → Выбран: Профиль $PROFILE"
            elif [ "$CODE_DEC" -eq 114 ]; then
                # Volume DOWN — предыдущий
                PROFILE=$(( (PROFILE - 1 + MAX_PROFILE + 1) % (MAX_PROFILE + 1) ))
                ui_print "  → Выбран: Профиль $PROFILE"
            fi
        fi
    done
else
    ui_print "⚠️ Устройство ввода не найдено"
    ui_print "Используется профиль по умолчанию: $PROFILE"
fi

# === Запись выбранного профиля ===
ui_print ""
ui_print "Запись профиля $PROFILE в settings..."

# Профили
case "$PROFILE" in
    0)
        SELECTED_ID="0"
        SELECTED_NAME="Latvijas Mobilais (Latvia)"
        ;;
    1)
        SELECTED_ID="1"
        SELECTED_NAME="AT&T (USA)"
        ;;
    2)
        SELECTED_ID="2"
        SELECTED_NAME="T-Mobile (USA)"
        ;;
esac

# Создаём settings с выбранным профилем
cat > "$SETTINGS" <<EOF
[Выбор оператора]
selected_carrier=$SELECTED_ID
EOF

ui_print ""
ui_print "========================================"
ui_print "  Профиль: $PROFILE"
ui_print "  Оператор: $SELECTED_NAME"
ui_print "========================================"
ui_print ""
ui_print "Модуль установлен!"
ui_print "Перезагрузите устройство."
