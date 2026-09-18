#!/system/bin/sh

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
LOGDIR="/data/adb"
LOGFILE="$LOGDIR/carrier-research.log"
TMPFILE="$SETTINGS.tmp.$$"

mkdir -p "$LOGDIR"

CURRENT="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"

case "$CURRENT" in
    0|1|2|3) ;;
    *) CURRENT=0 ;;
esac

NEXT=$(( (CURRENT + 1) % 4 ))

case "$NEXT" in
    0) NAME="RU test profile" ;;
    1) NAME="Latvia test profile" ;;
    2) NAME="AT&T test profile" ;;
    3) NAME="T-Mobile test profile" ;;
esac

printf 'selected_carrier=%s\n' "$NEXT" > "$TMPFILE"
chmod 0600 "$TMPFILE"
mv -f "$TMPFILE" "$SETTINGS"
chmod 0600 "$SETTINGS"

{
    echo "[$(date)] Test profile changed: $NEXT — $NAME"
    echo "Real SIM ISO: $(getprop gsm.sim.operator.iso-country)"
    echo "Real SIM numeric: $(getprop gsm.sim.operator.numeric)"
    echo "Real operator ISO: $(getprop gsm.operator.iso-country)"
    echo "Real operator numeric: $(getprop gsm.operator.numeric)"
    echo "No telephony properties were changed."
} >> "$LOGFILE"

chmod 0600 "$LOGFILE"

echo "Selected test profile: $NEXT — $NAME"
echo "Real telephony properties were not changed."
