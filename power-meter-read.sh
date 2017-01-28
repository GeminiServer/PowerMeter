#!/bin/bash
#    _____  ____             __        __   _____  ____               ____
#   / ____||___ \           /_ |      /_ | / ____||___ \             |___ \
#  | |  __   __) | _ __ ___  | | _ __  | || (___    __) | _ __ __   __ __) | _ __
#  | | |_ | |__ < | '_ ` _ \ | || '_ \ | | \___ \  |__ < | '__|\ \ / /|__ < | '__|
#  | |__| | ___) || | | | | || || | | || | ____) | ___) || |    \ V / ___) || |
#   \_____||____/ |_| |_| |_||_||_| |_||_||_____/ |____/ |_|     \_/ |____/ |_|
#
#  Author: Erkan Colak - 01.02.2014 / 09.05.2015
#  lesezeahler v0.2
#  read and evaluate SML output received from EMH eHZ

# set serial device
clear

echo ""
echo "Reading Power Meter eHZ - Haushaltsstrom und Waermepumpe"
echo "Erkan Colak - 05.01.2016"
echo "v0.2"
echo ""

command -v bc >/dev/null 2>&1 || { echo >&2 "'bc' is required, but it's not installed. Please install it and try again. ('apt-get install bc')  Aborting!"; exit 1; }

INPUT_DEV_wp="/dev/usb-ir-lesekopf-wp"
INPUT_NAME_wp="Waermepumpe"
INPUT_PMNR_wp="5026782"

INPUT_DEV_hz="/dev/usb-ir-lesekopf-hz"
INPUT_NAME_hz="Haushaltsstrom"
INPUT_PMNR_hz="5026783"

if [ -e "$INPUT_DEV_wp" ]; then echo "Checking: "$INPUT_DEV_wp " exist... OK"; else echo $INPUT_DEV_wp "is required and cloud not be detected. Aborting!"; exit 1; fi
if [ -e "$INPUT_DEV_hz" ]; then echo "Checking: "$INPUT_DEV_hz " exist... OK"; else echo $INPUT_DEV_wp "is required and cloud not be detected. Aborting!"; exit 1; fi

iMeterReadSize="460"
SML_START_SEQUENCE="1B1B1B1B0101010176"
iMeter1="298"
iMeter2="340"
iMeter3="382"
iMeter4="424"
iRepeatCount="5"
DEBUGMODE="0"

if [ "$1" != "" ]; then DEBUGMODE="$1"; fi

#set $INPUT_DEV to 9600 8N1
echo "Settings input devices to 9600 8N1... OK"
stty -F $INPUT_DEV_wp 1:0:8bd:0:3:1c:7f:15:4:5:1:0:11:13:1a:0:12:f:17:16:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0
stty -F $INPUT_DEV_hz 1:0:8bd:0:3:1c:7f:15:4:5:1:0:11:13:1a:0:12:f:17:16:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0
echo ""
METER_OUTPUT__START_SEQUENCE=""
i="0"

function e {
  INPUT_DEV=$1
  INPUT_NAME=$2
  INPUT_PMNR=$3
  echo "Reading Power Meter vlaues from:" $INPUT_NAME "("$INPUT_DEV")"
  while [ "$METER_OUTPUT__START_SEQUENCE" != "$SML_START_SEQUENCE" ]
  do
        READEHZ=`cat $INPUT_DEV 2>/dev/null | xxd -p -u -l $iMeterReadSize`
        METER_OUTPUT=${READEHZ//[[:space:]]/}
        METER_OUTPUT__START_SEQUENCE=$(echo "${METER_OUTPUT:0:18}")
        if [ $METER_OUTPUT__START_SEQUENCE != $SML_START_SEQUENCE ]; then if [ "$DEBUGMODE" == 1 ]; then echo "missed start and trying again..."; fi
             #exit 1
        fi
  done

  if [ "$DEBUGMODE" == 1 ]; then echo $METER_OUTPUT; echo; fi

  let METER_180=0x${METER_OUTPUT:$iMeter1:10}; VALUE1=$(echo "scale=4; $METER_180 / 10000" |bc)
  let METER_180=0x${METER_OUTPUT:$iMeter2:10}; VALUE2=$(echo "scale=4; $METER_180 / 10000" |bc)
  let METER_180=0x${METER_OUTPUT:$iMeter3:10}; VALUE3=$(echo "scale=4; $METER_180 / 10000" |bc)
  let METER_180=0x${METER_OUTPUT:$iMeter4:8};  VALUE4=$(echo "scale=2; $METER_180 / 10" |bc)

  echo "               Zaehler-Name: "$INPUT_NAME
  echo "             Zaehler-Nummer: "$INPUT_PMNR
  echo "                 Lese-Datum: "$(date +%d)"."$(date +%m)"."$(date +%Y)" "$(date +%H)":"$(date +%m)":"$(date +%S)
  if [ "$DEBUGMODE" == 1 ]; then echo "   Meter 1.8.0 (from plant): "$VALUE1 "kWh (HEX:"${METER_OUTPUT:$iMeter1:10}")";
  else echo "   Meter 1.8.0 (from plant): "$VALUE1 "kWh"; fi
  if [ "$DEBUGMODE" == 1 ]; then echo "     Meter 2.8.0 (to plant): "$VALUE2 "kWh (HEX:"${METER_OUTPUT:$iMeter2:10}")";
  else echo "     Meter 2.8.0 (to plant): "$VALUE2 "kWh"; fi
  if [ "$DEBUGMODE" == 1 ]; then echo "     Meter 2.8.0 (to plant): "$VALUE3 "kWh (HEX:"${METER_OUTPUT:$iMeter3:10}")";
  else echo "     Meter 2.8.0 (to plant): "$VALUE3 "kWh"; fi
  if [ "$DEBUGMODE" == 1 ]; then echo "Total effective power (+/-): "$VALUE4 "W (HEX:"${METER_OUTPUT:$iMeter4:8}")";
  else echo "Total effective power (+/-): "$VALUE4 "W"; fi

  METER_OUTPUT__START_SEQUENCE=""
  echo ""
  echo ""
}

while [ $i -lt $iRepeatCount ]
do
e $INPUT_DEV_wp $INPUT_NAME_wp $INPUT_PMNR_wp
e $INPUT_DEV_hz $INPUT_NAME_hz $INPUT_PMNR_hz
echo "Starting next read sequence.."
sleep 5
i=$[$i+1]
done
