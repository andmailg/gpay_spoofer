#!/system/bin/sh

# ============================================================
# GPay Spoofer — action.sh
# ============================================================

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
PROPS_FILE="$MODDIR/original_props"
LOGFILE="/sdcard/Gpay-Spoofer.log"

# --- Читаем текущий профиль ---
CURRENT="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"

case "$CURRENT" in
    0|1|2|3) ;;
    *) CURRENT=0 ;;
esac

# Цикл переключения на 4 значения: 0, 1, 2, 3
SELECTED_CARRIER=$(( (CURRENT + 1) % 4 ))

TARGET_NUMERIC=""
TARGET_ISO=""

# --- Определяем целевые значения ---
case "$SELECTED_CARRIER" in
    0)
        TARGET_NAME="🔄 Оригинальные значения (Сброс)"
        if [ -f "$PROPS_FILE" ]; then
            . "$PROPS_FILE"
            TARGET_NUMERIC="$ORIG_NUMERIC"
            TARGET_ISO="$ORIG_ISO"
        fi
        [ -z "$TARGET_NUMERIC" ] && TARGET_NUMERIC="$(getprop gsm.operator.numeric)"
        [ -z "$TARGET_ISO" ] && TARGET_ISO="$(getprop gsm.operator.iso-country)"
        ;;
    1)
        TARGET_NUMERIC="24701"
        TARGET_ISO="lv"
        TARGET_NAME="🇱🇻 Latvijas Mobilais"
        ;;
    2)
        TARGET_NUMERIC="310094"
        TARGET_ISO="us"
        TARGET_NAME="🇺🇸 AT&T"
        ;;
    3)
        TARGET_NUMERIC="310260"
        TARGET_ISO="us"
        TARGET_NAME="🇺🇸 T-Mobile"
        ;;
esac

# --- Записываем новый профиль в settings ---
TMPFILE="$SETTINGS.tmp.$$"
printf 'selected_carrier=%s\n' "$SELECTED_CARRIER" > "$TMPFILE"
chmod 0600 "$TMPFILE"
mv -f "$TMPFILE" "$SETTINGS"
chmod 0600 "$SETTINGS"

# --- Прописываем значения через resetprop ---
if [ -n "$TARGET_NUMERIC" ] && [ -n "$TARGET_ISO" ]; then
    resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
    resetprop "gsm.operator.iso-country" "$TARGET_ISO"
    resetprop "gsm.sim.operator.numeric" "$TARGET_NUMERIC"
    resetprop "gsm.sim.operator.iso-country" "$TARGET_ISO"
    resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"

    resetprop "gsm.sim.operator.numeric.1" "$TARGET_NUMERIC"
    resetprop "gsm.sim.operator.iso-country.1" "$TARGET_ISO"
    resetprop "gsm.sim.operator.numeric.2" "$TARGET_NUMERIC"
    resetprop "gsm.sim.operator.iso-country.2" "$TARGET_ISO"
fi

# --- Логируем текущее состояние в файл ---
if [ -d "/sdcard" ]; then
    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Profile changed via Action: $SELECTED_CARRIER — $TARGET_NAME"
        echo "Real SIM ISO: $(getprop gsm.sim.operator.iso-country 2>/dev/null)"
        echo "Real operator ISO: $(getprop gsm.operator.iso-country 2>/dev/null)"
    } >> "$LOGFILE"
    chmod 0600 "$LOGFILE"
fi

# --- Вывод интерфейса для Magisk Manager ---
echo "Selected profile: $SELECTED_CARRIER — $TARGET_NAME"
echo "--------------------------------------------------"
echo "🔄 Запускаю автоматическое обновление свойств..."

# --- Фоновый запуск service.sh без ожидания (ключевой момент) ---
# Удаляем lock-файл на случай, если старый процесс завис, и запускаем заново в фоне
rm -f "/data/adb/gpay-spoofer.lock"
sh "$MODDIR/service.sh" >/dev/null 2>&1 &

echo "✅ Готово! Свойства успешно применены "
echo "Проверьте лог в /sdcard/Gpay-Spoofer.log"
