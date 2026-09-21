#!/system/bin/sh
# GPay Spoofer — add_carrier.sh (Финальная версия)

MODDIR="${0%/*}"
CARRIERS_DB="$MODDIR/carriers.db"

show_usage() {
    echo "Использование: su -c sh add_carrier.sh <MCCMNC> <ISO> <NAME>"
    echo "Пример       : su -c sh add_carrier.sh 25001 ru 'Megafon'"
    exit 1
}

if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    show_usage
fi

INPUT_NUMERIC="$(echo "$1" | tr -d ' ')"
INPUT_ISO="$(echo "$2" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"
INPUT_NAME="$3"

if [ ! -f "$CARRIERS_DB" ]; then
    echo "❌ Ошибка: Файл базы данных '$CARRIERS_DB' не найден!"
    exit 1
fi

case "$INPUT_NUMERIC" in
    *[!0-9]* | "" | [0-9][0-9][0-9][0-9] | [0-9][0-9][0-9][0-9][0-9][0-9][0-9]*)
        echo "❌ Ошибка: Код MCCMNC должен содержать строго 5 или 6 цифр."
        exit 1
        ;;
esac

if ! echo "$INPUT_ISO" | grep -Eq '^[a-z]{2}$'; then
    echo "❌ Ошибка: ISO код страны должен состоять из 2 букв латиницы."
    exit 1
fi

if grep -q ":${INPUT_NUMERIC}:" "$CARRIERS_DB"; then
    echo "⚠️ Предупреждение: Оператор с кодом $INPUT_NUMERIC уже есть в базе!"
    exit 1
fi

LAST_ID=$(cut -d':' -f1 "$CARRIERS_DB" 2>/dev/null | sort -n | tail -n 1)
case "$LAST_ID" in ''|*[!0-9]*) LAST_ID=0 ;; esac
NEW_ID=$((LAST_ID + 1))

NEW_LINE="${NEW_ID}:${INPUT_NUMERIC}:${INPUT_ISO}:${INPUT_NAME}"

TMP_DB="$CARRIERS_DB.tmp"
cat "$CARRIERS_DB" > "$TMP_DB"
echo "$NEW_LINE" >> "$TMP_DB"
sed '/^[[:space:]]*$/d' "$TMP_DB" > "$CARRIERS_DB"
rm -f "$TMP_DB"
chmod 0600 "$CARRIERS_DB"

echo "=================================================="
echo "✅ Оператор успешно добавлен в carriers.db!"
echo "Строка: $NEW_LINE"
echo "=================================================="
