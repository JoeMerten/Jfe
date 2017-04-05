#/bin/bash
########################################################################################################################
# Jlink Starterscript
#-----------------------------------------------------------------------------------------------------------------------
# \project    Jfe
# \file       Jlink.sh
# \creation   2016-02-21, Joe Merten
#-----------------------------------------------------------------------------------------------------------------------
# Currently tested with linux only
########################################################################################################################

########################################################################################################################
# Konstanten & Globale Variablen
########################################################################################################################

#JLINK_SN_EDU_1
#JLINK_SN_PLUS_1
JLINK_SN_ULTRA_1=504301306
JLINK_SN_PRO_1=174301514
JLINK_SN_PRO_2=174301515

JLINK_SN=""
#JLINK_SN="$JLINK_SN_ULTRA_1"
#JLINK_SN="$JLINK_SN_PRO_1"

DEVICE=""
IF=""
SPEED=""
# 36HMz has been recommended by segger for e.g. Stm42F4 and Max32550
SPEED="36000"
PORT=""
#PORT="2331"

# -singlerun scheint nicht so recht mit Eclipse zusammen zu funktionieren

########################################################################################################################
# Auswertung der Kommandozeilenparameter
########################################################################################################################
while (("$#")); do
    if [ "$1" == "?" ] || [ "$1" == "-?" ] || [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ]; then
        ShowHelp
        exit 0
    elif [ "$1" == "nocolor" ]; then
        NoColor
    elif [ "$1" == "edu" ] || [ "$1" == "edu1" ]; then
        JLINK_SN="$JLINK_SN_EDU_1"
    elif [ "$1" == "plus" ] || [ "$1" == "plus1" ]; then
        JLINK_SN="$JLINK_SN_PLUS_1"
    elif [ "$1" == "ultra" ] || [ "$1" == "ultra1" ]; then
        JLINK_SN="$JLINK_SN_ULTRA_1"
    elif [ "$1" == "pro" ] || [ "$1" == "pro1" ]; then
        JLINK_SN="$JLINK_SN_PRO_1"
    elif [ "$1" == "pro2" ]; then
        JLINK_SN="$JLINK_SN_PRO_2"
    elif [ "$1" == "lh" ] || [ "$1" == "max32550" ]; then
        DEVICE="max32550"
        [ "$IF"    == "" ] && IF="JTAG"
        [ "$SPEED" == "" ] && SPEED="12000"
        [ "$PORT"  == "" ] && PORT="2330"
    elif [ "$1" == "stm32f401" ]; then
        # Stm Discoveryboard mit Stm32F401 VCT6U
        DEVICE="stm32f401vc"
        [ "$IF"    == "" ] && IF="SWD"
        #[ "$SPEED" == "" ] && SPEED="12000"
        #[ "$PORT"  == "" ] && PORT="2330"
    elif [ "$1" == "stm32f411" ]; then
        # Stm Discoveryboard mit Stm32F411 VET6U
        DEVICE="stm32f411ve"
        [ "$IF"    == "" ] && IF="SWD"
        #[ "$SPEED" == "" ] && SPEED="12000"
        #[ "$PORT"  == "" ] && PORT="2330"
    elif [ "$1" == "lpc433xM4" ]; then
        DEVICE="LPC4330_M4"
        [ "$IF"    == "" ] && IF="JTAG"
        [ "$SPEED" == "" ] && SPEED="12000"
        #[ "$PORT"  == "" ] && PORT="2330"
    else
        echo "Unexpected parameter \"$1\"" >&2
        #ShowHelp
        exit 1
    fi
    shift
done

########################################################################################################################
# Main...
########################################################################################################################

# Jlink Installationsverzeichnis bestimmen
JLINK_INSTALL_DIR="$(readlink "$(which JLinkGDBServer)")"
[ "$JLINK_INSTALL_DIR" != "" ] && JLINK_INSTALL_DIR="$(dirname "$JLINK_INSTALL_DIR")"
# Determine Segger rtos plugin directory, supported from about version 5.42
JLINK_PLUGIN_DIR=""
[ "$JLINK_INSTALL_DIR" != "" ] && test -d "$JLINK_INSTALL_DIR/GDBServer" && JLINK_PLUGIN_DIR="$JLINK_INSTALL_DIR/GDBServer"

JLINK_PARAMS=()
[ "$JLINK_SN" != "" ] && JLINK_PARAMS+=("-select" "USB=$JLINK_SN")
[ "$DEVICE"   != "" ] && JLINK_PARAMS+=("-device" "$DEVICE")
[ "$IF"       != "" ] && JLINK_PARAMS+=("-if"     "$IF")
[ "$SPEED"    != "" ] && JLINK_PARAMS+=("-speed"  "$SPEED")
[ "$PORT"     != "" ] && JLINK_PARAMS+=("-port"   "$PORT")
JLINK_PARAMS+=("-noir")
# "$JLINK_PLUGIN_DIR" != "" ] && JLINK_PARAMS+=("-rtos" "$JLINK_PLUGIN_DIR/RTOSPlugin_FreeRTOS.so")
# Some older versions of JlinkGdbserver need to have workingdir = installdir to make -rtos option work
#[ "$JLINK_PLUGIN_DIR" != "" ] && cd "$JLINK_INSTALL_DIR" && JLINK_PARAMS+=("-rtos" "GDBServer/RTOSPlugin_FreeRTOS.so")

while true; do
    clear
    echo "JLinkGDBServer ${JLINK_PARAMS[@]}"
    echo ""
    JLinkGDBServer "${JLINK_PARAMS[@]}"
    #JLinkGDBServer -select USB=$JLINK_SN -device max32550 -if JTAG -speed 12000 -noir -port 2330
    echo ""
    sleep 1
done
