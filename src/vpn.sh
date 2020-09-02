#!/bin/bash
# **********************************************
# * Скрипт для запуска/остановки vpn соединения
# * Использование:
# * vpn.sh [start|stop|restart|reload|status]
# * (c) -+= Dimka Inc =+-
# **********************************************
# VPN Шлюз
VPNGATEWAY={VPNGW}
# Имя пользователя
USERNAME={VPNUSR}
# Файл с паролем пользователя
PWDFILE=/root/.secret/pwd.vpn

# Функция запуска VPN
start() {
    if [ "$(pidof openconnect)" != "" ] ; then
       echo "VPN уже включен"
       exit 1
    fi
    echo "Запуск VPN"
    cat ${PWDFILE} | openconnect -b ${VPNGATEWAY} --user ${USERNAME} --passwd-on-stdin
    echo "VPN работает"
}

# Функция останова VPN
stop() {
    if [ "$(pidof openconnect)" = "" ] ; then
       echo "VPN не запущен"
       exit 1
    fi
    echo "Остановка VPN"
    sudo kill -9 $(pidof openconnect)
    echo "VPN выключен"
}

case "$1" in
    start)
         start
         ;;
    stop)
         stop
         ;;
    restart|reload|condrestart)
         stop
         start
         ;;
    status)
         if [ "$(pidof openconnect)" = "" ] ; then
            echo "VPN не запущен"
            exit 2
         else
             echo "VPN работает"
             exit $(pidof openconnect)
         fi
esac
