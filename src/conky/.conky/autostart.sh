#!/bin/bash

# Очистка файла
cp /dev/null ~/.conky/info.txt
#----------------- Данные для вывода--------------------#
# Имя машины
echo "Имя машины: "`hostname` >> ~/.conky/info.txt
#IP адрес
echo "IP адрес: "`hostname -I` >> ~/.conky/info.txt
#Время включения
echo "Время включения: "`uptime -s | sed -e "s/^\([0-9]*\)-\([0-9]*\)-\([0-9]*\) \([0-9]*\):\([0-9]*\).*$/\3.\2.\1 \4:\5/g"` >> ~/.conky/info.txt
#Имя пользователя
echo "Имя пользователя: "`whoami` >> ~/.conky/info.txt
# Размер ОЗУ
echo "Размер ОЗУ: "`lshw  -C memory | grep 'size' | awk '{print $2}'` >> ~/.conky/info.txt
# Процессор
echo "Processor: "`cat /proc/cpuinfo | grep "model name" -m1 | cut -c14-` >> ~/.conky/info.txt
#Сервер входа
#Время входа

sleep 15
conky -c ~/.conky/.conkyrc &
exit 0
