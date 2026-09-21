#!/system/bin/sh
# GPay Spoofer — add_carrier.sh (Утилита добавления операторов)

MODDIR="${0%/*}"
CARRIERS_DB="$MODDIR/carriers.db"

# Функция вывода справки
show_usage() {
    echo "Использование: su -c sh add_carrier.sh <MCCMNC> <ISO> <NAME>"
    echo "Пример       : su -c sh add_carrier.sh 25001 ru 'Megafon'"
    echo "--------------------------------------------------"
    echo "  <MCCMNC> — Цифровой код (5-6 цифр, например: 25001)"
    echo "  <ISO>    — Двухбуквенный код страны (например: ru, kz, us)"
    echo "  <NAME>   — Название оператора и страны для вывода"
    exit 1
}

# Проверяем, что переданы все 3 обязательных аргумента
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
    show_usage
fi

INPUT_NUMERIC="$(echo "$1" | tr -d ' ')"
INPUT_ISO="$(echo "$2" | tr -d ' ' | tr '[:upper:]' '[:lower:]')"
INPUT_NAME="$3"

# --- Валидация входных данных ---

# 1. Проверяем базу данных
if [ ! -f "$CARRIERS_DB" ]; then
    echo "❌ Ошибка: Файл базы данных '$CARRIERS_DB' не найден!"
    exit 1
fi

# 2. Проверяем MCCMNC (должен состоять только из 5-6 цифр)
case "$INPUT_NUMERIC" in
    *[!0-9]* | "" | [0-9][0-9][0-9][0-9] | [0-9][0-9][0-9][0-9][0-9][0-9][0-9]*)
        echo "❌ Ошибка: Код MCCMNC должен содержать строго 5 или 6 цифр (передано: '$INPUT_NUMERIC')."
        exit 1
        ;;
esac

# 3. Проверяем ISO код (строго 2 латинские буквы)
if ! echo "$INPUT_ISO" | grep -Eq '^[a-z]{2}$'; then
    echo "❌ Ошибка: ISO код страны должен состоять из 2 букв латиницы (передано: '$INPUT_ISO')."
    exit 1
fi

# 4. Проверяем, нет ли уже такого MCCMNC в базе
if grep -q ":${INPUT_NUMERIC}:" "$CARRIERS_DB"; then
    echo "⚠️ Предупреждение: Оператор с кодом $INPUT_NUMERIC уже есть в базе!"
    grep ":${INPUT_NUMERIC}:" "$CARRIERS_DB" | sed 's/^/  /'
    echo "Отмена операции."
    exit 1
fi

# --- Расчет нового ID ---

# Ищем максимальный ID в первой колонке и прибавляем 1
LAST_ID=$(cut -d':' -f1 "$CARRIERS_DB" 2>/dev/null | sort -n | tail -n 1)
case "$LAST_ID" in
    ''|*[!0-9]*) LAST_ID=0 ;;
esac
NEW_ID=$((LAST_ID + 1))

# --- Запись в базу данных ---

# Формируем строку по нашему новому оптимизированному стандарту
NEW_LINE="${NEW_ID}:${INPUT_NUMERIC}:${INPUT_ISO}:${INPUT_NAME}"

# Безопасная дозапись в конец файла (добавляем перенос строки на всякий случай)
echo "" >> "$CARRIERS_DB"
echo "$NEW_LINE" >> "$CARRIERS_DB"

# Удаляем случайные пустые строки, которые могли образоваться при редактировании
sed -i '/^[[:space:]]*$/d' "$CARRIERS_DB"

echo "=================================================="
echo "✅ Оператор успешно добавлен в carriers.db!"
echo "Строка: $NEW_LINE"
echo "=================================================="
