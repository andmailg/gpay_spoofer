#!/system/bin/sh

ui_print "*******************************"
ui_print " Carrier Research Logger"
ui_print "*******************************"
ui_print "Device: $(getprop ro.product.device)"
ui_print "Android: $(getprop ro.build.version.release)"
ui_print "SDK: $(getprop ro.build.version.sdk)"
ui_print ""
ui_print "Режим: только чтение и журналирование"
ui_print "Системные свойства telephony не изменяются"
