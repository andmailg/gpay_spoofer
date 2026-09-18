#!/system/bin/sh

# --- Создание настроек по умолчанию, если файл отсутствует ---
if [ ! -f "$MODPATH/settings" ]; then
    echo 'selected_carrier=0' > "$MODPATH/settings"
    chmod 0600 "$MODPATH/settings"
    ui_print "[*] Создан settings по умолчанию (профиль RU)"
fi

ui_print "[*] GPay Spoofer установлен"
ui_print "[*] Для переключения профиля используйте действие модуля в Magisk App"
