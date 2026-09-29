#!/system/bin/sh
# shellcheck shell=sh
# GPay-Spoofer: add_carrier.sh (добавление оператора в carriers.db)

case "$0" in
    */*) MODDIR="${0%/*}" ;;
    *)   MODDIR="$(pwd)" ;;
esac
CARRIERS_DB="$MODDIR/carriers.db"

if [ "$#" -lt 3 ]; then
    echo "Использование: su -c sh add_carrier.sh <MCCMNC> <ISO> <ALPHA_NAME>"
    echo "Пример: su -c sh add_carrier.sh 25001 ru MegaFon"
    echo "Имя из нескольких слов можно без кавычек: ... 44010 jp NTT Docomo"
    exit 1
fi

INPUT_NUMERIC=$(echo "$1" | tr -d ' \r')
INPUT_ISO=$(echo "$2" | tr -d ' \r' | tr '[:upper:]' '[:lower:]')
shift 2
INPUT_ALPHA=$(echo "$*" | tr -d '\r' | sed 's/^ *//; s/ *$//')

if [ ! -f "$CARRIERS_DB" ]; then
    echo "❌ Ошибка: База данных не найдена!"
    exit 1
fi

# MCCMNC: строго 5-6 цифр
case "$INPUT_NUMERIC" in
    *[!0-9]* | "")
        echo "❌ Ошибка: MCCMNC должен состоять только из цифр (5-6 штук)."
        exit 1
        ;;
esac
_len=${#INPUT_NUMERIC}
if [ "$_len" -lt 5 ] || [ "$_len" -gt 6 ]; then
    echo "❌ Ошибка: MCCMNC должен состоять из 5-6 цифр (получено: $_len)."
    exit 1
fi

# ISO: ровно 2 латинские буквы
case "$INPUT_ISO" in
    [a-z][a-z]) ;;
    *) echo "❌ Ошибка: ISO код региона должен строго содержать 2 буквы."; exit 1 ;;
esac

# Имя: не пустое, без разделителя
case "$INPUT_ALPHA" in
    "") echo "❌ Ошибка: имя оператора не может быть пустым."; exit 1 ;;
    *:*) echo "❌ Ошибка: имя оператора не должно содержать символ ':'."; exit 1 ;;
esac

# Дубликат проверяем только по полю MCCMNC
if awk -F: -v n="$INPUT_NUMERIC" '{ gsub(/\r/, "") } $2==n { f=1 } END { exit !f }' "$CARRIERS_DB"; then
    echo "⚠️ Оператор $INPUT_NUMERIC уже зарегистрирован в базе!"
    exit 1
fi

# Новый id = максимальный существующий + 1
LAST_ID=$(awk -F: '/^[0-9]+:/ { if ($1 + 0 > m) m = $1 + 0 } END { print m + 0 }' "$CARRIERS_DB")
NEW_ID=$((LAST_ID + 1))
NEW_LINE="${NEW_ID}:${INPUT_NUMERIC}:${INPUT_ISO}:${INPUT_ALPHA}"

# Запись через временный файл: исходная база не пострадает при сбое
TMP_DB="$CARRIERS_DB.tmp"
{
    grep -v '^[[:space:]]*$' "$CARRIERS_DB"
    echo "$NEW_LINE"
} > "$TMP_DB" && mv "$TMP_DB" "$CARRIERS_DB"
chmod 0600 "$CARRIERS_DB" 2>/dev/null

echo "✅ Успешно добавлено: $NEW_LINE"
