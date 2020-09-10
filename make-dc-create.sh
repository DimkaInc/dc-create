#!/bin/bash
#
# Файл сборки итогового файла dc-create.sh
# на основании template.sh и подключаемых файлов.
#
FILE="../release/dc-create.sh"

cd src
# Подговка каталогов для заливки в файл
cd GVSMO_Zastavka
tar -czvf ../GVSMO_Zastavka.tar.gz *
cd ..
tar -czvf TVU1-v.1.tar.gz TVU1-v.1
tar -czvf fly-tvu01.tar.gz fly-tvu01
tar -czvf conky.tar.gz conky

# Конвертация файлов в текст
base64 GVSMO_Zastavka.tar.gz >GVSMO_Zastavka.tar.gz-base64
base64 TVU1-v.1.tar.gz >TVU1-v.1.tar.gz-base64
base64 fly-tvu01.tar.gz >fly-tvu01.tar.gz-base64
base64 conky.tar.gz >conky.tar.gz-base64


# Удаление ненужных файлов
rm GVSMO_Zastavka.tar.gz
rm TVU1-v.1.tar.gz
rm fly-tvu01.tar.gz
rm conky.tar.gz

# Обработка шаблона для формирования результатирующего файла
cat /dev/null >$FILE

sed -i "s/\r//g" template

while read LINE; do
	#echo ">`echo \"$LINE\" | grep \"#\"`<"
	if [ "`echo \"$LINE\" | grep \"#\"`" != "" ]
	then
		echo "$LINE" >>$FILE
	else
	    if [ "$LINE" == "" ]
	    then
			echo "" >>$FILE
	    else
            sed -i "s/\r//g" $LINE
			cat $LINE >>$FILE
			echo -e "\n## EOF" >>$FILE
	    fi
	fi
done <template

rm GVSMO_Zastavka.tar.gz-base64
rm TVU1-v.1.tar.gz-base64
rm fly-tvu01.tar.gz-base64
rm conky.tar.gz-base64
cd ..
