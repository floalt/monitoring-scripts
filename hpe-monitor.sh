#!/bin/bash

### rudimentary hardware monitoring for HPE ProLiant Microserver

# description:
#   Checks the following values via the local iLO interface:
#       CPU temperature, chipset temperature, fan speed
#   In case of an error, an alarm is triggered via email
#
#   Configuration: see 'hpe-monitor.conf' file
#
# author: flo.alt@it-flows.de
# version: 1.0.0



# Read configuration file

SCRIPTPATH=$(dirname "$(readlink -e "$0")")
CONFIG_FILE="$SCRIPTPATH/hpe-monitor.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Configuration file $CONFIG_FILE not found!"
    exit 1
fi
source "$CONFIG_FILE"


# Check if ipmitool is installed, if not, install it

if ! command -v ipmitool &> /dev/null; then
    echo "ipmitool not found, installing..."
    apt update && apt install -y ipmitool
fi


# Retrieve system values

temp_cpu=$(ipmitool sensor get "02-CPU 1" | awk -F': ' '/Sensor Reading/ {print $2}' | awk '{print $1}')
temp_chipset=$(ipmitool sensor get "07-Chipset" | awk -F': ' '/Sensor Reading/ {print $2}' | awk '{print $1}')
fan_speed=$(ipmitool sensor get "Fan 1 DutyCycle" | awk -F': ' '/Sensor Reading/ {print $2}' | awk '{print $1}')


# Check values

CRITICAL_TEMP=80  # Critical temperature threshold
CRITICAL_FAN=5    # Minimum fan duty cycle percentage

if (( $(echo "$temp_cpu >= $CRITICAL_TEMP" | bc -l) )) ||
   (( $(echo "$temp_chipset >= $CRITICAL_TEMP" | bc -l) )) ||
   (( $(echo "$fan_speed < $CRITICAL_FAN" | bc -l) )); then

    # Check which value triggered the alarm
    alarm_message=""
    if (( $(echo "$temp_cpu >= $CRITICAL_TEMP" | bc -l) )); then
        alarm_message+="CPU temperature: $temp_cpu°C (ALARM)\n"
    else
        alarm_message+="CPU temperature: $temp_cpu°C\n"
    fi

    if (( $(echo "$temp_chipset >= $CRITICAL_TEMP" | bc -l) )); then
        alarm_message+="Chipset temperature: $temp_chipset°C (ALARM)\n"
    else
        alarm_message+="Chipset temperature: $temp_chipset°C\n"
    fi

    if (( $(echo "$fan_speed < $CRITICAL_FAN" | bc -l) )); then
        alarm_message+="Fan speed: $fan_speed% (ALARM)\n"
    else
        alarm_message+="Fan speed: $fan_speed%\n"
    fi

    # Email content
    email_content="Subject: [$CUSTOMER_NAME] $EMAIL_SUBJECT\n\n$alarm_message\nPlease check!"

    # Send email
    echo -e "$email_content" | mail -s "[$CUSTOMER_NAME] $EMAIL_SUBJECT" "$EMAIL_TO"
fi
