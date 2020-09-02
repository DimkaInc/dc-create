#!/bin/bash
#
# Скрипт создания контроллера домена на базе Samba 4 для Debian 10
# В качестве руководства использоватлись матералы:
# https://wiki.samba.org/index.php/Active_Directory_Domain_Controller
# https://unlis.ru/?p=501
# @author Dmitry Dobryshin Aka -+= Dimka Inc =+-
# @date   06.11.2019
# @version 0.0.5
#
# ==========================================================
# Переменные для работы
# Имя хоста
HOSTNAME="mtv-srv-dc-0001"
# Домен. ВАЖНО!!! Доменная зона .local является ошибочной и не работает из-за
# конфликта с локальными службами (Avahi).
REALM="TERVETMO01.LOC"
# IP адрес хоста (Так как это контроллер домена, то используется
# исключительно статический адрес)
ADDRESS="192.168.0.1"
# Маска сети. Можно задавать количеством бит или байтами, разделёнными точкой
MASK=255.255.255.0
# Шлюз - IP адрес шлюза для организации связи в локальной сети
GATEWAY="192.168.0.1"
# DNS сервера, до 2х штук через пробел
DNSSERVERS="8.8.8.8 8.8.4.4"
# Пароль пользователя Administrator контроллера домена
ADMPASWD="Password"
# ==== Cisco-Any-Connect ====
# Шлюз
#VPNGW="guv.secure.mosreg.ru"
# Пользователь
VPNUSR="vpnuser"
# пароль
VPNPWD="Password"

# ================================================
#
# Функция опроса пользователя с ответом y/n
# возвращает 0 при ответе y и 1 в ином случае
myAskYN() {
  # Локальная переменна для получения ответа пользователя
  local AMSURE
  # Если есть параметр
  if [ -n "$1" ] ; then
     # покажем параметр пользователю и ждём нажатия клавиши
     read -n 1 -p "$1 (y/[n]): " AMSURE
  # Параметра нет
  else
      # Ждём от пользователя нажатой клавиши
      read -n 1 AMSURE
  fi
  # Изменим цвет текста на экране
  echo -e "\e[0;39m" 1>&2
  # Если введена y
  if [ "$AMSURE" = "y" ] ; then
     # вернём 0
     return 0
  # нажата другая кнопка
  else
      # вернём 1
      return 1
  fi
}

# Функкция опроса пользователя с ответом y/n
# при ответе, отличном от y, происходит завершение работы скрипта
myAskYNE() {
  # Выполним опрос пользователя
  myAskYN "$1"
  # Если вернули не 0
  if [ $? -ne 0 ] ; then
     # Прекраим работу, вернув 1
     exit 1
  fi
}

curPath= # переменная с текущим абсолютным путём, где находится скрипт
cRes=    # переменная для возврата текстовых значений из функций
pYes=    # параметр --yes

# Функция получения ответа от пользователя
# первый параметр - текстовое сообщение, второй параметр - список допустимых ответов
input1() {
  # Если есть параметр
  if [ -n "$1" ] ; then
     # Покажем параметр пользователю и ждём от него нажатых клавиш
     read -p "$1" -sn 1 cRes
  # параметр пустой
  else
      # Получим нажатых кнопок пользователя
      read -sn 1 cRes
  fi

  # проверка допустимых ответов на соответствие второму параметру
  while [ "$2" = "${2#*$cRes}" ] ; do
        # Если не соответствет, ожидаем от пользователя ещё
        read -sn 1 cRes
  done
  # Выведем полученный ответ
  echo $cRes 1>&2
}

# Просмотрим все параметры запуска
for param in "$@" ; do
  # Если есть параметр --yes
  if [ "$param" = "--yes" ] ; then
     # Установим переменную "без вопросов"
     pYes=1
  # Если есть парметр --help
  elif [ "$param" = "--help" ] ; then
     # Покажем инструкцию по применению
     echo -e "Скрипт создания контроллера домена \e[90m(перед запуском необходимо отредактировать, внеся необходимые данные для создания домена)\e[37m.\n"
     echo -e "Способ использования:\n\n   $0 [параметры]\n\n\e[4mПараметры:\e[24m\n \e[1m--yes\e[21m    - не задавать вопросов во время работы скрипта\n \e[1m--remove\e[21m - удалить установленные компоненты\n \e[1m--help\e[21m   - вывести этот текст"
     exit 0
  fi
done
# Если нет "без вопросов"
if [ "$pYes" != "1" ] ; then
   # Спросим нужно ли запускать, и если нет, выйдем
   echo -e "\e[32m"
   myAskYNE "Скрипт создания контроллера домена. Уверен что нужно запустить?"
fi

# Основной модуль скрипта
mainProc() {
  # Переменные
  # Флаг удаления настроек
  local pRemove=0
  # Флаг "без вопросов"
  local pYes=0
  # Ответы функций
  local cRes=
  # Описание цветов
  # Информационное сообщение
  local cInfo='\e[0;40;32m'
  # Обычный текст консоли
  local cNormal='\e[0;40;37m'
  # Текст
  local cText='\e[0;40;90m'
  # Важное сообщение
  local cRed='\e[0;40;31m'
  # Выделенное
  local cGold='\e[0;40;93m'
  # Файл
  local cBlue='\e[0;40;34m'
  # Ссылка
  local cUrl='\e[4;40;34m'
  # Невидимый
  local cNone='\e[8;40;31m'

  # Перебор всех параметров
  for param in "$@"; do
      # Если есть параметр "--yes"
      if [ "$param" = "--yes" ] ; then
         # Установим флаг "без вопросов"
         local pYes=1
      # Если есть параметр "--remove"
      elif [ "$param" = "--remove" ] ; then
         # Установим флаг "удаление"
         local pRemove=1
      fi
  done

  # Функция преобразования октета в число бит
  oct2count() {
    # Если нет параметра или он пустой
    if [[ "$1" = "" ]] ; then
       # Ошибка
       cRes=-1
    # 00000000b - 0 установленных бит
    elif [[ "$1" = "0" ]] ; then
         cRes=0
    # 10000000b - 1 установленный бит
    elif [[ "$1" = "128" ]] ; then
         cRes=1
    # 11000000b - 2 установленных бита
    elif [[ "$1" = "192" ]] ; then
         cRes=2
    # 11100000b - 3 установленных бита
    elif [[ "$1" = "224" ]] ; then
         cRes=3
    # 11110000b - 4 установленных бита
    elif [[ "$1" = "240" ]] ; then
         cRes=4
    # 11111000b - 5 установленных бит
    elif [[ "$1" = "248" ]] ; then
         cRes=5
    # 11111100b - 6 установленных бит
    elif [[ "$1" = "252" ]] ; then
         cRes=6
    # 11111110b - 7 установленных бит
    elif [[ "$1" = "254" ]] ; then
         cRes=7
    # 11111111b - 8 установленных бит
    elif [[ "$1" = "255" ]] ; then
         cRes=8
    # В остальных случаях - ошибка
    else
         сRes=-1
    fi
  }

  # Функция опроса пользователя с ответом y/n
  # возвращает 0 при ответе y и 1 в ином случае
  myAskYN() {
    # Локальная переменнвя хранения ответа
    local AMSURE
    # Если есть первый параметр
    if [ -n "$1" ] ; then
       # Покажем первый параметр и будем ждать нажатую клавишу пользователя
       read -n 1 -p "$1 (y/[n]): " AMSURE
    else
        # Иначе ждём ответа от пользователя
        read -n 1 AMSURE
    fi
    # Переключим цвет на обычный
    echo -e "${cNormal}" 1>&2
    # Если нажали "y"
    if [ "$AMSURE" = "y" ] ; then
       # Вернём ноль
       return 0
    # Иначе вернём 1
    else
        return 1
    fi
  }

  # Функкция опроса пользователя с ответом y/n
  # при ответе, отличном от y, происходит завершение работы скрипта
  myAskYNE() {
    # Спросим пользователя
    myAskYN "$1"
    # Если возвращён не 0
    if [ $? -ne 0 ] ; then
       # Завершим работу скрипта
       exit 1
    fi
  }

  # Функция получения ответа от пользователя
  # первый параметр - текстовое сообщение
  input1() {
    # Если есть сообщение
    if [ -n "$1" ] ; then
       # Покажем его и будем ждать от пользователя нажатия одной клавиши
       read -p "$1" -sn 1 cRes
    # Иначе
    else
        # Будем ждать от пользователя нажатия одной клавиши
        read -sn 1 cRes
    fi
    # Вернём в cRes нажатую клавишу
  }

  # Функция ожидания нажатия любой клавиши
  #
  sayWait() {
    # переменная ответа пользователя
    local AMSURE
    # Если есть параметр, покажем его
    [ -n "$1" ] && echo "$@" 1>&2
    # Ожидаем от пользователя ответ
    read -n 1 -p "(нажмите любую клавишу для продолжения)" AMSURE
    # Изменим цвет на обычный
    echo -e "${cNormal}" 1>&2
  }

  # Функция выделения нескольких строк из файла до строки "# EOF"
  # первый парамет - Уникальная ключевая фраза перед началом участка текста
  # второй параметр - имя файла, где сожержится текст
  # Строка, содержащая ключ и "# EOF" в результат не попадают.
  extractLines() {
    cRes=$(sed -n -e "/$1/,/# EOF/p" $2 | sed -e '1d;${h;d;}')
  }

  # Функция настройки сети
  doEthernet() {
    # --------------------------------------------------
    # Настройка сетевого интерфейса через NetworkManager
    # --------------------------------------------------
    local AUTODHCP="${AUTODHCP,,}"
    if [[ "$AUTODHCP" =~ ^(yes|no)$ ]]; then
       echo -e "${cInfo}Настройка сетевого подключения${cNormal}"
    else
       echo -e "${cInfo}AUTODHCP${cNormal} принимает значения ${cRed}yes${cInfo} или ${cRed}no${cNormal}"
       exit 1
    fi

    DEVNAME="Ethernet0"
    DEVICE=$(ip -r -f inet address show | egrep "state UP" | awk '/.*:/{print $2}' | rev | cut -c 2- | rev)
    NMCON="nmcli connection"


    if [[ $(${NMCON} show | grep "${DEVNAME}" | awk '/[0-9a-zA-Z]*/{print $1}') = "${DEVNAME}" ]] ; then
       echo -e "${cText}$NMCON down \"${DEVNAME}\"${cNormal}" 1>&2
       $NMCON down "${DEVNAME}"
       echo -e "${cText}$NMCON modify \"${DEVNAME}\" ifname $DEVICE${cNormal}" 1>&2
       $NMCON modify "${DEVNAME}" ifname $DEVICE
    else
       echo -e "${cText}$NMCON add type ethernet con-name \"${DEVNAME}\" ifname $DEVICE${cNormal}" 1>&2
       $NMCON add type ethernet con-name "${DEVNAME}" ifname $DEVICE
    fi

    if [ "$AUTODHCP" = "no" ] ; then
       echo -e "${cText}$NMCON modify \"${DEVNAME}\" ipv4.method manual ip4 $NETWORK gw4 $GATEWAY${cNormal}" 1>&2
       $NMCON modify "${DEVNAME}" ipv4.method manual ip4 $NETWORK gw4 $GATEWAY
       echo -e "${cText}$NMCON modify \"${DEVNAME}\" ipv4.dns \"${ADDRESS} $DNSSERVERS\"${cNormal}" 1>&2
       $NMCON modify "${DEVNAME}" ipv4.dns "${ADDRESS} $DNSSERVERS"
       echo -e "${cText}$NMCON modify \"${DEVNAME}\" ipv4.dns-search ${REALM,,}${cNormal}" 1>&2
       $NMCON modify "${DEVNAME}" ipv4.dns-search ${REALM,,}
       echo -e "${cText}$NMCON modify \"${DEVNAME}\" ipv6.dns-search ${REALM,,}${cNormal}" 1>&2
       $NMCON modify "${DEVNAME}" ipv6.dns-search ${REALM,,}
    else
       echo -e "${cText}$NMCON modify \"${DEVNAME}\" ipv4.method auto${cNormal}" 1>&2
       $NMCON modify "${DEVNAME}" ipv4.method auto
    fi
    echo -e "${cText}$NMCON modify \"${DEVNAME}\" connection.autoconnect yes${cNormal}" 1>&2
    $NMCON modify "${DEVNAME}" connection.autoconnect yes

    echo -e "${cText}$NMCON up \"${DEVNAME}\"${cNormal}" 1>&2
    $NMCON up "${DEVNAME}"
    if [ $? -ne 0 ] ; then
       echo -e "${cRed}Не удалось включить сеть${cNormal}"
       exit 1
    fi

  }

  # Функция приведения ОС к актуальному состоянию
  doUpdate() {
    # ========================================
    echo -e "${cInfo}Установка обновлений${cNormal}"
    # ========================================

    echo -e "${cText}--- Получаем список обновлений ---${cNormal}"
    apt-get update > /dev/null
    echo -e "${cText}--- Выполняем основные обновления ---${cNormal}"
    apt-get -y upgrade > /dev/null
    echo -e "${cText}--- Выполняем системные обновления ---${cNormal}"
    apt-get -y dist-upgrade > /dev/null
    echo -e "${cText}--- Выполняем удаление неиспользуемых пакетов ---${cNormal}"
    apt-get -y autoremove > /dev/null

  }

  # Функция настройки имени хоста
  doHosts() {
    echo -e "${cInfo}Установка имени хоста ${cGold}${HOSTNAME}${cNormal}"
    hostnamectl set-hostname ${HOSTNAME}

    echo -e "${cInfo}Установка ${cGold}resolvconf${cInfo}, так как файл ${cBlue}/etc/resolv.conf${cInfo} всё-равно генерируется автоматически,"
    echo -e "но с помощью этой службы можно контролировать этот процесс и вносить коррективы${cNormal}"
    apt-get -y install resolvconf > /dev/null
    echo -e "${cInfo}Создание основных записей для автоматического формирования файла ${cBlue}/etc/resolv.conf${cNormal}"
    echo -e "# Автоматически подставляется при поиске коротких имён хостов\ndomain ${REALM,,}\n# Список поиска для имён хостов. Обычно используется имя домена. При необходимости можно дополнить список\n# именами доменов через пробел. Последовательность имеет значение.\n# search ${REALM,,}\n# nameserver ${ADDRESS}" >/etc/resolvconf/resolv.conf.d/tail

    #for DNS in $DNSSERVERS ; do
    #    echo "nameserver ${DNS}" >>/etc/resolvconf/resolv.conf.d/tail
    #done

    echo -e "${cInfo}Корректировка файла ${cBlue}/etc/hosts${cNormal}"
    echo -e "127.0.0.1    localhost\n${ADDRESS}    ${HOSTNAME,,}.${REALM,,} ${HOSTNAME,,}\n\n# The following lines are desirable for IPv6 capable hosts\n::1     localhost ip6-localhost ip6-loopback\nff02::1 ip6-allnodes\nff02::2 ip6-allrouters" >/etc/hosts

  }

  # Функция настройки службы точного времени NTP
  doNTP() {
    # ======================================================
    echo -e "${cInfo}Настройка службы времени NTP${cNormal}"
    # ======================================================
    if [ ! -f "/etc/ntp.conf.old" ] ; then
       cp /etc/ntp.conf{,.old}
       extractLines "^## \/etc\/ntp\.conf" $1
       echo -e "${cRes}" >/etc/ntp.conf
    fi
    systemctl enable ntp || update-rc.d ntp defaults > /dev/null
    systemctl restart ntp || service ntp start > /dev/null
    echo -e "${cInfo}Проверка настроек получения эталонного времениe${cNormal}"
    ntpq -p
  }

  # Функция установки BIND9 из исходников
  doInstallBind9() {
    # =======================================================
    echo -e "${cInfo}Скачивание дистрибутива BIND9${cNormal}"
    # =======================================================
    # На момент написания данного скрипта, существовала стабильная версия 9.14.7, но устанавливалась 9.11.5
    if [[ ! -f "./bind-9.11.5.tar.gz" ]]; then
      wget https://downloads.isc.org/isc/bind9/9.11.5/bind-9.11.5.tar.gz
    fi
    echo -e "${cInfo}Распаковка архива с исходными файлами${cNormal}"
    tar xzvf bind-9.11.5.tar.gz
    cd bind-9.11.5
    echo -e "${cInfo}Подготовка к сборке. установка необходимых пакетов${cNormal}"
    sudo apt-get -y install make gcc python3 python3-ply openssl libssl-dev libxml2 libxml2-dev linux-headers-$(uname-r) libcap-dev libkrb5-dev libldap2-dev libz-dev zlib1g-dev
    if [ $? -ne 0 ]; then
      echo -e "${cRed}Произошла ошибка${cNormal}"
      exit 1
    fi
    ./configure --with-gssapi=/usr/include/gssapi --with-dlopen=yes --with-dlz-ldap --with-dlz-filesystem=yes --with-zlib
    if [ $? -ne 0 ]; then
      echo -e "${cRed}Произошла ошибка${cNormal}"
      exit 1
    fi
    make
    if [ $? -ne 0 ]; then
      echo -e "${cRed}Произошла ошибка${cNormal}"
      exit 1
    fi
    make install
    cd ..

    ln /usr/local/sbin/named /usr/sbin/named
  }

  # Функция установки необходимых пакетов
  doInstall() {
    for PACKAGE in $PACKAGES
    do
      apt-get -y install $PACKAGE
      if [ $? -ne 0 ]; then
         echo -e "${cRed}Произошла ошибка при установке ${cBlue}${PACKAGE}${cNormal}"
         exit 1
      fi
    done
  }

  # Функция установки VPN
  doVPN() {
    if [ "${VPNGW}" != "" ] ; then
      echo -e "${cInfo}Настройка VPN${cNormal}"
      if [ ! -d "/root/.secret" ] ; then
         mkdir /root/.secret
      fi
      echo -e "${cInfo}Формирование файла пароля ${cBlue}/root/.secret/pwd.vpn${cNormal}"
      touch /root/.secret/pwd.vpn
      echo "${VPNPWD}" > /root/.secret/pwd.vpn
      echo -e "${cInfo}Формирование файла управления VPN ${cBlue}/root/.secret/vpn.sh${cNormal}"
      extractLines "^## \/root\/\.secret\/vpn\.sh" $1
      echo "${cRes}" > /root/.secret/vpn.sh
      sed -i "s/{VPNUSR}/$VPNUSR/g;s/{VPNGW}/$VPNGW/g" /root/.secret/vpn.sh
      chmod 0600 /root/.secret/pwd.vpn
      chmod 0700 /root/.secret/vpn.sh
      echo -e "${cInfo}Формирование расписания для root"
      crontab -l >mycrontab
      if [ "$(grep '/root/.secret/vpn.sh' mycrontab)" == "" ] ; then
         echo "# Каждые 5 минут пытаться запустить VPN соединение. Если уже VPN работает, то повторно не соединится."
         echo "*/5 * * * * /root/.secret/vpn.sh" >> mycrontab
      else
         sed -i "s/^.*\/root\/\.secret\/vpn.sh/\*\/5 \* \* \* \* \/root\/\.secret\/vpn.sh/" mycrontab
      fi
      echo -e "${cText}*/5 * * * * /root/.secret/vpn.sh ${cNormal}"
      crontab mycrontab
      rm mycrontab
    fi

  }

  # Функция показа настроек
  doShowInfo() {
    echo -e "${cInfo}Будет создан контроллер домена со следующими параметрами:${cNormal}"
    echo -e "${cBlue}Дистрибутив Linux:                 ${cGold}$LINUXNAME${cNormal}"
    echo -e "${cBlue}Контроллер домена:                 ${cGold}$HOSTNAME${cNormal}"
    echo -e "${cBlue}Домен:                             ${cGold}$REALM${cNormal}"
    echo -e "${cBlue}Краткий домен:                     ${cGold}$DOMAIN${cNormal}"
    echo -e "${cBlue}IP адрес контроллера:              ${cGold}$ADDRESS${cNormal}"
    echo -e "${cBlue}Маска сети:                        ${cGold}$MASK${cNormal}"
    echo -e "${cBlue}Шлюз:                              ${cGold}$GATEWAY${cNormal}"
    echo -e "${cBlue}Сервера DNS:                       ${cGold}$DNSSERVERS${cNormal}"
    echo -e "${cBlue}Сервер перенаправления DNS:        ${cGold}$FORWARDDNS${cNormal}"
    echo -e "${cBlue}Пароль пользователя Administrator: ${cRed}$ADMPASWD${cNormal}"
    if [ "${VPNGW}" != "" ] ; then
       PACKAGES="${PACKAGES} openconnect"
       echo -e "${cBlue}VPN шлюз:                          ${cBlue}$VPNGW${cNormal}"
       echo -e "${cBlue}VPN пользователь:                  ${cGold}$VPNUSR${cNormal}"
       echo -e "${cBlue}Пароль VPN пользоателя:            ${cRed}$VPNPWD${cNormal}"
    fi
  }

  # Функция подготовки к настройке Samba
  doSambaPrepare() {
    echo -e "${cInfo}Отключение демонов, связанных с Samba${cNormal}"
    systemctl stop samba-ad-dc smbd nmbd winbind > /dev/null
    #systemctl disable samba-ad-dc smbd nmbd winbind
    if [[ ! -f "/etc/samba/smb.conf.old" ]] ; then
      echo -e "${cInfo}Переименование оригинального ${cBlue}smb.conf${cInfo} в ${cBlue}smb.conf.old${cInfo} на всякий случай${cNormal}"
      mv /etc/samba/smb.conf{,.old}
    fi

    echo -e "${cInfo}Удаление существующего smb.conf, созданного при установке${cNormal}"
    CONFIG=$(sudo smbd -b | egrep "CONFIGFILE" | cut -d ":" -f 2)
    if [[ "$CONFIG" != "" ]] ; then
       if [[ -f "$CONFIG" ]] ; then
          rm $CONFIG
       fi
    fi

    echo -e "${cInfo}Удаление всех файлов ${cBlue}*.tdb${cInfo} и ${cBlue}*.ldb${cInfo}, являющихся базой данных Samba для предотвращения неудачной настройки${cNormal}"
    SUBPATHS="LOCKDIR STATEDIR CACHEDIR PRIVATE_DIR"
    for SUBPATH in $SUBPATHS
    do
      CONFIG=$(sudo smbd -b | egrep "$SUBPATH" | cut -d ":" -f 2)
      if [[ "$CONFIG" != "" ]]; then
         if ls ${CONFIG}/*.tdb 1> /dev/null 2>&1; then
            rm ${CONFIG}/*.tdb
         fi
         if ls ${CONFIG}/*.ldb 1> /dev/null 2>&1; then
            rm ${CONFIG}/*.ldb
         fi
      fi
    done
    echo -e "${cInfo}Удаление существующего файла ${cBlue}/etc/krb5.conf${cNormal}"
    if [[ -f "/etc/krb5.conf" ]]; then
       rm /etc/krb5.conf
    fi
  }

  #!!!! Функция подготовки перед созданием домена в AstraLinux
  doDomainPrepareAstra() {
    # ===========================================
    echo -e "${cInfo}Настройка домена${cNormal}"
    # ===========================================

    exdomain=`astra-sambadc -i | grep "Forest" | grep "${DOMAIN}"`
    if [ "${exdomain}" == "" ] ; then
       echo -e "${cInfo}Отключение действующего домена${cNormal}"
       astra-sambadc -S

       echo -e "${cInfo}Удаление существующего smb.conf, созданного при установке${cNormal}"
       CONFIG=$(sudo smbd -b | egrep "CONFIGFILE" | cut -d ":" -f 2)
       if [[ "$CONFIG" != "" ]] ; then
          if [[ -f "$CONFIG" ]] ; then
             rm $CONFIG
          fi
       fi

       echo -e "${cInfo}Удаление всех файлов ${cBlue}*.tdb${cInfo} и ${cBlue}*.ldb${cInfo}, являющихся базой данных Samba для предотвращения неудачной настройки${cNormal}"
       SUBPATHS="LOCKDIR STATEDIR CACHEDIR PRIVATE_DIR"
       for SUBPATH in $SUBPATHS
       do
          CONFIG=$(sudo smbd -b | egrep "$SUBPATH" | cut -d ":" -f 2)
          if [[ "$CONFIG" != "" ]]; then
             if ls ${CONFIG}/*.tdb 1> /dev/null 2>&1; then
                rm ${CONFIG}/*.tdb
             fi
             if ls ${CONFIG}/*.ldb 1> /dev/null 2>&1; then
                rm ${CONFIG}/*.ldb
             fi
          fi
       done
       echo -e "${cInfo}Удаление существующего файла ${cBlue}/etc/krb5.conf${cNormal}"
       if [[ -f "/etc/krb5.conf" ]]; then
          rm /etc/krb5.conf
       fi
    fi
  }

  # Функция создания домена в Debian
  doDomainCreateDebian() {
    echo -e "${cInfo}Создание контроллера домена${cNormal}"
    samba-tool domain provision --use-rfc2307 --realm="${REALM}" --domain="${DOMAIN}" --host-name="${HOSTNAME}" --host-ip="${ADDRESS}" --adminpass="${ADMPASWD}" --dns-backend=BIND9_DLZ --server-role=dc
  }

  #!!! Функция создания домена AstraLinux
  doDomainCreateAstra() {
    if [ "${exdomain}" == "" ] ; then
       echo -e "${cInfo}Создание контроллера домена ${cGold}${DOMAIN}${cNormal}"
       astra-sambadc -b -d ${REALM} -p $ADMPASWD -y
    fi
  }

  # Функция проверки созданныъх файлов конфигурации в Astra Linux
  doCheckConfigsAstra() {
    echo -e "${cInfo}Проверка созданного системой файла конфигурации ${cBlue}/etc/samba/smb.conf${cNormal}"

    if [ ! -f "/etc/samba/smb.conf" ] || [ $(wc /etc/samba/smb.conf | awk '{ print $3 }') -le 400 ] ; then
       echo -e "${cRed}Опять ОС косячит, вот что получилось: ${cText}"
       cat /etc/samba/smb.conf

       doDomainCreateDebian

       echo -e "${cRed}=== ГЕНЕРИРУЕМ ФАЙЛ С НУЛЯ ===${cNormal}"

       extractLines "^## \/etc\/samba\/smb\.conf0" $1
       echo -e "${cRes}" > /etc/samba/smb.conf
       sed -i "s/{HOSTNAME}/${HOSTNAME^^}/;s/{REALM}/${REALM}/;s/{DOMAIN}/${DOMAIN}/;s/{REALMLOW}/${REALM,,}/" /etc/samba/smb.conf
       echo -en "${cText}"
       cat /etc/samba/smb.conf
       echo -en "${cNormal}"
       cp /usr/share/samba/smb.conf{,.old}

       cp /etc/samba/smb.conf /usr/share/samba/smb.conf
       doDNSon                  # Включение DNS
       doDomainConfigure        # Конфигурирование домена
       if [ $? -ne 0 ] ; then
          exit 1
       fi
    fi
  }

  # Функция включения сервера DNS
  doDNSon() {
    echo -e "${cInfo}Запуск службы DNS${cNormal}"
    systemctl start bind9 > /dev/null
    systemctl enable bind9 > /dev/null
  }

  # Функция донастроек для сетевого обнаружения и авторизации на сервре доменными учётными записями
  doDomainConfigure() {
    # named.conf
    echo -e "${cInfo}Настройка файла ${cBlue}/etc/bind/named.conf\n${cInfo}Добавление пути к файлу настроек зоны Samba:\n${cText}include \"/var/lib/samba/private/named.conf\";${cNormal}"
    if [[ $(grep "include \"/var/lib/samba/private/named.conf\";" /etc/bind/named.conf) = "" ]]; then
       echo "include \"/var/lib/samba/private/named.conf\";" >>/etc/bind/named.conf
    fi

    # named.conf.options
    echo -e "${cInfo}Настройка файла ${cBlue}/etc/bind/named.conf.options\n${cInfo}Добавляются строки:\n${cText}        tkey-gssapi-keytab \"/var/lib/samba/private/dns.keytab\";\n        forwarders {\n            ${FORWARDDNS};\n        };\n${cNormal}"
    if [[ $(grep "tkey-gssapi-keytab \"/var/lib/samba/private/dns.keytab\";" /etc/bind/named.conf.options) = "" ]]; then
       cp /etc/bind/named.conf.options{,.old}
       sed -i -e "/^};.*/s/^};/        tkey-gssapi-keytab \"\/var\/lib\/samba\/private\/dns\.keytab\";\n        forwarders {\n            ${FORWARDDNS};\n        };\n};\n/" /etc/bind/named.conf.options
    fi

    # samba named.conf
    echo -e "${cInfo}Настройка файла ${cBlue}/var/lib/samba/private/named.conf${cNormal}"
    local FILESO=$(named -v | cut -d " " -f 2 | cut -d "-" -f 1 | sed 's/\(.*\)\.\(.*\)\..*/dlz_bind\1_\2\.so/') #'
    local PATHFILESO=$(find / -name ${FILESO})
    echo $PATHFILESO
    echo $FILESO

    if [[ "${PATHFILESO}" != "" ]]; then
      if [ ! -f /var/lib/samba/private/named.conf ] ; then
         echo -e "dlz \"AD DNS Zone\" {\ndatabase \"dlopen ${PATHFILESO}\";\n};\n" > /var/lib/samba/private/named.conf
      fi
      if [[ $(cat /var/lib/samba/private/named.conf | grep "${PATHFILESO}") = "" ]]; then
         echo -e "dlz \"AD DNS Zone\" {\ndatabase \"dlopen ${PATHFILESO}\";\n};\n" > /var/lib/samba/private/named.conf
      fi
    else
        echo -e "${cRed}Произошла ошибка. файл ${FILESO} не найден.${cNormal}"
        exit 1
    fi

    # krb5.conf
    echo -e "${cInfo}Копирование файла настроек kerberos в ${cBlue}/etc/krb5.conf${cNormal}"
    cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
    echo -e "${cInfo}Разблокировка демона Samba${cNormal}"
    systemctl unmask samba-ad-dc > /dev/null
    if [ $? -ne 0 ]; then
       echo -e "${cRed}Произошла ошибка${cNormal}"
       exit 1
    fi
    echo -e "${cInfo}Запуск демона Samba${cNormal}"
    systemctl stop samba-ad-dc > /dev/null
    systemctl start  samba-ad-dc > /dev/null
    if [ $? -ne 0 ]; then
       echo -e "${cRed}Произошла ошибка${cNormal}"
       exit 1
    fi
    echo -e "${cInfo}Включение демона Samba${cNormal}"
    systemctl enable samba-ad-dc > /dev/null
    if [ $? -ne 0 ]; then
       echo -e "${cRed}Произошла ошибка${cNormal}"
       exit 1
    fi
    echo -e "${cInfo}Перезапуск сервера DNS${cNormal}"
    systemctl restart bind9 > /dev/null
    if [ $? -ne 0 ]; then
       echo -e "${cRed}Произошла ошибка${cNormal}"
       exit 1
    fi

  }

  # Функция донастроек для сетевого обнаружения и авторизации на сервре доменными учётными записями для Astra Linux
  doDomainConfigureAstra() {
    # named.conf
    echo -e "${cInfo}Настройка файла ${cBlue}/etc/bind/named.conf\n${cInfo}Добавление пути к файлу настроек зоны Samba:\n${cText}include \"/var/lib/samba/bind-dns/named.conf\";${cNormal}"
    if [[ $(grep "include \"/var/lib/samba/bind-dns/named.conf\";" /etc/bind/named.conf) = "" ]]; then
       echo "include \"/var/lib/samba/bind-dns/named.conf\";" >>/etc/bind/named.conf
    fi

    # named.conf.options
    echo -e "${cInfo}Настройка файла ${cBlue}/etc/bind/named.conf.options\n${cInfo}Добавляются строки:\n${cText}        tkey-gssapi-keytab \"/var/lib/samba/private/dns.keytab\";\n        forwarders {\n            ${FORWARDDNS};\n        };\n${cNormal}"
    if [[ $(grep "tkey-gssapi-keytab \"/var/lib/samba/private/dns.keytab\";" /etc/bind/named.conf.options) = "" ]]; then
       cp /etc/bind/named.conf.options{,.old}
       sed -i -e "/^};.*/s/^};/        tkey-gssapi-keytab \"\/var\/lib\/samba\/private\/dns\.keytab\";\n        forwarders {\n            ${FORWARDDNS};\n        };\n};\n/" /etc/bind/named.conf.options
    fi

    echo -e "${cInfo}Разблокировка демона Samba${cNormal}"
    systemctl unmask samba-ad-dc > /dev/null
    if [ $? -ne 0 ]; then
       echo -e "${cRed}Произошла ошибка${cNormal}"
       exit 1
    fi
    echo -e "${cInfo}Запуск демона Samba${cNormal}"
    systemctl stop samba-ad-dc > /dev/null
    systemctl start  samba-ad-dc > /dev/null
    if [ $? -ne 0 ]; then
       echo -e "${cRed}Произошла ошибка${cNormal}"
       exit 1
    fi
    echo -e "${cInfo}Включение демона Samba${cNormal}"
    systemctl enable samba-ad-dc > /dev/null
    if [ $? -ne 0 ]; then
       echo -e "${cRed}Произошла ошибка${cNormal}"
       exit 1
    fi
    echo -e "${cInfo}Перезапуск сервера DNS${cNormal}"
    systemctl restart bind9 > /dev/null
    if [ $? -ne 0 ]; then
       echo -e "${cRed}Произошла ошибка${cNormal}"
       exit 1
    fi

  }

  # Функция проверки настроек Domain и Kerberos
  doCheckDomain() {
    echo -e "${cInfo}Проверка уровня созданного домена${cNormal}"
    samba-tool domain level show
    if [ $? -ne 0 ]; then
       echo -e "${cRed}Произошла ошибка${cNormal}"
       exit 1
    fi

    echo -e "${cInfo}Проверка настройки kerberos${cNormal}"
    echo "${ADMPASWD}" | sudo kinit Administrator
    klist
    if [ $? -ne 0 ]; then
       echo -e "${cRed}Произошла ошибка${cNormal}"
       exit 1
    fi
  }

  # Функция настройки обратной зоны DNS
  doDNSReverceMake() {
    echo -e "${cInfo}Настройка обратной зоны DNS${cNormal}"
    IPX=$ADDRESS
    IP1=${IPX%%.*}
    IPX=${IPX#*.*}
    IP2=${IPX%%.*}
    IPX=${IPX#*.*}
    IP3=${IPX%%.*}
    IPX=${IPX#*.*}
    echo -e "${cBlue}${IP3}.${IP2}.${IP1}.in-addr.arpa${cNormal}"
    samba-tool dns zonecreate ${HOSTNAME,,}.${REALM,,} ${IP3}.${IP2}.${IP1}.in-addr.arpa > /dev/null
    if [ $? -ne 0 ]; then
       echo -e "${cRed}Произошла ошибка${cNormal}"
       exit 1
    fi
    echo -e "${cText}${IPX}    PTR ${HOSTNAME,,}.${REALM}${cNormal}"
    samba-tool dns add ${HOSTNAME,,}.${REALM,,} ${IP3}.${IP2}.${IP1}.in-addr.arpa ${IPX} PTR ${HOSTNAME,,}.${REALM,,} > /dev/null
  }

  # Функция настройки фаервола
  doFirewallConfigure() {
    # ===============================================
    echo -e "${cInfo}Настройка брандмауэра${cNormal}"
    # ===============================================
    local TCPPORTS="53 88 135 139 389 445 464 636 3268 3269 49152:65535"
    local UDPPORTS="53 88 123 137 138 389 464"

    if [ "$(iptables -L | egrep "^ufw")" != "" ] ; then
       # ufw установлен
       ufw logging on
       ufw limit 22/tcp
       for port in ${TCPPORTS}
       do
         ufw allow ${port}/tcp
         ufw allow out to any port ${port} proto tcp
       done
       for port in ${UDPPORTS}
       do
         ufw allow ${port}/udp
         ufw allow out to any port ${port} proto udp
       done
       ufw enable
       ufw status
    else
       # ufw не установлен
       echo -e "${cInfo}Брандмауэр не установлен${cNormal}"
    fi
  }

  # Функция настройки авторизации доменными пользователями
  doDomainUsersAutority() {
    # ==============================================================================
    echo -e "${cInfo}===Настройка авторизации доменными пользователями===${cNormal}"
    # ==============================================================================
    echo -e "${cInfo}Корректировка файла ${cBlue}/etc/nsswitch.conf${cNormal}"
    if [ "$(grep 'passwd:.*winbind' /etc/nsswitch.conf)" = "" ] ; then
       sed "/^passwd:/s/$/\twinbind/" /etc/nsswitch.conf
       sed -i "/^passwd:/s/$/\twinbind/" /etc/nsswitch.conf
    fi
    if [ "$(grep 'group:.*winbind' /etc/nsswitch.conf)" = "" ] ; then
       sed "/^group:/s/$/\twinbind/" /etc/nsswitch.conf
       sed -i "/^group:/s/$/\twinbind/" /etc/nsswitch.conf
    fi
    echo -e "${cInfo}Добавление команды создания домашнего каталога в файл ${cBlue}/etc/pam.d/common-session-noninteractive${cNormal}"
    if [ "$(grep 'mkhomedir' /etc/pam.d/common-session-noninteractive)" = "" ] ; then
       echo -e "${ctext}session required        pam_mkhomedir.so        umask=0077${cNormal}"
       sed -i "\$asession required        pam_mkhomedir.so        umask=0077" /etc/pam.d/common-session-noninteractive
    fi
    echo -e "${cInfo}Корректировка файла ${cBlue}/etc/samba/smb.conf${cInfo}. Добавление возможности входа на сервер доменными учётными записями${cNormal}"
    if [ "$(grep 'encrypt passwords = Yes' /etc/samba/smb.conf)" = "" ] ; then
       extractLines "## \/etc\/samba\/smb\.conf1" $1
       echo -e "${cText}${cRes}${cNormal}"
       echo "${cRes}" > incfile
       sed -i "/\[netlogon\]/ {
           r incfile
           a[netlogon]
           d }" /etc/samba/smb.conf
       extractLines "^## \/etc\/samba\/smb\.conf2" $1
       echo -e "${cText}${cRes}${cNormal}"
       echo "${cRes}" > incfile
       sed -i "\$r incfile" /etc/samba/smb.conf
       rm incfile
    fi
  }

  # Функция установки темы авторизации для Plasma, Debian
  doTemeLogonDebian() {
    # ===================================================================
    echo -e "${cInfo}Установка темы для авторизации на сервере${cNormal}"
    # ===================================================================
    if [ ! -d "/usr/share/sddm/themes/TVU1-v.1" ] ; then
       echo -e "${cInfo}Распаковка файла ${cBlue}TVU1-v.1.tar.gz${cInfo} в каталог ${cBlue}/usr/share/sddm/themes/TVU1-v.1${cNormal}"
       tar -C /usr/share/sddm/themes -xzvf TVU1-v.1.tar.gz > /dev/null
    fi

    if [ ! -f /etc/sddm.conf ] ; then
       extractLines "^## \/etc\/sddm\.conf" $1
       echo "${cRes}" >/etc/sddm.conf
    fi
    if [ "$(grep 'Current=TVU1-v.1' /etc/sddm.conf)" = "" ] ; then
       echo -e "${cInfo}Изменение текущей темы входа в файле ${cBlue}/etc/sddm.conf${cNormal}"
       sed -i "s/\(Current=\).*/\1TVU1-v.1/" /etc/sddm.conf
       dpkg-recofigure sddm
    fi
  }

  # Функция установки фона на рабочий стол пользователям для Plasma, Debian
  doWallpaperDebian() {
    # ========================================================================================
    echo -e "${cInfo}Подготовка к установке всем пользователям фона на рабочий стол${cNormal}"
    # ========================================================================================
    if [ ! -f "/usr/share/desktop-base/active-theme/wallpaper/contents/images/GVSMO_Zastavka-1.jpg" ] ; then
       echo -e "${cInfo}Распаковка файлов фонов в каталог ${cBlue}/usr/share/desktop-base/active-theme/wallpaper/contents/images/${cNormal}"
       tar -C /usr/share/desktop-base/active-theme/wallpaper/contents/images/ -xzvf GVSMO_Zastavka.tar.gz > /dev/null
    fi
    if [ ! -f "/usr/share/scripts/change-wallpaper.sh" ] ; then
       echo -e "${cInfo}Создание каталога с файлами ${cBlue}/usr/share/scripts/change-wallpaper.sh${cInfo} и ${cBlue}/usr/share/scripts/chwall.sh${cIndo} и ${cBlue}/usr/share/scripts/Фон.desktop${cNormal}"
       extractLines "^## \/usr\/share\/scripts\/change-wallpaper\.sh" $1
       cRes=$(echo "$cRes" | sed -e "s/{DOMAIN}/${DOMAIN}/g")
       echo $cRes
       mkdir /usr/share/scripts
       chmod 0755 /usr/share/scripts
       echo -e "${cRes}" > /usr/share/scripts/change-wallpaper.sh
       chmod 0755 /usr/share/scripts/change-wallpaper.sh
       extractLines "^## \/usr\/share\/scripts\/chwall\.sh" $1
       echo -e "${cRes}" > /usr/share/scripts/chwall.sh
       chmod 0755 /usr/share/scripts/chwall.sh
       extractLines "^## \/usr\/share\/scripts\/Фон\.desktop" $1
       echo -e "${cRes}" > /usr/share/scripts/Фон.desktop
       chmod 0755 /usr/share/scripts/Фон.desktop
       crontab -l > uscron
       if [ "$(grep 'change-wallpaper.sh' uscron)" = "" ] ; then
          echo "*/5 * * * * /usr/share/scripts/change-wallpaper.sh" >> uscron
          echo "0/5 * * * * /usr/share/scripts/change-wallpaper.sh" >> /etc/cron.d/wallpaper
          #     -   - - - -
          #     |   | | | +- День недели 0-7 (Восресенье 0 или 7)
          #     |   | | +--- Месяц 1-12
          #     |   | +----- День в месяце 1-31
          #     |   +------- Час 0-23
          #     +----------- Минуты 0-59
          #                  после символа / периодичность повторения в выбранном диапазоне (минуты, часы, дни, месяцы, года, дни недели)
          crontab uscron
          chmod 0644 /etc/cron.d/wallpaper
       fi
       rm uscron
    fi
  }

  # Функция установки фона на рабочий стол пользователям для fly, AstraLinux
  doWallpaperAstra() {
    # ========================================================================================
    echo -e "${cInfo}Подготовка к установке всем пользователям фона на рабочий стол${cNormal}"
    # ========================================================================================
    if [ ! -f "/usr/share/desktop-base/active-theme/wallpaper/contents/images/GVSMO_Zastavka-1.jpg" ] ; then
       mkdir -p /usr/share/desktop-base/active-theme/wallpaper/contents/images 2>&1
       echo -e "${cInfo}Распаковка файлов фонов в каталог ${cBlue}/usr/share/desktop-base/active-theme/wallpaper/contents/images/${cNormal}"
       tar -C /usr/share/desktop-base/active-theme/wallpaper/contents/images/ -xzvf GVSMO_Zastavka.tar.gz > /dev/null

       echo -e "${cInfo}Назначение фона для экрана блокировки.${cText} Хотя существуют файл конфигурации:\n  /usr/share/kstyle/themes/breeze.themerc\n  /usr/share/fly-wm/theme/default.themerc.fly-mini\n  /usr/share/fly-wm/theme/default.themerc.fly-kiosk\n  /usr/share/fly-wm/theme/current.themerc.fly-tablet-kiosk\n  /usr/share/fly-wm/theme/default.themerc.fly-tablet-kiosk\n  /usr/share/fly-wm/theme/current.themerc.fly-kiosk\n  /usr/share/fly-wm/theme/default.themerc.fly-tablet\n  /usr/share/fly-wm/theme/default.themerc.fly-mobile\n  /usr/share/fly-wm/theme/default.themerc,\n  но настойки из них не берутся, а используются жёстко прописанные пути к файлам в тексте програмы.\n Российские ПОграммисты из rusbitech постарались, чтобы нельзя было изменить их звёздный фон${cNormal}"
       # (окно авторизации)
       cp /usr/share/desktop-base/active-theme/wallpaper/contents/images/locker_panel_flat.png /usr/share/fly-wm/images/locker_panel_flat.png
       # (фон на окно разблокировки)
       cp /usr/share/desktop-base/active-theme/wallpaper/contents/images/background*.png /usr/share/fly-dm/themes/fly-flat/
       echo -e "${cInfo}Назначение фона на рабочий стол всем пользователям${cNormal}"
       sed -i "s/\(^Wallpaper=\).*/\1\/usr\/share\/desktop-base\/active-theme\/wallpaper\/contents\/images\/GVSMO_Zastavka-12\.jpg/" /etc/X11/fly-dm/backgroundrc
       for file in /usr/share/fly-wm/def*
       do
           sed -i "s/\(^Wallpaper=\).*/\1\/usr\/share\/desktop-base\/active-theme\/wallpaper\/contents\/images\/GVSMO_Zastavka-1\.jpg/" $file
           sed -i "s/\(^LogoPosition=\)/\1LogoPosition=NotShow/" $file
       done
       echo -e "${cInfo}Назначение темы логона для всех пользователей${cNormal}"
       mkdir -p /usr/share/fly-dm/themes/fly-tvu01 2>&1
       tar -C /usr/share/fly-dm/themes/ -xzvf fly-tvu01.tar.gz > /dev/null
       sed -i "s/\(^Theme=\).*/\1\/usr\/share\/fly-dm\/themes\/fly-tvu01/" /etc/X11/fly-dm/fly-dmrc
       extractLines "^## \/usr\/share\/scripts\/chwall_astra\.sh" $1
       echo -e "${cRes}" > /usr/share/scripts/chwall.sh
       chmod 0755 /usr/share/scripts/chwall.sh
       extractLines "^## \/usr\/share\/scripts\/chwall_astra\.desktop" $1
       echo -e "${cRes}" > /usr/share/fly-wm/Desktops/Desktop1/chwall.desktop
       chmod 0755 /usr/share/scripts/chwall.desktop
    fi

  }

  # Функция установки фона для загрузчика GRUB
  doGrubWallpaper() {
    # =================================================================
    echo -e "${cInfo}Замена фоновой картинки загрузчика GRUB${cNormal}"
    # =================================================================
    if [ "$(grep 'GVSMO_Zastavka.*\.jpg' /etc/default/grub)" = "" ] ; then
       echo -e "${cInfo}Изменение разрешения до 800х600${cNormal}"
       if [ "$(grep 'GRUB_GFXMODE' /etc/default/grub)" != "" ] ; then
          sed -i "s/^.*GRUB_GFXMODE.*$/GRUB_GFXMODE=800x600/" /etc/default/grub
       else
           echo "GRUB_GFXMODE=800x600" >> /etc/default/grub
       fi
       echo -e "${cInfo}Добавление фоновой картинки ${cBlue}/usr/share/desktop-base/active-theme/wallpaper/contents/images/GVSMO_Zastavka-1.jpg${cNormal}"
       echo 'GRUB_BACKGROUND="/usr/share/desktop-base/active-theme/wallpaper/contents/images/GVSMO_Zastavka-1.jpg"' >> /etc/default/grub
       update-grub
    fi
  }

  # Функция окончательной проверки настроек сервера
  doLastCheck() {
    echo -e "${cInfo}Проверка DNS${cNormal}"
    nslookup ${REALM,,}
    dig ${HOSTNAME,,}.${REALM,,}
    dig -x ${ADDRESS}
    ping -c 3 -a ${ADDRESS}
    echo -e "${cGold}Настройка завершена. Не забудьте на роутере/DHCP сервере сделать следующие настройки:${cText}"
    echo -e "DNS1:\t${ADDRESS}\nDNS2:\t8.8.8.8\nDomain:\t${REALM,,}\nWINS Servers:\t${ADDRESS}\nNTP Servers:\t${ADDRESS}${cNormal}"
  }

  # Функция установки антивируса. Для Linux подходит Dr.WEB, ESET NOD32
  doDefenderInstall() {
    # ===== NOD32 =====
    # +++++ ESET Security Management Center 7 (отдельные дистрибутивы для Linux)
    # https://download.eset.com/com/eset/apps/business/era/webconsole/latest/era.war                   Web-консоль
    # https://download.eset.com/com/eset/apps/business/era/server/linux/latest/server-linux-i386.sh    Сервер 32x
    # https://download.eset.com/com/eset/apps/business/era/server/linux/latest/server-linux-x86_64.sh  Сервер 64х
    # https://download.eset.com/com/eset/apps/business/era/agent/latest/agent-linux-i386.sh            Агент 32x
    # https://download.eset.com/com/eset/apps/business/era/agent/latest/agent-linux-x86_64.sh          Агент 64x
    # https://download.eset.com/com/eset/apps/business/era/rdsensor/latest/rdsensor-linux-i386.sh      Средство обнаружения неизвестных компьютеров 32х
    # https://download.eset.com/com/eset/apps/business/era/rdsensor/latest/rdsensor-linux-x86_64.sh    Средство обнаружения неизвестных компьютеров 64х
    # +++++ ESET NOD32 Антивирус для Linux Desktop
    # https://download.esetnod32.ru/home/trial/linux/eset_nod32av_32bit_ru.linux                       32x 30 дней пробная.
    # https://download.esetnod32.ru/home/trial/linux/eset_nod32av_64bit_ru.linux                       64x 30 дней пробная.
    # Dr.WEB
    # ----- Dr.WEB - Центр упраления предоставляется по запросу
    # ----- Dr.WEB - Dr.Web для Linux
    # https://download.geo.drweb.com/pub/drweb/unix/workstation/11.1/drweb-11.1.1-av-linux-x86.run     30 дней пробная на десктоп.
    # https://download.geo.drweb.com/pub/drweb/unix/workstation/11.1/drweb-11.1.1-av-linux-amd64.run   30 дней пробная на десктоп.
    wget https://download.geo.drweb.com/pub/drweb/unix/workstation/11.1/drweb-11.1.1-av-linux-amd64.run
    bash drweb-11.1.1-av-linux-amd64.run
  }

  # Функция извлечения файлов заставки
  doGSVMOExtract() {
    extractLines "^## \.\/GVSMO_Zastavka\.tar\.gz" $1
    echo "$cRes" > ./GVSMO_Zastavka.tar.gz_base64
    base64 -d ./GVSMO_Zastavka.tar.gz_base64 >./GVSMO_Zastavka.tar.gz
    rm ./GVSMO_Zastavka.tar.gz_base64
  }

  # Функция извлечения файлов темы для Plasma
  doTVUExtract() {
    extractLines "^## \.\/TVU1-v\.1\.tar\.gz" $1
    echo "$cRes" > ./TVU1-v.1.tar.gz_base64
    base64 -d ./TVU1-v.1.tar.gz_base64 >./TVU1-v.1.tar.gz
    rm ./TVU1-v.1.tar.gz_base64
  }

  # Функция извлечения файлов темы для Astra-Linux
  doFlyExtract() {
    extractLines "^## \.\/fly-tvu01\.tar\.gz" $1
    echo "$cRes" > ./fly-tvu01.tar.gz_base64
    base64 -d ./fly-tvu01.tar.gz_base64 >./fly-tvu01.tar.gz
    rm ./fly-tvu01.tar.gz_base64
  }


  # Список устанавливаемых пакетов
  #local PACKAGES="ntp python3-ply bind9utils bind9 dnsutils libnss-winbind libpam-winbind winbind krb5-kdc krb5-admin-server krb5-config krb5-user samba smbclient"
  local PACKAGES="ntp python3-ply bind9utils bind9 dnsutils libnss-winbind libpam-winbind krb5-kdc krb5-admin-server samba smbclient"
  # lsb-core
  echo -e "
${cInfo}===================================================================
Создание контроллера домена согласно руководству Samba
${cUrl}https://wiki.samba.org/index.php/Active_Directory_Domain_Controller${cInfo}
и ${cUrl}https://unlis.ru/?p=501${cInfo}
===================================================================${cNormal}\n"

  if [ "$pRemove" -eq "1" ] ; then
     echo -e "${cRed}Удаление контроллера домена с настройками${cNormal}"
     if [ "$pYes" -ne "1" ] ; then
        echo -e "${cInfo}"
        myAskYNE "Продолжить?"
     fi
     for PACKAGE in $PACKAGES
     do
       sudo apt-get -y purge ${PACKAGE}
     done
     sudo apt-get -y purge python3-ply libssl-dev libxml2-dev linux-headers-$(uname -r) libcap-dev libkrb5-dev libldap2-dev libz-dev zlib1g-dev
     sudo apt-get -y autoremove
     exit 0
  else
    echo -en "${cNone}"
    local HOSTNAME=`awk -F "=" '/^HOSTNAME/{print $2}' $1 | sed 's/^"\(.*\)"$/\1/'`
    local REALM=`awk -F "=" '/^REALM/{print $2}' $1 | sed 's/^"\(.*\)"$/\1/'`
    local ADDRESS=`awk -F "=" '/^ADDRESS/{print $2}' $1 | sed 's/^"\(.*\)"$/\1/'`
    local MASK=`awk -F "=" '/^MASK/{print $2}' $1 | sed 's/^"\(.*\)"$/\1/'`
    local GATEWAY=`awk -F "=" '/^GATEWAY/{print $2}' $1 | sed 's/^"\(.*\)"$/\1/'`
    local ADMPASWD=`awk -F "=" '/^ADMPASWD/{print $2}' $1 | sed 's/^"\(.*\)"$/\1/'`
    local DNSSERVERS=`awk -F "=" '/^DNSSERVERS/{print $2}' $1 | sed 's/^"\(.*\)"$/\1/'`
    local FORWARDDNS=`sed -e 's/^\([0-9\.]*\).*/\1/' <<<${DNSSERVERS}`
    local DOMAIN=`sed 's/\..*//' <<<${REALM}`
    local VPNGW=`awk -F "=" '/^VPNGW/{print $2}' $1 | sed 's/^"\(.*\)"$/\1/'`
    local VPNUSR=`awk -F "=" '/^VPNUSR/{print $2}' $1 | sed 's/^"\(.*\)"$/\1/'`
    local VPNPWD=`awk -F "=" '/^VPNPWD/{print $2}' $1 | sed 's/^"\(.*\)"$/\1/'`
    local AUTODHCP="no"
    local LINUXNAME=`lsb_release -a | grep "Description" | sed -e 's/^.*:[\ *\t*]\([0-9a-zA-Z\ ]*\).*/\1/' | rev | sed -e 's/^[\ 0-9]*\(.*$\)/\1/' | rev`
    echo -en "${cNormal}"
    local grp=$(grep "." <<< $MASK)
    if [ "$grp" != "" ] ; then
       oct2count ${MASK%%.*} ; local oct1=$cRes ; local MASK=${MASK#*.*}
       oct2count ${MASK%%.*} ; local oct2=$cRes ; local MASK=${MASK#*.*}
       oct2count ${MASK%%.*} ; local oct3=$cRes ; local MASK=${MASK#*.*}
       oct2count ${MASK%%.*} ; local oct4=$cRes
       local MASK=$oct1
       if [[ "$oct1" = "8" && "$oct2" != "-1" ]] ; then
          local MASK=$(($MASK + $oct2))
          if [[ "$oct2" = "8" && $oct3 != "-1" ]] ; then
             local MASK=$(($MASK + $oct3))
             if [[ "$oct3" = "8" && $oct4 != "-1" ]] ; then
                local MASK=$(($MASK + $oct4))
             fi
          fi
       fi
    fi
    local NETWORK="${ADDRESS}/${MASK}"

    doShowInfo # Показ информации

    if [ "$pYes" -ne "1" ] ; then
       echo -e "${cGold}\e[5mВсе предыдущие настройки будут уничтожены!${cNormal}"
       echo -e "${cInfo}"
       myAskYNE "Продолжить?"
    fi

    #===================================================
    # Настройка сетевого интерфейса через NetworkManager
    #===================================================
    doEthernet
    if [ "$?" -ne "0" ] ; then
       exit 1
    fi

    doUpdate # Обновления системы
    doHosts  # Сайты

    # ===================================================
    # Меняем false на true в случае, если BIND не
    # поддерживает DLZ_BIND для сопряжения Samba и BIND9
    # ===================================================
    if false; then
       doInstallBind9
    fi

    # =========================================
    # -----------------------------------------
    if [ "${LINUXNAME}" = "Debian GNU" ] ; then
    # -----------------------------------------
    # =========================================
       echo -e "${cInfo}Установка пакетов для работы с Microsoft Active Directory\nПри установке будет запрошена настройка kerberos.\nУкажите область kerberos по умолчанию: ${cGold}${REALM}${cInfo}\nи управляющий сервер ${cGold}${HOSTNAME}.${REALM,,}${cNormal}"
       if [ "$pYes" -ne "1" ] ; then
          echo -e "${cInfo}\e[5m"
          sayWait
       fi

       doInstall                # Предварительная установка пакетов
       if [ $? -ne 0 ] ; then
          exit 1
       fi

       doNTP $@                 # Служба времени
       doVPN $@                 # Настройка VPN если он необходим
       doGSVMOExtract $@        # Извлечение архива фоновых картинок
       doTVUExtract $@          # Извлечение архива темы для Plasma
       doSambaPrepare           # Подготовка перед созданием домена
       doDomainCreateDebian     # Создание домена
       doDNSon                  # Включение DNS
       doDomainConfigure        # Конфигурирование домена
       if [ $? -ne 0 ] ; then
          exit 1
       fi

       doCheckDomain            # Проверка домена
       if [ $? -ne 0 ] ; then
          exit 1
       fi

       doDNSReverceMake         # Настройка обратной зоны DNS
       if [ $? -ne 0 ] ; then
          exit 1
       fi
       doFirewallConfigure      # Настройка фаервола
       doDomainUsersAutority $@ # Настройка авторизации доменными пользователями
       doTemeLogonDebian $@     # Установка темы для авторизации
       doWallpaperDebian $@     # Установка фона на рабочий стол пользователей
       doGrubWallpaper $@       # Установка фона загрузчику
       doDefenderInstall        # Установка Ативируса
       doLastCheck              # Окончательная проверка

    fi
    
    if [ "$LINUXNAME" = "Astra Linux CE" ] ; then

       local PACKAGES="ntp python3-ply bind9utils bind9 dnsutils fly-admin-ad-server fly-admin-ad-client libnss-winbind libpam-winbind krb5-kdc krb5-admin-server samba smbclient"
       doInstall                # Предварительная установка пакетов
       if [ $? -ne 0 ] ; then
          exit 1
       fi

       doNTP $@                  # Служба времени
       doVPN $@                  # Установка VPN если необходимо
       doGSVMOExtract $@         # Извлечение архива фоновых картинок
       doFlyExtract $@           # Извлечение темы для Astra Linux
       doSambaPrepare            # Подготовка перед созданием домена
       doDomainPrepareAstra      # Подготовка перед созданием домена
       doDomainCreateAstra       # Создание домена
       doCheckConfigsAstra $@    # Проверка созданных конфигурационных файлов
       if [ $? -ne 0 ] ; then
          exit 1
       fi
       doDomainConfigureAstra $@ # Донастройка домена
       if [ $? -ne 0 ] ; then
          exit 1
       fi

       doCheckDomain             # Проверка домена
       if [ $? -ne 0 ] ; then
          exit 1
       fi
       doDNSReverceMake          # Настройка обратной зоны DNS
       if [ $? -ne 0 ] ; then
          exit 1
       fi
       doFirewallConfigure       # Настройка фаервола
       doDomainUsersAutority $@  # Настройка авторизации доменными пользователями
       doWallpaperAstra $@       # Установка фона на рабочий стол пользователей
       doGrubWallpaper $@        # Установка фона загрузчику
       doDefenderInstall         # Установка Ативируса
       doLastCheck               # Окончательная проверка
    fi
  fi
}

sudo bash -c "$(declare -f mainProc); mainProc $0 $*"

exit 0
