#!/system/bin/sh

# ============================================================
# GPay Spoofer — action.sh
# Вызывается пользователем через действие модуля в Magisk App.
# Циклически переключает профили (0 = Оригинал, 1-3 = Операторы).
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


# --- Определяем целевые значения (с учетом сдвига индексов: 1, 2, 3) ---
case "$SELECTED_CARRIER" in
    0) 
        if [ -f "$PROPS_FILE" ]; then
            . "$PROPS_FILE"
            
            # Восстанавливаем оригиналы, если они были сохранены
            #[ -n "$ORIG_ALPHA" ] && resetprop "gsm.operator.alpha" "$ORIG_ALPHA"
            [ -n "$ORIG_NUMERIC" ] && resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
            [ -n "$ORIG_ISO" ] && resetprop "gsm.operator.iso-country" "$TARGET_ISO"
            
        fi
        TARGET_NAME="🔄 Оригинальные значения (Сброс)"
        ;;
    1)
        #TARGET_ALPHA="Latvijas Mobilais"
        TARGET_NUMERIC="24701"
        TARGET_ISO="lv"
        TARGET_NAME="Latvijas Mobilais 🇱🇻"
        ;;
    2)
        #TARGET_ALPHA="ATT"
        TARGET_NUMERIC="310094"
        TARGET_ISO="🇺🇸"
        TARGET_NAME="AT&T 🇺🇸"
        ;;
    3)
        #TARGET_ALPHA="T-Mobile"
        TARGET_NUMERIC="310260"
        TARGET_ISO="🇺🇸"
        TARGET_NAME="T-Mobile 🇺🇸"
        ;;
esac

# --- Записываем новый профиль в settings ---
TMPFILE="$SETTINGS.tmp.$$"
printf 'selected_carrier=%s\n' "$SELECTED_CARRIER" > "$TMPFILE"
chmod 0600 "$TMPFILE"
mv -f "$TMPFILE" "$SETTINGS"
chmod 0600 "$SETTINGS"


# Прописываем значения
#resetprop "gsm.sim.operator.alpha" "$ORIG_ALPHA"
resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
resetprop "gsm.operator.iso-country" "$TARGET_ISO"
resetprop "gsm.sim.operator.numeric" "$TARGET_NUMERIC"
resetprop "gsm.sim.operator.iso-country" "$TARGET_ISO"
resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"

# Сбрасываем мульти-слоты
resetprop "gsm.sim.operator.numeric.1" "$TARGET_NUMERIC"
resetprop "gsm.sim.operator.iso-country.1" "$TARGET_ISO"
resetprop "gsm.sim.operator.numeric.2" "$TARGET_NUMERIC"
resetprop "gsm.sim.operator.iso-country.2" "$TARGET_ISO"



# --- Логируем текущее состояние---
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Profile changed: $SELECTED_CARRIER — $TARGET_NAME"
    echo "Real SIM ISO: $(getprop gsm.sim.operator.iso-country 2>/dev/null)"
    echo "Real SIM numeric: $(getprop gsm.sim.operator.numeric 2>/dev/null)"
    echo "Real operator ISO: $(getprop gsm.operator.iso-country 2>/dev/null)"
    echo "Real operator numeric: $(getprop gsm.operator.numeric 2>/dev/null)"
} >> "$LOGFILE"

chmod 0600 "$LOGFILE"

echo "Selected profile: $SELECTED_CARRIER — $TARGET_NAME"
if [ "$SELECTED_CARRIER" -eq 0 ]; then
    echo "Оригинальные свойства оператора применены! Перезагрузка не обязательна."
else
    echo "Перезапустите service.sh или перезагрузите устройство для применения."
fi