#!/system/bin/sh
# install.sh — Установка модуля GPay-Spoofer с выбором профиля

MODDIR="/data/adb/modules/GPay-Spoofer"
SETTINGS="$MODDIR/settings"

mkdir -p "$MODDIR"

ui_print "========================================"
ui_print "  GPay-Spoofer v1.2.3"
ui_print "========================================"
ui_print ""

INSTALL_DIR="$(dirname "$0")"

if [ -f "$INSTALL_DIR/action.sh" ]; then
    ui_print "Запуск интерактивного выбора профиля..."
    ui_print "Используйте Громкость ВВЕРХ/ВНИЗ и Питание"
    ui_print ""
    sh "$INSTALL_DIR/action.sh"
fi

if [ ! -f "$SETTINGS" ] || ! grep -q "selected_carrier=" "$SETTINGS"; then
    echo "selected_carrier=0" > "$SETTINGS"
fi

ui_print ""
ui_print "========================================"
ui_print "  Модуль установлен!"
ui_print "  Перезагрузите устройство."
ui_print "========================================"