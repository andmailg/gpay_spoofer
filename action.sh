#!/system/bin/sh
# action.sh — Надежный выбор профиля через кнопки громкости и питания

MODDIR="${1:-${0%/*}}"
SETTINGS="$MODDIR/settings"
[ ! -d "$MODDIR" ] && mkdir -p "$MODDIR"

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

# Поиск устройства ввода с поддержкой клавиш
EVENT_FILE=""
for ev in /dev/input/event*; do
    if [ -e "$ev" ]; then
        if getevent -p "$ev" 2>/dev/null | grep -q "0114\|0115\|0116"; then
            EVENT_FILE="$ev"
            break
        fi
    fi
done

if [ -z "$EVENT_FILE" ]; then
    for i in $(seq 0 15); do
        if [ -e "/dev/input/event$i" ]; then
            EVENT_FILE="/dev/input/event$i"
            break
        fi
    done
fi

if [ -z "$EVENT_FILE" ] || [ ! -e "$EVENT_FILE" ]; then
    ui_print "⚠️ Устройства ввода не найдены!"
    ui_print "Используется текущий профиль: $PROFILE"
else
    ui_print "Устройство: $EVENT_FILE"
    ui_print "Ожидание нажатий (30 сек таймаут)..."
    ui_print ""

    start_time=$(date +%s)
    
    # Читаем getevent напрямую в цикле без использования файлов и tail, чтобы избежать багов сабшеллов
    getevent -lt "$EVENT_FILE" 2>/dev/null | while read -r line; do
        case "$line" in
            *KEY_VOLUMEUP*DOWN*)
                PROFILE=$(( (PROFILE + 1) % 3 ))
                ui_print "  → Профиль $PROFILE"
                echo "$PROFILE" > "$MODDIR/.tmp_profile"
                ;;
            *KEY_VOLUMEDOWN*DOWN*)
                PROFILE=$(( (PROFILE - 1 + 3) % 3 ))
                ui_print "  → Профиль $PROFILE"
                echo "$PROFILE" > "$MODDIR/.tmp_profile"
                ;;
            *KEY_POWER*DOWN*)
                ui_print ""
                ui_print "✅ Профиль $PROFILE подтверждён"
                echo "$PROFILE" > "$MODDIR/.tmp_profile"
                break
                ;;
        esac

        current_time=$(date +%s)
        if [ $((current_time - start_time)) -gt 30 ]; then
            ui_print ""
            ui_print "⏱ Время истекло. Сохранен профиль $PROFILE"
            break
        fi
    done &
    
    EVENT_PID=$!
    
    # Ожидание завершения фонового процесса с таймаутом
    i=0
    while [ $i -lt 31 ] && [ -d "/proc/$EVENT_PID" ]; do
        sleep 1
        i=$((i + 1))
    done
    
    # Жестко гасим getevent, если он еще висит
    kill $EVENT_PID 2>/dev/null
    wait $EVENT_PID 2>/dev/null

    if [ -f "$MODDIR/.tmp_profile" ]; then
        PROFILE=$(cat "$MODDIR/.tmp_profile")
        rm -f "$MODDIR/.tmp_profile"
    fi
fi

# Запись профиля в финальный settings
case "$PROFILE" in
    0) NAME="Latvijas Mobilais (Latvia)" ;;
    1) NAME="AT&T (USA)" ;;
    2) NAME="T-Mobile (USA)" ;;
    *) PROFILE=0; NAME="Latvijas Mobilais (Latvia)" ;;
esac

echo "selected_carrier=$PROFILE" > "$SETTINGS"

ui_print ""
ui_print "========================================"
ui_print "  Профиль: $PROFILE"
ui_print "  Оператор: $NAME"
ui_print "========================================"
ui_print ""
ui_print "Готово!"