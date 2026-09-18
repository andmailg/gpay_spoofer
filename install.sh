#!/system/bin/sh
# install.sh — Установка модуля GPay-Spoofer

MODDIR="/data/adb/modules/GPay-Spoofer"
SETTINGS="$MODDIR/settings"

ui_print "========================================"
ui_print "  GPay-Spoofer v1.2.0"
ui_print "========================================"
ui_print ""
ui_print "Профиль по умолчанию: 0 (Latvia)"
ui_print ""
ui_print "Чтобы сменить оператора:"
ui_print "  1. После установки открой Magisk"
ui_print "  2. Modules → GPay-Spoofer → Settings"
ui_print "  3. Нажми кнопку «Выбор оператора»"
ui_print "  4. Перезагрузи устройство"
ui_print ""
ui_print "Установка..."

# Создаём settings с профилем по умолчанию (Latvia)
cat > "$SETTINGS" <<EOF
[Выбор оператора]
selected_carrier=0
EOF

ui_print ""
ui_print "========================================"
ui.print "  Профиль: 0 — Latvia (GPay)"
ui_print "========================================"
ui_print ""
ui_print "Модуль установлен!"
ui_print "Перезагрузите устройство."
