#!/system/bin/sh

MODDIR="/data/adb/modules/GPay-Spoofer"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Ошибка: Этот скрипт должен запускаться с правами root!"
    echo "Используйте команду: su -c sh bin_checker.sh"
    exit 1
fi

if [ ! -f "$CARRIERS_DB" ]; then
    echo "❌ Ошибка: База данных '$CARRIERS_DB' не найдена!"
    exit 1
fi

clear 2>/dev/null || printf "\033[H\033[J"
echo "=================================================="
echo "      GPAY SPOOFER — УМНАЯ НАСТРОЙКА ПО BIN       "
echo "=================================================="
printf " Введите первые 6-8 цифр карты: "
read -r USER_INPUT

USER_BIN="$(echo "$USER_INPUT" | tr -d '[:space:]' | tr -d '-')"

case "$USER_BIN" in
    *[!0-9]* | "")
        echo "❌ Ошибка: BIN должен состоять строго из цифр!"
        exit 1
        ;;
    [0-9][0-9][0-9][0-9][0-9] | [0-9][0-9][0-9][0-9] | [0-9][0-9][0-9] | [0-9][0-9] | [0-9])
        echo "❌ Ошибка: Введите минимум 6 цифр (рекомендуется 8)."
        exit 1
        ;;
esac

BIN_8="$(echo "$USER_BIN" | cut -c1-8)"

echo "--------------------------------------------------"
echo "🔍 Запрос к онлайн-базе для BIN $BIN_8..."

RESPONSE=""
if command -v curl >/dev/null 2>&1; then
    RESPONSE="$(curl -fsSL --connect-timeout 5 --max-time 10 "https://handyapi.com" 2>/dev/null)"
elif command -v wget >/dev/null 2>&1; then
    RESPONSE="$(wget -qO- --timeout=10 "https://data.handyapi.com/bin/$BIN_8" 2>/dev/null)"
fi

if [ -z "$RESPONSE" ]; then
    echo "❌ Ошибка: Не удалось получить ответ от сервера."
    echo "Проверьте подключение к интернету."
    exit 1
fi

TARGET_ISO="$(echo "$RESPONSE" | sed -n 's/.*"A2"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr '[:upper:]' '[:lower:]')"

if [ -z "$TARGET_ISO" ]; then
    echo "❌ Ошибка: BIN не найден в базе данных или регион не определен."
    exit 1
fi

echo "✅ Карта определена! Регион выпуска: $(echo "$TARGET_ISO" | tr '[:lower:]' '[:upper:]')"
echo "--------------------------------------------------"

NEW_ID=""
TARGET_NUMERIC=""
TARGET_NAME=""

while IFS=":" read -r id numeric iso name; do
    case "$id" in "" | [[:space:]]*) continue ;; esac
    if [ "$iso" = "$TARGET_ISO" ]; then
        NEW_ID="$id"
        TARGET_NUMERIC="$numeric"
        TARGET_NAME="$name"
        break
    fi
done < "$CARRIERS_DB"

if [ -n "$NEW_ID" ]; then
    echo "[*] В модуле найден подходящий профиль: [$NEW_ID] $TARGET_NAME"
else
    echo "[!] Страны '$TARGET_ISO' нет в вашей базе carriers.db."
    echo "[*] Автоматически назначаю универсальный профиль: Latvia (LMT)"
    NEW_ID=1
    
    while IFS=":" read -r id numeric iso _name; do
        case "$id" in "" | [[:space:]]*) continue ;; esac
        if [ "$id" -eq 1 ]; then
            TARGET_NUMERIC="$numeric"
            TARGET_ISO="$iso"
            break
        fi
    done < "$CARRIERS_DB"
fi

echo "selected_carrier=$NEW_ID" > "$SETTINGS"
chmod 0600 "$SETTINGS"

for suffix in "" ".1" ".2"; do
    resetprop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
    resetprop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
    resetprop "gsm.operator.numeric$suffix" "$TARGET_NUMERIC"
    resetprop "gsm.operator.iso-country$suffix" "$TARGET_ISO"
done
resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"

am force-stop com.android.vending >/dev/null 2>&1
am force-stop com.google.android.apps.walletnfcrel >/dev/null 2>&1
pm trim-caches 999G >/dev/null 2>&1

echo "--------------------------------------------------"
echo "🚀 Настройки Magisk-модуля успешно обновлены!"
echo "Применен профиль [$NEW_ID]. Изменения вступили в силу."
echo "=================================================="
