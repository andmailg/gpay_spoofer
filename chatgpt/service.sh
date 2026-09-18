#!/system/bin/sh

MODDIR="${0%/*}"
SETTINGS="$MODDIR/settings"
LOGDIR="/data/adb"
LOGFILE="$LOGDIR/carrier-research.log"
LOCKFILE="$LOGDIR/carrier-research.lock"

mkdir -p "$LOGDIR"
chmod 0700 "$LOGDIR"

# Не запускать два экземпляра одновременно
if [ -e "$LOCKFILE" ]; then
    exit 0
fi

touch "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# Ждём завершения загрузки Android
timeout=60
elapsed=0

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
    elapsed=$((elapsed + 2))

    if [ "$elapsed" -ge "$timeout" ]; then
        break
    fi
done

# Даём telephony время инициализировать SIM
sleep 5

PROFILE="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"

case "$PROFILE" in
    0) PROFILE_NAME="RU test profile" ;;
    1) PROFILE_NAME="Latvia test profile" ;;
    2) PROFILE_NAME="AT&T test profile" ;;
    3) PROFILE_NAME="T-Mobile test profile" ;;
    *) PROFILE=0; PROFILE_NAME="RU test profile" ;;
esac

{
    echo "========================================"
    echo "Timestamp: $(date)"
    echo "Device: $(getprop ro.product.device)"
    echo "Model: $(getprop ro.product.model)"
    echo "Android: $(getprop ro.build.version.release)"
    echo "SDK: $(getprop ro.build.version.sdk)"
    echo "Fingerprint: $(getprop ro.build.fingerprint)"
    echo "Selected test profile: $PROFILE"
    echo "Profile name: $PROFILE_NAME"
    echo ""
    echo "SIM state: $(getprop gsm.sim.state)"
    echo "SIM ISO: $(getprop gsm.sim.operator.iso-country)"
    echo "SIM alpha: $(getprop gsm.sim.operator.alpha)"
    echo "SIM numeric: $(getprop gsm.sim.operator.numeric)"
    echo "Operator ISO: $(getprop gsm.operator.iso-country)"
    echo "Operator alpha: $(getprop gsm.operator.alpha)"
    echo "Operator numeric: $(getprop gsm.operator.numeric)"
    echo "========================================"
    echo ""
} >> "$LOGFILE"

chmod 0600 "$LOGFILE"
