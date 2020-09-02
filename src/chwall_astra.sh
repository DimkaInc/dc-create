#!/bin/bash
NUM=`echo | awk ' { srand(); print int(1+rand()*20); } '`
echo ${NUM}
fly-wmfunc FLYWM_UPDATE_VAL WallPaper "/usr/share/desktop-base/active-theme/wallpaper/contents/images/GVSMO_Zastavka-${NUM}.jpg"
