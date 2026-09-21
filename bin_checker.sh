#!/system/bin/sh
MODDIR="${0%/*}"
[ "$MODDIR" = "." ] || [ -z "$MODDIR" ] && MODDIR="/data/adb/modules/GPay-Spoofer"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"

_set_prop() {
    if command -v resetprop >/dev/null 2>&1; then
        resetprop "$1" "$2"
    elif [ -x /data/adb/ap/bin/kpcli ]; then
        /data/adb/ap/bin/kpcli property set "$1" "$2"
    elif [ -x /data/adb/ksu/bin/kpcli ]; then
        /data/adb/ksu/bin/kpcli property set "$1" "$2"
    elif command -v kpcli >/dev/null 2>&1; then
        kpcli property set "$1" "$2"
    else
        setprop "$1" "$2"
    fi
}

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Ошибка: Нужны права root!"
    exit 1
fi

if [ ! -f "$CARRIERS_DB" ]; then
    echo "❌ Ошибка: База данных не найдена!"
    exit 1
fi

printf "\033[H\033[J"
echo "=== GPAY SPOOFER ==="
printf "Введите первые 6-8 цифр карты: "
read -r USER_INPUT

USER_BIN=$(echo "$USER_INPUT" | tr -d ' \t-')
case "$USER_BIN" in
    *[!0-9]* | "")
        echo "❌ Ошибка: Только цифры!"
        exit 1
        ;;
    [0-9]|[0-9][0-9]|[0-9][0-9][0-9]|[0-9][0-9][0-9][0-9]|[0-9][0-9][0-9][0-9][0-9])
        echo "❌ Ошибка: Минимум 6 цифр!"
        exit 1
        ;;
esac

BIN_8=$(echo "$USER_BIN" | cut -c1-8)
API_URL="https://data.handyapi.com/bin/$BIN_8"

RESPONSE=""
if command -v curl >/dev/null 2>&1; then
    RESPONSE=$(curl -fsSL --connect-timeout 5 --max-time 10 "$API_URL" 2>/dev/null)
elif command -v wget >/dev/null 2>&1; then
    RESPONSE=$(wget -qO- --timeout=10 "$API_URL" 2>/dev/null)
fi

if [ -z "$RESPONSE" ]; then
    echo "❌ Ошибка сети."
    exit 1
fi

TARGET_ISO=$(echo "$RESPONSE" | tr '},' '\n' | grep '"A2"' | cut -d'"' -f4 | tr '[:upper:]' '[:lower:]' | head -n 1)
if [ -z "$TARGET_ISO" ]; then
    echo "❌ Регион не найден."
    exit 1
fi

NEW_ID=""
TARGET_NUMERIC=""
TARGET_NAME=""

_match=$(grep ":${TARGET_ISO}:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
if [ -n "$_match" ]; then
    NEW_ID=$(echo "$_match" | cut -d':' -f1)
    TARGET_NUMERIC=$(echo "$_match" | cut -d':' -f2)
    TARGET_NAME=$(echo "$_match" | cut -d':' -f4)
else
    _default=$(grep "^1:" "$CARRIERS_DB" 2>/dev/null | head -n 1)
    if [ -n "$_default" ]; then
        NEW_ID=1
        TARGET_NUMERIC=$(echo "$_default" | cut -d':' -f2)
        TARGET_ISO=$(echo "$_default" | cut -d':' -f3)
        TARGET_NAME=$(echo "$_default" | cut -d':' -f4)
    fi
fi

if [ -z "$NEW_ID" ]; then
    echo "❌ Ошибка: База данных пуста."
    exit 1
fi

echo "selected_carrier=$NEW_ID" > "$SETTINGS"
chmod 0600 "$SETTINGS"

for suffix in "" ".1" ".2"; do
    _set_prop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
    _set_prop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
    _set_prop "gsm.operator.numeric$suffix" "$TARGET_NUMERIC"
    _set_prop "gsm.operator.iso-country$suffix" "$TARGET_ISO"
done
_set_prop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"

am force-stop com.android.vending >/dev/null 2>&1
am force-stop com.google.android.apps.walletnfcrel >/dev/null 2>&1
pm trim-caches 999G >/dev/null 2>&1

echo "🚀 Успешно применен профиль: [$NEW_ID] $TARGET_NAME"
