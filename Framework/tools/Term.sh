#!/bin/bash
########################################################################################################################
# Uart Terminal starten
#-----------------------------------------------------------------------------------------------------------------------
# \project    Jfe
# \file       Term.sh
# \creation   2014-05-10, Joe Merten
########################################################################################################################

declare PARAMS=""
declare BAUD="115200"
declare DEVICE=""
declare DEVICE_P=""
declare LOGFN="auto"
declare CONFIG="tmp-rtscts"
declare CONFIGFN="$HOME/.minirc.$CONFIG"
declare HWFLOW="false"
declare VERBOSE="false"
declare LOOP="false"
declare STTY_DELAY=""
declare FORCE_STTY="false"
declare LOWER_RTS="false"

declare USE_MINICOM="false"
declare USE_PICOCOM="false"
declare OLD_PICOCOM="false"
declare USE_PYTERM="false"
declare USE_PYLOG="false"
declare USE_PULOG="false"

function ShowHelp {
    echo "Minicom / Picocom / ... starterscript, Joe Merten 2014"
    echo "usage: $0 <device> [options] ..."
    echo "  <device>       - z.B. '/dev/ttyUSB0' oder 'ttyUSB0' ..."
    echo "Available options:"
    echo "  <baudrate>     - e.g. 230k or 1M, ... default is 115200"
    echo "  --hwflow       - enable hardware flowcontrol via rts/cts"
    echo "  -v             - dont start the uart terminal application but show the command line(s) instead"
    echo "  --minicom      - use minicomm"
    echo "  --picocom      - use picocom (default)"
    echo "  --pyterm       - use python miniterm (python3 -m serial.tools.miniterm)"
    echo "  --pylog        - use python tiny logging script"
    echo "  --pulog        - use Pulog.py"
        echo "  --logfile <fn> - specify logfile, \"none\" = disable logfile recording, default logfile is located in $HOME"
    echo "  --delay <n>    - delay between stty and (old) picocom start, sometimes needed for some CDC devices"
    echo "  --loop         - repeated start of terminal application, useful if e.g. Usb device disapears temporarily"
    echo "                   this also checks the existend of the specified serial device before starting the terminal application"
    echo "  --stty         - force usage of stty command before starting the terminal application"
    echo "  --lower-rts    - force rts handshake to be inactive after opening the serial port"
}


while (("$#")); do
  if [ "$1" == "?" ] || [ "$1" == "-?" ] || [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ]; then
    ShowHelp
    exit 0
  elif [[ "$1" =~ ^[0-9]+$ ]]; then BAUD="$1"
  elif [ "$1" ==  "19k" ] || [ "$1" ==  "19K" ]; then   BAUD="19200"
  elif [ "$1" ==  "38k" ] || [ "$1" ==  "38K" ]; then   BAUD="38400"
  elif [ "$1" ==  "57k" ] || [ "$1" ==  "57K" ]; then   BAUD="57600"
  elif [ "$1" == "115k" ] || [ "$1" == "115K" ]; then  BAUD="115200"
  elif [ "$1" == "230k" ] || [ "$1" == "230K" ]; then  BAUD="230400"
  elif [ "$1" == "250k" ] || [ "$1" == "250K" ]; then  BAUD="250000"
  elif [ "$1" == "460k" ] || [ "$1" == "460K" ]; then  BAUD="460800"
  elif [ "$1" == "500k" ] || [ "$1" == "500K" ]; then  BAUD="500000"
  elif [ "$1" == "921k" ] || [ "$1" == "921K" ]; then  BAUD="921600"
  elif [ "$1" ==   "1m" ] || [ "$1" ==   "1M" ]; then BAUD="1000000"
  elif [ "$1" ==  "1m5" ] || [ "$1" ==  "1M5" ]; then BAUD="1500000"
  elif [ "$1" ==   "2m" ] || [ "$1" ==   "2M" ]; then BAUD="2000000"
  elif [ "$1" ==   "3m" ] || [ "$1" ==   "3M" ]; then BAUD="3000000"
  elif [ "$1" ==   "4m" ] || [ "$1" ==   "4M" ]; then BAUD="4000000"
  elif [ "$1" ==   "5m" ] || [ "$1" ==   "5M" ]; then BAUD="5000000"
  elif [ "$1" ==   "6m" ] || [ "$1" ==   "6M" ]; then BAUD="6000000"
  elif [ "$1" ==   "7m" ] || [ "$1" ==   "7M" ]; then BAUD="7000000"
  elif [ "$1" ==   "8m" ] || [ "$1" ==   "8M" ]; then BAUD="8000000"
  elif [[ "$1" =~ ^/dev/tty     ]]; then DEVICE="$1"
  elif [[ "$1" =~ ^tty*         ]]; then DEVICE="/dev/$1"
  elif [[ "$1" =~ ^/dev/serial/ ]]; then DEVICE="$1"
  elif [ "$1" == "--hwflow"  ] || [ "$1" == "hwflow"  ];   then HWFLOW="true"
  elif [ "$1" == "--minicom" ] || [ "$1" == "minicom" ];   then USE_MINICOM="true"
  elif [ "$1" == "--picocom" ] || [ "$1" == "picocom" ];   then USE_PICOCOM="true"
  elif [ "$1" == "--pyterm"  ] || [ "$1" == "pyterm"  ];   then USE_PYTERM="true"
  elif [ "$1" == "--pylog"   ] || [ "$1" == "pylog"   ];   then USE_PYLOG="true"
  elif [ "$1" == "--pulog"   ] || [ "$1" == "pulog"   ];   then USE_PULOG="true"
  elif [ "$1" == "-v" ] || [ "$1" == "--verbose" ]; then VERBOSE="true"
  elif [ "$1" == "--stty"      ]; then FORCE_STTY="true"
  elif [ "$1" == "--lower-rts" ]; then LOWER_RTS="true"
  elif [ "$1" == "--loop"      ]; then LOOP="true"
  elif [ "$1" == "--logfile" ]; then
    shift
    LOGFN="$1"
    if [ "$LOGFN" == "" ]; then
      echo "Missing logfilename" >&2
      exit 1
    fi
  elif [ "$1" == "--delay" ]; then
    shift
    STTY_DELAY="$1"
    if [ "STTY_DELAY" == "" ]; then
      echo "Missing delay value" >&2
      exit 1
    fi
  else
    echo "Unexpected parameter \"$1\"" >&2
    ShowHelp
    exit 1
    #PARAMS+=" $1"
  fi
  shift
done

# Picocom als default einstellen
[ "$USE_MINICOM" == "false" ] && [ "$USE_PICOCOM" == "false" ] && [ "$USE_PYTERM" == "false" ] && [ "$USE_PYLOG" == "false" ] && [ "$USE_PULOG" == "false" ] && USE_PICOCOM="true"

# Picomom Version ermitteln
if [ "$USE_PICOCOM" == "true" ]; then
    # Detect if we have a recent picocom 2.3a with logfile option (Joe's patches) or not
    # -> https://github.com/Joe-Merten/picocom
    # picocom 2.3 e.g. can handle more baudrates and have some aditional features
    # picocom 1.7 (Kubuntu 16.04) kann z.B. kein 1MBaud
    picocom --help | grep -q "lo<g>file" || OLD_PICOCOM="true"
    #echo "OLD_PICOCOM=$OLD_PICOCOM"
fi

if [ "$DEVICE" == "" ]; then
    echo "Device muss angegeben werden" >&2
    exit 1
fi


while true; do
    PARAMS=""

    if [ "$LOOP" == "true" ]; then
        # Waiting for the device appearing
        while ! test -e "${DEVICE}"; do
            echo -n "."
            sleep 1
        done
    fi

    # On my Kubuntu 14.04 32 Bit, both minicom and picocom have trouble with device names > 127 chars.
    # But sometimes we want to use something like
    #     /dev/serial/by-id/usb-Maxim_IntegratedCircuit_DesignPvt._Ltd._CDCACM_USB_To_RS-232_Emulation_Device_D9E539F2-4940-4DA1-AC49-5DFD667DD905-if00
    # As this typically is a symlink to e.g. /dev/ttyACM*, we solve the problem by following the symlink manually
    DEVICE_P="$DEVICE"
    [ "${#DEVICE}" -gt 128 ] && [ -L "${DEVICE}" ] && DEVICE_P="$(readlink -f "${DEVICE}")"

    if [ "$USE_MINICOM" == "true" ]; then
        # Temporäres Minicom Configfile erstellen zur Einstellung von HW-Flow
        if [ "$HWFLOW" == "false" ]; then
            echo "pu rtscts No" >"$CONFIGFN"
        else
            echo "pu rtscts Yes" >"$CONFIGFN"
        fi

        #Logfile ermitteln
        [ "$LOGFN" == "auto" ] && LOGFN="$HOME/Minicom-Capture-$(basename "$DEVICE").log"

        PARAMS+=" -mwz --color=on"
        PARAMS+=" -b $BAUD"
        PARAMS+=" -D $DEVICE_P"
        [ "$LOGFN"  != "none" ] && PARAMS+=" -C $LOGFN"
        [ "$CONFIG" != "" ] && PARAMS+=" $CONFIG"

        # Aufrufbeispiele
        # alias term-u0="LANG= minicom -mwz --color=on -b 115200 -D /dev/ttyUSB0 -C ~/MiniCom-Capture-U0.log"
        # echo "pu rtscts Yes" >"$HOME/.minirc.tmp-rtscts"; LANG= minicom -mwz --color=on -b 115200 -D /dev/ttyUSB0 -C ~/MiniCom-Capture-U0.log  tmp-rtscts

        if [ "$VERBOSE" == "true" ]; then
            echo "----- $CONFIGFN -----"
            cat "$CONFIGFN"
            echo "----- EOF -----"
            echo "LANG= minicom $PARAMS"
        else
            #LANG="utf-8" minicom $PARAMS -R utf-8
            LANG= minicom $PARAMS
        fi

        rm -f "$CONFIGFN"
    fi


    if [ "$USE_PICOCOM" == "true" ]; then
        if [ "$OLD_PICOCOM" == "false" ] && [ "$FORCE_STTY" == "false" ]; then
            # yep, ein neues Picocom; kein stty und kein script erforderlich ;-)
            PARAMS+=" $DEVICE_P"
            PARAMS+=" --baud $BAUD"
            PARAMS+=" --imap lfcrlf"
            [ "$HWFLOW" == "true" ] && PARAMS+=" --flow hard"
            [ "$LOGFN" == "auto" ] && LOGFN="$HOME/Picocom-Capture-$(basename "$DEVICE").log"
            [ "$LOGFN" != "none" ] && PARAMS+=" --logfile $LOGFN"
            [ "$LOWER_RTS" == "true" ] && PARAMS+=" --lower-rts"
            if [ "$VERBOSE" == "true" ]; then
                echo "picocom $PARAMS"
            else
                picocom $PARAMS
            fi
        else
            # altes Picocom kann leider kein 1 MBaud, deshalb stellen wir das selbst ein
            RTSCTS=""
            [ "$HWFLOW" == "true" ] && RTSCTS="crtscts"
            STTY_PARAMS="-F $DEVICE_P $BAUD cs8 -parenb -cstopb $RTSCTS sane raw -echo -echok -onlcr"

            PARAMS+=" $DEVICE_P"
            PARAMS+=" --noinit"
            # Übergabe der Baudrate an altes Picocom ist nur für die Anzeige; auf die Einstellung hat es (wg. --noinit) keine Auswirkung
            PARAMS+=" --baud $BAUD"
            PARAMS+=" --imap lfcrlf"

            # altes Picocom hat kein Logging, also verwenden wir Script
            [ "$LOGFN" == "auto" ] && LOGFN="$HOME/Picocom-Capture-$(basename "$DEVICE").log"
            SCRIPT_PARAMS="-a -f"

            if [ "$VERBOSE" == "true" ]; then
                echo "stty $STTY_PARAMS"
                [ "$STTY_DELAY" != "" ] && echo "sleep $STTY_DELAY"
                if [ "$LOGFN"  != "none" ]; then
                    echo "script $SCRIPT_PARAMS -c \"picocom $PARAMS\" \"$LOGFN\""
                else
                    echo "picocom $PARAMS"
                fi
            else
                if ! stty $STTY_PARAMS; then
                    echo "=== ERROR while configuring the uart ===" >/dev/stderr
                fi
                [ "$STTY_DELAY" != "" ] && sleep $STTY_DELAY
                if [ "$LOGFN"  != "none" ]; then
                    script $SCRIPT_PARAMS -c "picocom $PARAMS" "$LOGFN"
                else
                    picocom $PARAMS
                fi
            fi
        fi
    fi

    if [ "$USE_PYTERM" == "true" ]; then
        PARAMS+=" $DEVICE_P"
        PARAMS+=" $BAUD"
        # enable raw mode to e.g. retain ansi colors, but older versions of miniterm have not such option (e.g. kubuntu 14.04)
        python3 -m serial.tools.miniterm --help | grep -q "\-\-raw" && PARAMS+=" --raw"
        #PARAMS+=" --eol LF"        ; # is unfortunately only for TX (e.g. enter key), not for RX data
        #PARAMS+=" --quiet"
        PARAMS+=" --menu-char 1"   ; # menu with Ctrl+A
        PARAMS+=" --exit-char 24"  ; # exit with Ctrl+X
        [ "$HWFLOW" == "true" ] && PARAMS+=" --rtscts"
        [ "$LOGFN" == "auto" ] && LOGFN="$HOME/Pythoncom-Capture-$(basename "$DEVICE").log"
        #[ "$LOGFN" != "none" ] && PARAMS+=" --logfile $LOGFN"
        [ "$LOWER_RTS" == "true" ] && PARAMS+=" --rts 0"

        SCRIPT_PARAMS="-a -f"

        if [ "$VERBOSE" == "true" ]; then
            if [ "$LOGFN"  != "none" ]; then
                echo "script $SCRIPT_PARAMS -c \"python3 -m serial.tools.miniterm $PARAMS\" \"$LOGFN\""
            else
                echo "python3 -m serial.tools.miniterm $PARAMS"
            fi
        else
            if [ "$LOGFN"  != "none" ]; then
                script $SCRIPT_PARAMS -c "python3 -m serial.tools.miniterm $PARAMS" "$LOGFN"
                # python miniterm unfortunately translates received LF to CRLF, so we want to remove those CR from the logfile
                TMPFILE="$LOGFN.tmp"
                if tr -d '\015'  < "$LOGFN" > "$TMPFILE"; then
                    mv "$TMPFILE" "$LOGFN"
                else
                    echo "=== Error while removing CR from $LOGFN ===" >/dev/stderr
                fi
            else
                python3 -m serial.tools.miniterm $PARAMS
            fi
        fi
    fi

    if [ "$USE_PULOG" == "true" ]; then
        PARAMS+=" $DEVICE_P"
        PARAMS+=" $BAUD"
        [ "$HWFLOW" == "true" ] && PARAMS+=" --rtscts"
        [ "$LOGFN" == "auto" ] && LOGFN="$HOME/Pulog-Capture-$(basename "$DEVICE").log"
        [ "$LOGFN" != "none" ] && PARAMS+=" --logfile $LOGFN"
        [ "$LOWER_RTS" == "true" ] && PARAMS+=" --lower-rts"
        if [ "$VERBOSE" == "true" ]; then
            echo "Pulog.py $PARAMS"
        else
            Pulog.py $PARAMS
        fi
    fi

    if [ "$USE_PYLOG" == "true" ]; then
        # TODO: HWFLOW
        declare LF=$'\n'
        declare CMD=""
        CMD+="import serial""$LF"
        CMD+="import datetime""$LF"
        CMD+="ser = serial.Serial(port = '$DEVICE_P', baudrate = $BAUD)""$LF"
        [ "$LOWER_RTS" == "true" ] && CMD+="ser.setRTS(False)""$LF"
        [ "$LOGFN" == "auto" ] && LOGFN="$HOME/Pylog-Capture-$(basename "$DEVICE").log"
        CMD+="timestamp = 'Started logging at ' + datetime.datetime.now().isoformat(' ')""$LF"
        # 'ab' = append & binary; for open modes see https://docs.python.org/3/library/functions.html#open
        [ "$LOGFN" != "none" ] && CMD+="logfile = open('$LOGFN', 'ab')""$LF"
        [ "$LOGFN" != "none" ] && CMD+="logfile.write(bytes(timestamp + '\n', 'utf-8')); logfile.flush()""$LF"
        CMD+="console = open('/dev/stdout', 'wb')""$LF"
        CMD+="console.write(bytes(timestamp + '\n', 'utf-8')); console.flush()""$LF"
        CMD+="while True:""$LF"
        CMD+="    data = ser.read()""$LF"
        CMD+="    console.write(data)""$LF"
        CMD+="    console.flush()""$LF"
        [ "$LOGFN" != "none" ] && CMD+="    logfile.write(data)""$LF"
        [ "$LOGFN" != "none" ] && CMD+="    logfile.flush()""$LF"
        CMD+="timestamp = 'Finished logging at ' + datetime.datetime.now().isoformat(' ')""$LF"
        [ "$LOGFN" != "none" ] && CMD+="logfile.write(bytes(timestamp + '\n', 'utf-8')); logfile.flush()""$LF"
        CMD+="console.write(bytes(timestamp + '\n', 'utf-8')); console.flush()""$LF"
        CMD+="ser.close()""$LF"
        CMD+="console.close()""$LF"
        [ "$LOGFN" != "none" ] && CMD+="logfile.close()""$LF"

        if [ "$VERBOSE" == "true" ]; then
            echo "python3 -c \"$CMD\""
        else
            python3 -c "$CMD"
        fi
    fi

# just for python serial experiments
#     if [ "$USE_PYLOG" == "truee" ]; then
#         python3 -c "
# import time
# import serial
# ser = serial.Serial(port = '/dev/ttyUSB0', baudrate = 921600)
# ser.setRTS(False)
# # 'ab' = append & binary; for open modes see https://docs.python.org/3/library/functions.html#open
# logfile = open('logfile.log', 'ab')
# console = open('/dev/stdout', 'wb')
# while True:
#     data = ser.read()
#     console.write(data)
#     logfile.write(data)
# "
#     fi

    if [ "$LOOP" == "true" ]; then
        # sleep a moment before restart terminal app
        # this gives the user time to e.g hit ctrl+c to leave our script
        sleep 2
    else
        break;
    fi
done
