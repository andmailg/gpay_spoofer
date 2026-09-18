#!/system/bin/sh
# action.sh — Выбор профиля через кнопки громкости и питания
# Исправления: getevent -ql, FIFO для чтения в главном процессе (не subshell),
#              таймаут 30с, атомарная запись, валидация, trap cleanup

MODDIR="${1:-${0%/*}}"
SETTINGS="$MODDIR/settings"
TMP_SETTINGS="$MODDIR/settings.tmp.$$"
TMP_PROFILE="$MODDIR/.tmp_profile.$$"
FIFO="$MODDIR/.event_fifo.$$"
LOCKFILE="$MODDIR/.action.lock"

# --- Блокировка: не запускать дважды ---
if [ -e "$LOCKFILE" ]; then
    for _lock in 1 2 3 4 5; do
        if [ ! -e "$LOCKFILE" ]; then break; fi
        sleep 1
    done
    if [ -e "$LOCKFILE" ]; then
        ui_print "⚠️ Другой экземпляр action.sh уже запущен."
        exit 1
    fi
fi
touch "$LOCKFILE"

# --- Trap: очистка при любом выходе ---
cleanup() {
    if [ -n "$GETEVENT_PID" ] && [ -d "/proc/$GETEVENT_PID" ]; then
        kill "$GETEVENT_PID" 2>/dev/null
        wait "$GETEVENT_PID" 2>/dev/null
    fi
    rm -f "$FIFO" "$TMP_PROFILE" "$LOCKFILE"
}
trap cleanup EXIT INT TERM HUP

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

# --- Чтение текущего профиля с валидацией ---
CURRENT=""
if [ -r "$SETTINGS" ]; then
    CURRENT=$(grep "^selected_carrier=" "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | tr -d '[:space:]')
fi
case "$CURRENT" in
    0|1|2) ;;
    *) CURRENT=0 ;;
esac
PROFILE=$CURRENT

ui_print "Текущий: Профиль $PROFILE"
ui_print ""

# --- Создание FIFO ---
rm -f "$FIFO"
mkfifo "$FIFO" 2>/dev/null
if [ ! -p "$FIFO" ]; then
    ui_print "⚠️ Не удалось создать FIFO, используем профиль по умолчанию"
    PROFILE=0
else
    # --- Запуск getevent -ql в фоне (stdin из /dev/null) ---
    getevent -ql < /dev/null > "$FIFO" 2>/dev/null &
    GETEVENT_PID=$!

    # Временный файл для передачи результата из цикла
    echo "$PROFILE" > "$TMP_PROFILE"

    start_time=$(date +%s)

    ui_print "Устройство: все input-устройства"
    ui_print "Ожидание нажатий (30 сек таймаут)..."
    ui_print ""

    # --- Чтение событий в ГЛАВНОМ процессе (не subshell!) ---
    # read -t 1 таймаут 1 сек на строку. При отсутствии событий while
    # завершается через ~30 итераций (30 сек).
    while IFS= read -r line -t 1; do
        current_time=$(date +%s)
        if [ $((current_time - start_time)) -ge 30 ]; then
            ui_print "⏱ Время истекло. Сохранён профиль $PROFILE"
            echo "$PROFILE" > "$TMP_PROFILE"
            break
        fi

        case "$line" in
            *KEY_VOLUMEUP*DOWN*)
                PROFILE=$(( (PROFILE + 1) % 3 ))
                ui_print "  → Профиль $PROFILE"
                echo "$PROFILE" > "$TMP_PROFILE"
                ;;
            *KEY_VOLUMEDOWN*DOWN*)
                PROFILE=$(( (PROFILE - 1 + 3) % 3 ))
                ui_print "  → Профиль $PROFILE"
                echo "$PROFILE" > "$TMP_PROFILE"
                ;;
            *KEY_POWER*DOWN*)
                ui_print ""
                ui_print "✅ Профиль $PROFILE подтверждён"
                echo "$PROFILE" > "$TMP_PROFILE"
                break
                ;;
        esac
    done < "$FIFO"
fi

# --- Чтение результата из tmp-файла ---
if [ -f "$TMP_PROFILE" ]; then
    PROFILE=$(cat "$TMP_PROFILE")
    rm -f "$TMP_PROFILE"
fi

# Валидация итогового профиля
case "$PROFILE" in
    0|1|2) ;;
    *) PROFILE=0 ;;
esac

# --- Атомарная запись settings ---
printf 'selected_carrier=%s\n' "$PROFILE" > "$TMP_SETTINGS"
chmod 0600 "$TMP_SETTINGS"
mv -f "$TMP_SETTINGS" "$SETTINGS"

case "$PROFILE" in
    0) NAME="Latvijas Mobilais (Latvia)" ;;
    1) NAME="AT&T (USA)" ;;
    2) NAME="T-Mobile (USA)" ;;
    *) PROFILE=0; NAME="Latvijas Mobilais (Latvia)" ;;
esac

ui_print ""
ui_print "========================================"
ui_print "  Профиль: $PROFILE"
ui_print "  Оператор: $NAME"
ui_print "========================================"
ui_print ""
ui_print "Готово!"
