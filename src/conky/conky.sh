#!/bin/bash

cp -r /usr/share/scripts/conky/.conky $HOME
cp /usr/share/scripts/conky/conky.desktop $HOME/.config/autostart/
chown -r $USER:$USER $HOME/.conky
chown $USER:$USER $HOME/.config/autostart/conky.desktop
