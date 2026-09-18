#!/system/bin/sh
# customize.sh — Точка входа Magisk при установке модуля
# Вызывается автоматически во время установки модуля

MODPATH="${0%/*}"
SETTINGS="$MODPATH/settings"
TMP_SETTINGS="$MODPATH/settings.tmp.$$"

ui_print "***************************************"
ui_print "  GPay-Spoofer v1.2.3"
ui_print "***************************************"
ui_print ""

# Создаем файл настроек по умолчанию, если его нет
if [ ! -f "$SETTINGS" ]; then
    printf 'selected_carrier=0\n' > "$TMP_SETTINGS"
    chmod 0600 "$TMP_SETTINGS"
    mv -f "$TMP_SETTINGS" "$SETTINGS"
    ui_print "Создан файл настроек по умолчанию."
else
    ui_print "Файл настроек уже существует."
fi

ui_print ""
ui_print "Запуск интерактивного выбора профиля..."
ui_print "Используйте Громкость ВВЕРХ/ВНИЗ и Питание"
ui_print ""

# Запускаем action.sh как подпроцесс
if [ -f "$MODPATH/action.sh" ]; then
    sh "$MODPATH/action.sh" "$MODPATH"
fi

ui_print ""
ui_print "***************************************"
ui_print "  Модуль установлен!"
ui_print "  Перезагрузите устройство."
ui_print "***************************************"
