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
NEXT=$(( (CURRENT + 1) % 4 ))

case "$NEXT" in
    0) NAME="🔄 Оригинальные значения (Сброс)" ;;
    1) NAME="Latvijas Mobilais 🇱🇻" ;;
    2) NAME="AT&T 🇺🇸" ;;
    3) NAME="T-Mobile 🇺🇸" ;;
esac

# --- Записываем новый профиль в settings ---
TMPFILE="$SETTINGS.tmp.$$"
printf 'selected_carrier=%s\n' "$NEXT" > "$TMPFILE"
chmod 0600 "$TMPFILE"
mv -f "$TMPFILE" "$SETTINGS"
chmod 0600 "$SETTINGS"

# --- Если выбран пункт 0, сразу применяем оригинальные свойства ---
if [ "$NEXT" -eq 0 ]; then
    if [ -f "$PROPS_FILE" ]; then
        . "$PROPS_FILE"
        
        # Восстанавливаем оригиналы, если они были сохранены
        [ -n "$ORIG_ALPHA" ] && resetprop "gsm.operator.alpha" "$ORIG_ALPHA"
        [ -n "$ORIG_NUMERIC" ] && resetprop "gsm.operator.numeric" "$ORIG_NUMERIC"
        [ -n "$ORIG_ISO" ] && resetprop "gsm.operator.iso-country" "$ORIG_ISO"
        
        # Возвращаем сим-карту к исходным значениям
        resetprop "gsm.sim.operator.alpha" "$ORIG_ALPHA"
        resetprop "gsm.sim.operator.numeric" "$ORIG_NUMERIC"
        resetprop "gsm.sim.operator.iso-country" "$ORIG_ISO"
        
        # Сбрасываем мульти-слоты
        resetprop "gsm.sim.operator.numeric.1" "$ORIG_NUMERIC"
        resetprop "gsm.sim.operator.iso-country.1" "$ORIG_ISO"
        resetprop "gsm.sim.operator.numeric.2" "$ORIG_NUMERIC"
        resetprop "gsm.sim.operator.iso-country.2" "$ORIG_ISO"
    fi
fi

# --- Логируем ---
{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Profile changed: $NEXT — $NAME"
    echo "Real SIM ISO: $(getprop gsm.sim.operator.iso-country 2>/dev/null)"
    echo "Real SIM numeric: $(getprop gsm.sim.operator.numeric 2>/dev/null)"
    echo "Real operator ISO: $(getprop gsm.operator.iso-country 2>/dev/null)"
    echo "Real operator numeric: $(getprop gsm.operator.numeric 2>/dev/null)"
} >> "$LOGFILE"

chmod 0600 "$LOGFILE"

echo "Selected profile: $NEXT — $NAME"
if [ "$NEXT" -eq 0 ]; then
    echo "Оригинальные свойства оператора применены! Перезагрузка не обязательна."
else
    echo "Перезапустите service.sh или перезагрузите устройство для применения."
fi