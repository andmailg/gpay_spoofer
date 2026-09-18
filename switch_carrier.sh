#!/system/bin/sh
# switch_carrier.sh — Выбор профиля при нажатии Action в Magisk
# Кнопки громкости переключают профили, кнопка питания подтверждает

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
ui_print "Громкость ВВЕРХ / ВНИЗ — переключить"
ui_print "Кнопка питания — подтвердить"
ui_print ""

# Текущий профиль
CURRENT=$(grep "^selected_carrier=" "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | tr -d '[:space:]')
CURRENT=${CURRENT:-0}
PROFILE=$CURRENT

ui_print "Текущий: Профиль $PROFILE"
ui_print ""

# === Ищем устройство ввода через getevent ===
EVENT_FILE=""
if command -v getevent >/dev/null 2>&1; then
    EVENT_FILE=$(getevent -p 2>/dev/null | grep -B1 "key 0074" | grep "/dev/input" | head -1 | awk '{print $1}')
fi

if [ -z "$EVENT_FILE" ] || [ ! -e "$EVENT_FILE" ]; then
    for i in $(seq 0 15); do
        ev="/dev/input/event$i"
        if [ -e "$ev" ]; then
            EVENT_FILE="$ev"
            break
        fi
    done
fi

if [ -z "$EVENT_FILE" ]; then
    ui_print "⚠️ Устройства ввода не найдены"
    ui_print "Используем профиль: $PROFILE"
else
    ui_print "Устройство: $EVENT_FILE"
    ui_print "Ожидание нажатий..."
    ui_print ""

    while true; do
        EVENT=$(dd if="$EVENT_FILE" bs=64 count=1 2>/dev/null | od -A n -t x1 | tr -d ' \n')

        TYPE="${EVENT:32:8}"
        CODE="${EVENT:40:8}"

        TYPE_DEC=$((16#${TYPE}))
        CODE_DEC=$((16#${CODE}))

        # type=1 (клавиша)
        if [ "$TYPE_DEC" -eq 1 ]; then
            case "$CODE_DEC" in
                115)
                    # Volume UP — следующий
                    PROFILE=$(( (PROFILE + 1) % 3 ))
                    ui_print "  → Профиль $PROFILE"
                    ;;
                114)
                    # Volume DOWN — предыдущий
                    PROFILE=$(( (PROFILE - 1 + 3) % 3 ))
                    ui_print "  → Профиль $PROFILE"
                    ;;
                116)
                    # Power — подтвердить
                    ui_print ""
                    ui_print "✅ Профиль $PROFILE подтверждён"
                    break
                    ;;
            esac
        fi
    done
fi

# === Запись профиля (исправлено: убран текстовый заголовок, нарушавший парсинг) ===
case "$PROFILE" in
    0) NAME="Latvijas Mobilais (Latvia)" ;;
    1) NAME="AT&T (USA)" ;;
    2) NAME="T-Mobile (USA)" ;;
esac

echo "selected_carrier=$PROFILE" > "$SETTINGS"

ui_print ""
ui_print "========================================"
ui_print "  Профиль: $PROFILE"
ui_print "  Оператор: $NAME"
ui_print "========================================"
ui_print ""
ui_print "Готово! Перезагрузите устройство."