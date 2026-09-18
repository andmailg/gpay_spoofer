#!/system/bin/sh
# action.sh — Надежный выбор профиля через кнопки громкости и питания

# Если передан аргумент из install.sh, используем его, иначе определяем сами
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

    # Сохраняем текущий профиль во временный файл на случай таймаута
    echo "$PROFILE" > "$MODDIR/.tmp_profile"

    start_time=$(date +%s)
    
    # Читаем события через cat/getevent в цикле с дескриптором, чтобы избежать сабшеллов
    # Или используем простой обход с чтением в файл внутри цикла
    getevent -lt "$EVENT_FILE" 2>/dev/null | while read -r line; do
        # Читаем актуальный профиль из файла, если он менялся
        if [ -f "$MODDIR/.tmp_profile" ]; then
            PROFILE=$(cat "$MODDIR/.tmp_profile")
        fi

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
    done

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
ui_print "Готово! Перезагрузите устройство."