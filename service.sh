#!/system/bin/sh

# ============================================================
# GPay Spoofer — service.sh
# Запускается Магиском после загрузки.
# Подменяет свойства оператора только при обнаружении русской SIM.
# ============================================================

MODDIR=${0%/*}
SETTINGS="$MODDIR/settings"
LOGFILE="/sdcard/Gpay-Spoofer.log"
LOCKFILE="/data/adb/gpay-spoofer.lock"

# --- Блокировка: не запускать два экземпляра ---
if [ -e "$LOCKFILE" ]; then
    exit 0
fi

touch "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# --- Ждём завершения загрузки Android ---
timeout=60
elapsed=0

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
    elapsed=$((elapsed + 2))

    if [ "$elapsed" -ge "$timeout" ]; then
        break
    fi
done

# --- Даём telephony и SD-карте время инициализироваться ---
sleep 15

# --- Читаем выбранный профиль (теперь допустимы 0, 1, 2, 3) ---
SELECTED_CARRIER="$(sed -n 's/^selected_carrier=//p' "$SETTINGS" 2>/dev/null | head -n 1)"

case "$SELECTED_CARRIER" in
    0|1|2|3) ;;
    *) SELECTED_CARRIER=0 ;;
esac

# --- Сохраняем оригинальные значения для восстановления (action.sh / uninstall) ---
#ORIG_ALPHA="$(getprop gsm.operator.alpha 2>/dev/null)"
ORIG_NUMERIC="$(getprop gsm.operator.numeric 2>/dev/null)"
ORIG_ISO="$(getprop gsm.operator.iso-country 2>/dev/null)"

# Записываем их в файл в директории модуля, чтобы action.sh мог их прочитать
#cat << EOF > "$MODDIR/original_props"
#ORIG_ALPHA="$ORIG_ALPHA"
#ORIG_NUMERIC="$ORIG_NUMERIC"
#ORIG_ISO="$ORIG_ISO"
#EOF

cat << EOF > "$MODDIR/original_props"
ORIG_NUMERIC="$ORIG_NUMERIC"
ORIG_ISO="$ORIG_ISO"
EOF

# --- Гарантированно создаем файл лога на SD-карте перед первой записью ---
mkdir -p /sdcard
[ ! -f "$LOGFILE" ] && touch "$LOGFILE"

# --- Если выбран профиль 0 (Оригинал), то спуфинг пропускаем ---
if [ "$SELECTED_CARRIER" -eq 0 ]; then
    echo "[$(date)] ℹ️ Выбран профиль 0 (Оригинал). Спуфинг пропущен." >> $LOGFILE
    exit 0
fi

# --- Проверяем, что SIM — российская ---
SOURCE_ISO="$(getprop gsm.sim.operator.iso-country 2>/dev/null)"
CHECK_ISO="$(echo "$SOURCE_ISO" | tr -d ',' | tr -d ' ')"

if [ "$CHECK_ISO" != "ru" ] && [ "$CHECK_ISO" != "RU" ]; then
    echo "[$(date)] ℹ️ Спуфинг не применен. SIM не российская (ISO: '$SOURCE_ISO')" >> $LOGFILE
    exit 0
fi

# --- Определяем целевые значения (с учетом сдвига индексов: 1, 2, 3) ---
case "$SELECTED_CARRIER" in
    1)
        TARGET_NUMERIC="24701"
        TARGET_ISO="lv"
        TARGET_NAME="🇱🇻 Latvijas Mobilais"
        ;;
    2)
        TARGET_NUMERIC="310094"
        TARGET_ISO="🇺🇸"
        TARGET_NAME="🇺🇸 AT&T"
        ;;
    3)
        TARGET_NUMERIC="310260"
        TARGET_ISO="🇺🇸"
        TARGET_NAME="🇺🇸 T-Mobile"
        ;;
esac

# --- Проверяем, что все переменные определены ---
[ -n "$TARGET_NUMERIC" ] || exit 1
[ -n "$TARGET_ISO" ] || exit 1

# --- Пишем стартовый лог о запуске спуфинга (через >>) ---
echo "[$(date)] Обнаружена SIM 🇷🇺  ($SOURCE_ISO). Спуфинг запущен: 🇷🇺→🇱🇻 $TARGET_NAME" >> $LOGFILE

# --- Подменяем свойства ---
resetprop "gsm.operator.numeric" "$TARGET_NUMERIC"
resetprop "gsm.operator.iso-country" "$TARGET_ISO"
resetprop "gsm.sim.operator.numeric" "$TARGET_NUMERIC"
resetprop "gsm.sim.operator.iso-country" "$TARGET_ISO"
resetprop "ro.cdma.home.operator.numeric" "$TARGET_NUMERIC"

# --- Мульти-SIM слоты ---
resetprop "gsm.sim.operator.numeric.1" "$TARGET_NUMERIC"
resetprop "gsm.sim.operator.iso-country.1" "$TARGET_ISO"
resetprop "gsm.sim.operator.numeric.2" "$TARGET_NUMERIC"
resetprop "gsm.sim.operator.iso-country.2" "$TARGET_ISO"

# --- Финальная запись в лог (через >>) ---
echo "[$(date)] ✅ Параметры "$TARGET_NAME" применены:" >> $LOGFILE
echo "[$(date)] numeric=$TARGET_NUMERIC iso=$TARGET_ISO" >> $LOGFILE