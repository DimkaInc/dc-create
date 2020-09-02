#!/bin/bash
NUM=`echo | awk ' { srand(); print int(1+rand()*20); } '`
CMD='string:
var Desktops = desktops();
for (i=0;i<Desktops.length;i++) {
        d = Desktops[i];
        d.wallpaperPlugin = "org.kde.image";
        d.currentConfigGroup = Array("Wallpaper",
                                    "org.kde.image",
                                    "General");
        d.writeConfig("Image", "file:///usr/share/desktop-base/active-theme/wallpaper/contents/images/GVSMO_Zastavka-{NUM}.jpg");
}'
CMD=$(echo "$CMD" | sed -e "s/{NUM}/$NUM/")
dbus-send --session --dest=org.kde.plasmashell --type=method_call /PlasmaShell org.kde.PlasmaShell.evaluateScript "$CMD"
