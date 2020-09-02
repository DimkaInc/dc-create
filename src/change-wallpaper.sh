for i in $(sudo find /home/ -depth -wholename "*{DOMAIN}*/autostart-scripts")
do
  USER=$(echo $i | sed -e "s/^.*{DOMAIN}\/\(.*\)\/\.config.*/\1/")
  # "
  k="/home/{DOMAIN}/${USER}/Рабочий стол/Фон.desktop"
  if [ ! -f "$k" ] ; then
     ln -s /usr/share/scripts/Фон.desktop "$k"
#     chown ${USER}:${USER} $i/chwall.sh
#     chmod 0755 $i/chwall.sh
#     crontab -u ${USER} -l > uscron
#     if [ "$(grep 'chwall.sh' uscron)" = "" ] ; then
#        echo "*/5 * * * * $i/chwall.sh" >> uscron
#        crontab -u ${USER} uscron
#     fi
#     rm uscron
  fi
done
