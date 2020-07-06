#!/bin/bash
# Just a small timeout to make sure we are being shown last while booting...
sleep 1s

color=41
color=42

if [ $color -eq 42 ]
then
    text="  System Okay!  "
else
    text="💀 System Hackd 💀"
fi

echo -e "\e[${color}m                                    "
echo -e "\e[${color}m                                    "
echo -e "\e[${color}m                                    "
echo -e "\e[${color}m   \e[49m                  \e[${color}m         \e[49m"
echo -e "\e[${color}m \e[49m ${text}   \e[${color}m         \e[49m"
echo -e "\e[${color}m   \e[49m                  \e[${color}m         \e[49m"
echo -e "\e[${color}m                                     "
echo -e "\e[${color}m                                     "
echo -e "\e[${color}m                                     "
echo -e "\e[49m"
exit

