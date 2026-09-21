#!/system/bin/sh
# GPay Spoofer — status.sh (Проверка текущего статуса и логов)

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"
BIN_CACHE="$MODDIR/my_card.bin.cache"
LOGFILE="$MODDIR/Gpay-Spoofer.log"

# Вычисляем ID профиля с учетом кэша карт
ID=""
if [ -f "$BIN_CACHE" ]; then
    CACHED_ISO="$(cut -d':' -f2 "$BIN_CACHE" 2>/dev/null)"
    if [ -n "$CACHED_ISO" ] && [ -f "$CARRIERS_DB" ]; then
        MATCH_LINE="$(sed -n "/:${CACHED_ISO}:/p" "$CARRIERS_DB" | head -n 1)"
        [ -n "$MATCH_LINE" ] && ID="$(echo "$MATCH_LINE" | cut -d':' -f1)" || ID=1
    fi
fi

if [ -z "$ID" ]; then
    ID="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"
fi

case "$ID" in *[!0-9]*|"") ID=0 ;; esac

echo "=================================================="
echo "          GPay Spoofer — СТАТУС ПРОФИЛЯ           "
echo "=================================================="

if [ -f "$BIN_CACHE" ]; then
    echo "💳 Привязанная карта : BIN $(cut -d':' -f1 "$BIN_CACHE") ($(cut -d':' -f2 "$BIN_CACHE" | tr '[:lower:]' '[:upper:]'))"
else
    echo "💳 Привязанная карта : Нет (Используется ручной выбор)"
fi

if [ "$ID" = "0" ]; then
    echo "⚙️ Активный профиль  : Оригинальные значения (Спуфинг отключен)"
else
    if [ -f "$CARRIERS_DB" ]; then
        LINE="$(sed -n "/^${ID}:/p" "$CARRIERS_DB" | head -n 1)"
        if [ -n "$LINE" ]; then
            NAME="$(echo "$LINE" | cut -d':' -f4)"
            echo "✅ Активный профиль  : [$ID] $NAME"
        else
            echo "⚠️ Активный профиль  : [$ID] Неизвестный оператор (нет в базе)"
        fi
    else
        echo "❌ Ошибка: Файл базы данных carriers.db отсутствует!"
    fi
fi

echo "--------------------------------------------------"
echo "📋 Текущие системные свойства (getprop):"
echo "  ISO сотовой вышки : $(getprop gsm.operator.iso-country 2>/dev/null)"
echo "  Код сотовой вышки : $(getprop gsm.operator.numeric 2>/dev/null)"
echo "  ISO вашей SIM     : $(getprop gsm.sim.operator.iso-country 2>/dev/null)"
echo "  Код вашей SIM     : $(getprop gsm.sim.operator.numeric 2>/dev/null)"

echo "--------------------------------------------------"
echo "📝 Последние события из лога модуля:"

if [ -s "$LOGFILE" ]; then
    # Выводим последние 5 строк. Если утилита tail обрезана в toybox,
    # используем безопасный для POSIX/Android вариант через sed
    if command -v tail >/dev/null 2>&1; then
        tail -n 5 "$LOGFILE" | sed 's/^/  /'
    else
        # Альтернатива на случай жестких ограничений окружения
        lines_count=$(wc -l < "$LOGFILE" | tr -d ' ')
        start_line=$((lines_count - 4))
        [ "$start_line" -lt 1 ] && start_line=1
        sed -n "${start_line},\$p" "$LOGFILE" | sed 's/^/  /'
    fi
else
    echo "  [Лог пуст или еще не создан]"
fi

echo "=================================================="
