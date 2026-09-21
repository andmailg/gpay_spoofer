#!/system/bin/sh

# ============================================================
# GPay Spoofer — status.sh (Проверка текущего статуса)
# ============================================================

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"

# Читаем сохраненный профиль
ID="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"
case "$ID" in
    *[!0-9]*|"") ID=0 ;;
esac

echo "=================================================="
echo "          GPay Spoofer — СТАТУС ПРОФИЛЯ           "
echo "=================================================="

# Выводим текстовое описание активного профиля
if [ "$ID" = "0" ]; then
    echo "⚙️ Активный профиль: [0] Оригинальные значения (Спуфинг отключен)"
else
    if [ -f "$CARRIERS_DB" ]; then
        LINE="$(sed -n "/^${ID}:/p" "$CARRIERS_DB" | head -n 1)"
        if [ -n "$LINE" ]; then
            IFS=":" read -r _ _ _ NAME << EOF
$LINE
EOF
            echo "✅ Активный профиль: [$ID] $NAME"
        else
            echo "⚠️ Активный профиль: [$ID] Неизвестный оператор (нет в базе)"
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
echo "=================================================="
