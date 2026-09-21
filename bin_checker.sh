#!/system/bin/sh
# GPay Spoofer — bin_checker.sh (Интерактивный инструмент для Termux)

# Определяем пути к модулю (скрипт должен запускаться от root)
MODDIR="/data/adb/modules/GPay-Spoofer"
SETTINGS="$MODDIR/settings"
CARRIERS_DB="$MODDIR/carriers.db"

# Проверка прав суперпользователя
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Ошибка: Этот скрипт должен запускаться с правами root!"
    echo "Используйте команду: su -c sh bin_checker.sh"
    exit 1
fi

# Проверка наличия базы данных модуля
if [ ! -f "$CARRIERS_DB" ]; then
    echo "❌ Ошибка: База данных '$CARRIERS_DB' не найдена!"
    exit 1
fi

clear
echo "=================================================="
echo "      GPAY SPOOFER — УМНАЯ НАСТРОЙКА ПО BIN       "
echo "=================================================="
echo " Скрипт определит регион вашей карты через онлайн-"
echo " базу и автоматически переключит Magisk-модуль."
echo "=================================================="
printf " Введите первые 6-8 цифр карты: "
read -r USER_INPUT

# Очистка ввода от пробелов и дефисов
USER_BIN="$(echo "$USER_INPUT" | tr -d '[:space:]' | tr -d '-')"

# Валидация длины и символов
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

# Отрезаем строго 8 символов для точного запроса
BIN_8="$(echo "$USER_BIN" | cut -c1-8)"

echo "--------------------------------------------------"
echo "🔍 Запрос к онлайн-базе для BIN $BIN_8..."

# Выполняем запрос к API (с таймаутом, чтобы не зависать)
RESPONSE="$(curl -fsSL --connect-timeout 5 --max-time 10 "https://data.handyapi.com/bin/$BIN_8" 2>/dev/null)"

if [ -z "$RESPONSE" ]; then
    echo "❌ Ошибка: Не удалось получить ответ от сервера."
    echo "Проверьте подключение к интернету в Termux."
    exit 1
fi

# Извлекаем ISO-код страны (ключ "A2") и переводим в нижний регистр
TARGET_ISO="$(echo "$RESPONSE" | sed -n 's/.*"A2"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | tr '[:upper:]' '[:lower:]')"

if [ -z "$TARGET_ISO" ]; then
    echo "❌ Ошибка: BIN не найден в базе данных или регион не определен."
    exit 1
fi

echo "✅ Карта определена! Регион выпуска: $(echo "$TARGET_ISO" | tr '[:lower:]' '[:upper:]')"
echo "--------------------------------------------------"

# Ищем подходящего оператора в carriers.db по ISO-коду страны
MATCH_LINE="$(sed -n "/:${TARGET_ISO}:/p" "$CARRIERS_DB" | head -n 1)"

if [ -n "$MATCH_LINE" ]; then
    NEW_ID="$(echo "$MATCH_LINE" | cut -d':' -f1)"
    TARGET_NUMERIC="$(echo "$MATCH_LINE" | cut -d':' -f2)"
    TARGET_NAME="$(echo "$MATCH_LINE" | cut -d':' -f4)"
    
    echo "[*] В модуле найден подходящий профиль: [$NEW_ID] $TARGET_NAME"
else
    # Если страны нет в базе, по умолчанию ставим Латвию (Профиль 1) как универсальный вариант
    echo "[!] Страны '$TARGET_ISO' нет в вашей базе carriers.db."
    echo "[*] Автоматически назначаю универсальный профиль: [1] Latvia (LMT)"
    NEW_ID=1
    LINE_LV="$(sed -n "/^1:/p" "$CARRIERS_DB" | head -n 1)"
    TARGET_NUMERIC="$(echo "$LINE_LV" | cut -d':' -f2)"
    TARGET_ISO="$(echo "$LINE_LV" | cut -d':' -f3)"
fi

# --- Сохранение конфигурации в Magisk-модуль ---
echo "selected_carrier=$NEW_ID" > "$SETTINGS"
chmod 0600 "$SETTINGS"

# --- Мгновенное применение resetprop «на лету» ---
for suffix in "" ".1" ".2"; do
    resetprop "gsm.sim.operator.numeric$suffix" "$TARGET_NUMERIC"
    resetprop "gsm.sim.operator.iso-country$suffix" "$TARGET_ISO"
done
resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
resetprop "gsm.operator.iso-country" "$TARGET_ISO"

# --- Сброс кэша сервисов Google ---
am force-stop com.android.vending >/dev/null 2>&1
am force-stop com.google.android.apps.walletnfcrel >/dev/null 2>&1
pm trim-caches 999G >/dev/null 2>&1

echo "--------------------------------------------------"
echo "🚀 Настройки Magisk-модуля успешно обновлены!"
echo "Google Wallet перезапущен. Перезагрузка не требуется."
echo "=================================================="
