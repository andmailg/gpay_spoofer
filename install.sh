#!/system/bin/sh
# install.sh — Установка модуля GPay-Spoofer с выбором профиля

MODPATH="${0%/*}"
MODDIR="/data/adb/modules/GPay-Spoofer"
SETTINGS="$MODDIR/settings"

mkdir -p "$MODDIR"

ui_print "========================================"
ui_print "  GPay-Spoofer v1.2.3"
ui_print "========================================"
ui_print ""

if [ -f "$MODPATH/action.sh" ]; then
    ui_print "Запуск интерактивного выбора профиля..."
    ui_print "Используйте Громкость ВВЕРХ/ВНИЗ и Питание"
    ui_print ""
    # Передаем целевой путь MODDIR первым аргументом в action.sh
    sh "$MODPATH/action.sh" "$MODDIR"
fi

# Если по какой-то причине файл settings не создался, создаем дефолтный
if [ ! -f "$SETTINGS" ] || ! grep -q "selected_carrier=" "$SETTINGS"; then
    echo "selected_carrier=0" > "$SETTINGS"
fi

ui_print ""
ui_print "========================================"
ui_print "  Модуль установлен!"
ui_print "  Перезагрузите устройство."
ui_print "========================================"