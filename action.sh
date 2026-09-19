#!/system/bin/sh

# ============================================================
# GPay Spoofer — action.sh
# Вызывается пользователем через действие модуля в Magisk App.
# Циклически переключает профиль оператора.
# ============================================================

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
LOGDIR="/data/adb"
LOGFILE="$LOGDIR/gpay-spoofer.log"

mkdir -p "$LOGDIR"

# --- Читаем текущий профиль ---
CURRENT="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"

case "$CURRENT" in
    0|1|2) ;;
    *) CURRENT=0 ;;
esac

NEXT=$(( (CURRENT + 1) % 3 ))

case "$NEXT" in
    0) NAME="Latvijas Mobilais (Latvia)" ;;
    1) NAME="AT&T (USA)" ;;
    2) NAME="T-Mobile (USA)" ;;
esac

# --- Записываем новый профиль ---
TMPFILE="$SETTINGS.tmp.$$"
printf 'selected_carrier=%s\n' "$NEXT" > "$TMPFILE"
chmod 0600 "$TMPFILE"
mv -f "$TMPFILE" "$SETTINGS"
chmod 0600 "$SETTINGS"

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
echo "Перезапустите service.sh или перезагрузите устройство для применения."
