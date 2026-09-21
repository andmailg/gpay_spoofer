#!/system/bin/sh

# --- Создание настроек по умолчанию, если файл отсутствует ---
if [ ! -f "$MODPATH/settings" ]; then
    echo 'selected_carrier=0' > "$MODPATH/settings"
    chmod 0600 "$MODPATH/settings"
    ui_print "[*] Создан файл настроек settings (профиль 0: Оригинал)"
fi

# --- Создание базы данных операторов, если файл отсутствует ---
if [ ! -f "$MODPATH/carriers.db" ]; then
    cat << EOF > "$MODPATH/carriers.db"
1:24701:lv:🇱🇻 Latvijas Mobilais
2:310094:us:🇺🇸 AT&T
3:310260:us:🇺🇸 T-Mobile
EOF
    chmod 0600 "$MODPATH/carriers.db"
    ui_print "[*] Создана база данных операторов carriers.db"
fi

# --- Выставление прав на исполняемые скрипты ---
# Magisk делает это автоматически для service.sh и action.sh, 
# но явное указание гарантирует стабильность на KernelSU / APatch
chmod 0755 "$MODPATH/service.sh" 2>/dev/null
chmod 0755 "$MODPATH/action.sh" 2>/dev/null

ui_print "[*] GPay Spoofer успешно установлен"
ui_print "[*] Для переключения профиля используйте действие модуля (Action) в Magisk / KernelSU App"
