#!/system/bin/sh
# install.sh — Установка модуля GPay-Spoofer с выбором профиля

MODPATH="${0%/*}"
SETTINGS="$MODPATH/settings"

ui_print "========================================"
ui_print "  GPay-Spoofer v1.2.3"
ui_print "========================================"
ui_print ""

# Создаем файл настроек по умолчанию во временной папке установки, если его нет
if [ ! -f "$SETTINGS" ]; then
    echo "selected_carrier=0" > "$SETTINGS"
fi

if [ -f "$MODPATH/action.sh" ]; then
    ui_print "Запуск интерактивного выбора профиля..."
    ui_print "Используйте Громкость ВВЕРХ/ВНИЗ и Питание"
    ui_print ""
    # Передаем путь MODPATH как рабочий каталог для сохранения настроек
    sh "$MODPATH/action.sh" "$MODPATH"
fi

ui_print ""
ui_print "========================================"
ui_print "  Модуль установлен!"
ui_print "  Перезагрузите устройство."
ui_print "========================================"