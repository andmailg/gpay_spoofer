#!/system/bin/sh
# install.sh — Установка модуля GPay-Spoofer с выбором профиля

MODDIR="/data/adb/modules/GPay-Spoofer"
SETTINGS="$MODDIR/settings"

# 1. Создаем директорию модуля, если она не существует
mkdir -p "$MODDIR"

ui_print "========================================"
ui_print "  GPay-Spoofer v1.2.0"
ui_print "========================================"
ui_print ""

# 2. Если рядом есть скрипт выбора профиля, запускаем его прямо при установке
if [ -f "$MODPATH/switch_carrier.sh" ] || [ -f "$(dirname "$0")/switch_carrier.sh" ]; then
    SWITCH_SCRIPT="$(dirname "$0")/switch_carrier.sh"
    if [ ! -f "$SWITCH_SCRIPT" ]; then
        SWITCH_SCRIPT="$MODPATH/switch_carrier.sh"
    fi
    
    if [ -f "$SWITCH_SCRIPT" ]; then
        ui_print "Запуск интерактивного выбора профиля..."
        ui_print "Используйте Громкость ВВЕРХ/ВНИЗ и Питание"
        ui_print ""
        sh "$SWITCH_SCRIPT"
    fi
fi

# 3. Если настройки еще не созданы интерактивно, ставим дефолт (Latvia)
if [ ! -f "$SETTINGS" ]; then
    cat > "$SETTINGS" <<EOF
[Выбор оператора]
selected_carrier=0
EOF
fi

ui_print ""
ui_print "========================================"
ui_print "  Модуль установлен!"
ui_print "  Перезагрузите устройство."
ui_print "========================================"