#!/system/bin/sh
# Циклическая смена оператора при нажатии кнопки Action в Magisk
# 0 → 1 → 2 → 0 ...

SETTINGS="/data/adb/modules/GPay-Spoofer/settings"
LOGFILE="/data/adb/Gpay-Spoofer.log"

# Текущее значение
CURRENT=$(grep "^selected_carrier=" "$SETTINGS" 2>/dev/null | cut -d'=' -f2 | tr -d '[:space:]')
CURRENT=${CURRENT:-0}

# Цикл: 0→1→2→0
case "$CURRENT" in
    0) NEXT=1 ;;
    1) NEXT=2 ;;
    2) NEXT=0 ;;
    *) NEXT=0 ;;
esac

# Сохраняем новое значение
sed -i "s/^selected_carrier=.*/selected_carrier=$NEXT/" "$SETTINGS"

# Имена операторов для лога
NAMES=(
    "Latvijas Mobilais (Latvia)"
    "AT&T (USA)"
    "T-Mobile (USA)"
)

echo "[$(date)] 🔄 Оператор переключён: $CURRENT → $NEXT (${NAMES[$NEXT]})" >> "$LOGFILE"
