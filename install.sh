#!/system/bin/sh
# install.sh — Установка модуля GPay-Spoofer с выбором профиля

MODDIR="/data/adb/modules/GPay-Spoofer"
SETTINGS="$MODDIR/settings"

# 1. Создаем директорию модуля
mkdir -p "$MODDIR"

ui_print "========================================"
ui_print "  GPay-Spoofer v1.2.0"
ui_print "========================================"
ui_print ""

# 2. Корректный запуск выбора профиля при установке
# Во время установки скрипты распакованы в текущую директорию ($OUTFD / прошивальщик)
INSTALL_DIR="$(dirname "$0")"

if [ -f "$INSTALL_DIR/switch_carrier.sh" ]; then
    ui_print "Запуск интерактивного выбора профиля..."
    ui_print "Используйте Громкость ВВЕРХ/ВНИЗ и Питание"
    ui_print ""
    sh "$INSTALL_DIR/switch_carrier.sh"
fi

# 3. Если настройки не создались, ставим дефолт (Latvia)
if [ ! -f "$SETTINGS" ] || ! grep -q "selected_carrier=" "$SETTINGS"; then
    cat > "$SETTINGS" <<EOF
selected_carrier=0
EOF
fi

ui_print ""
ui_print "========================================"
ui_print "  Модуль установлен!"
ui_print "  Перезагрузите устройство."
ui_print "========================================"