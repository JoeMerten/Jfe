#!/bin/bash -e
########################################################################################################################
# Script to download & install gcc-arm-embedded to linux, osx or cygwin hosts
#-----------------------------------------------------------------------------------------------------------------------
# \project    Jfe
# \file       InstallGccArm.sh
# \creation   2010-06-14, Joe Merten
########################################################################################################################


# GCC_ARM_VERSION ist z.B.                                       "4.7-2012-q4"
# URL_DIR                                                ".../4.7/4.7-2012-q4-major/+download"
# URL_BASE ".../4.7/4.7-2012-q4-major/+download/gcc-arm-none-eabi-4_7-2012q4-20121208"
# ARCHIVE_BASENAME                             "gcc-arm-none-eabi-4_7-2012q4-20121208"
# ARCHIVE_DIRNAME                              "gcc-arm-none-eabi-4_7-2012q4"
# INSTALL_BASENAME                             "gcc-arm-none-eabi-4_7-2012q4"
# INSTALL_DIR                             "/opt/gcc-arm-none-eabi-4_7-2012q4"

# GCC_ARM_VERSION ist z.B. "4.7-2014-q2"
declare GCC_ARM_VERSION=""
declare INCLUDE_SRC="true"
declare USE_CURL="false"
declare RETAIN_TMP="false"
declare BUILD_FROM_SOURCE="false"
declare BUILD_PPA="false"
declare BUILD_WIN="false"
declare BUILD_NANOX="false"

declare ESC=$'\e'
declare COLOR_RED_BOLD="${ESC}[0;91;1m"
declare COLOR_YELLOW_BOLD="${ESC}[0;33;1m"
declare COLOR_RESET="${ESC}[m"

set -e

########################################################################################################################
# Error handling hook
#-----------------------------------------------------------------------------------------------------------------------
# Da wir das Skript mit "bash -e" ausführen, führt jeder Befehls- oder Funktionsaufruf, der mit !=0 returniert zu einem
# Skriptabbruch, sofern der entsprechende Exitcode nicht Skriptseitig ausgewertet wird.
# Siehe auch http://wiki.bash-hackers.org/commands/builtin/set -e
# Mit dem OnError() stellen wir hier noch mal einen Fuss in die Tür um genau diesen Umstand (unerwartete Skriptbeendigung)
# sichtbar zu machen.
########################################################################################################################
function OnError() {
    echo "${COLOR_RED_BOLD}Script error exception in line $1, exit code $2${COLOR_RESET}" >&2
    trap SIGINT
    # but ... dont do `kill -INT 0` on OSX because it kills also the calling eclipse!
    [ "$HOST_SYSTEM" != "Darwin" ] && kill -INT 0
    exit 2
}
trap 'OnError $LINENO $?' ERR
# siehe auch http://stackoverflow.com/questions/64786/error-handling-in-bash
# Ohne "errtrace" wird mein OnError() nicht immer gerufen...
set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value


########################################################################################################################
# Error handling
########################################################################################################################
function Error {
    echo "${COLOR_RED_BOLD}Error: $*${COLOR_RESET}" 1>&2
    # when just doing exit 1, the eclipse builder will print "make: [pre-build] Error 1 (ignored)" and continued the build
    # but if we do that "kill -INT 0", then the build will be really forced to fail
    # but ... dont do `kill -INT 0` on OSX because it kills also the calling eclipse!
    [ "$HOST_SYSTEM" != "Darwin" ] && kill -INT 0
    exit 1
}


function Warning {
    echo "${COLOR_YELLOW_BOLD}Warning: $*${COLOR_RESET}" 1>&2
}


########################################################################################################################
# Exit-Hook
#-----------------------------------------------------------------------------------------------------------------------
# OnExit() wird bei jeder Art der Skriptbeendigung aufgerufen, ggf. nach OnError()
# Siehe auch http://wiki.bash-hackers.org/commands/builtin/trap
#
# TODO: Näher untersuchen und für mich anpassen
#   tempfiles=( )
#   cleanup() {
#       rm -f "${tempfiles[@]}"
#   }
#   trap cleanup EXIT
########################################################################################################################
declare tempfiles=()
declare tempdirs=()
function OnExit() {
    if [ "${#tempfiles[@]}" != "0" ] || [ "${#tempdirs[@]}" != "0" ]; then
        if [ "$RETAIN_TMP" == "false" ]; then
            echo "Cleaning up ..."
            [ "${#tempfiles[@]}" != "0" ] && rm -f "${tempfiles[@]}"
            [ "${#tempdirs[@]}" != "0" ] && rm -rf "${tempdirs[@]}"
        else
            echo "No cleanup, temporary files and directories will be retained"
        fi
    fi
}
trap 'OnExit $LINENO $?' EXIT


########################################################################################################################
# Host system detection
#-----------------------------------------------------------------------------------------------------------------------
# set variables
# - HOST_SYSTEM              e.g. "Linux" / "Darwin" / "Cygwin"
# - HOST_UBUNTU_VERSION      e.g. "14.04" / "16.04"  / ...
# - HOST_UBUNTU_VERSION_EXT  e.g. "14.04-32" / "16.04-64"  / ...
########################################################################################################################
function detectHost() {
    local UNAME_S=$(uname -s)
    if [ "$UNAME_S" == "Linux" ]; then
        HOST_SYSTEM="Linux"
    elif [ "$UNAME_S" == "Darwin" ]; then
        HOST_SYSTEM="Darwin"
    elif [[ "$UNAME_S" =~ ^CYGWIN_NT-.*$ ]]; then
        # might be "CYGWIN_NT-5.1" or "CYGWIN_NT-6.3" ...
        HOST_SYSTEM="Cygwin"
    else
        Error "Unknown host system '$UNAME_S'"
    fi

    HOST_UBUNTU_VERSION=""
    HOST_UBUNTU_VERSION_EXT=""
    if [ "$HOST_SYSTEM" == "Linux" ]; then
        HOST_UBUNTU_VERSION="$(lsb_release -rs)"
        UNAME_M=$(uname -m)
        if [ "$UNAME_M" == "i686" ]; then
            HOST_UBUNTU_VERSION_EXT="$HOST_UBUNTU_VERSION-32"
        elif [ "$UNAME_M" == "x86_64" ]; then
            HOST_UBUNTU_VERSION_EXT="$HOST_UBUNTU_VERSION-64"
        else
            Error "Unable to obtain architecture for '$UNAME_M'"
        fi
        echo "HOST_UBUNTU_VERSION     = $HOST_UBUNTU_VERSION"
        echo "HOST_UBUNTU_VERSION_EXT = $HOST_UBUNTU_VERSION_EXT"
    fi
}


########################################################################################################################
# Helper function to obtaint if a array contains a specific element
# \in  val  element to search for
# \in  arr  array to search on
########################################################################################################################
function isInArray() {
    local val=("$1")
    declare -a arr=("${!2}")
    local e
    for e in "${arr[@]}"; do
        [ "$e" == "$val" ] && return 0
    done
    return 1
}


########################################################################################################################
# Help
########################################################################################################################
function ShowHelp {
    echo "Usage: $0 <toolchain-version> [options]"
    echo "Options:"
    echo "        --retainTmp        Don't cleanup temp directory (downloads, builds, ...)"
    echo "    -b  --buildFromSrouce  Build toolchain from source (instead of use prebuild binaries)"
    echo "        --ppa              Prepare ppa build (only affects with -b) (untested)"
    echo "        --win              Include mingw cross build (only affects with -b) (untested)"
    echo "        --nanox            Build newlib nano with exceptions support (only affects with -b) (untested)"
    echo "Currently supported versions for installation are:"
    egrep -o "^        [0-9]\.[0-9]-201[0-9]-q[0-9]" "$0"
    echo "or just \"latest\" to install the most recent version"
}


########################################################################################################################
# Check prerequisites for toolchain package download and installation
########################################################################################################################
function checkPrerequisites() {
    if which curl >/dev/null; then
        # yep, curl available
        USE_CURL="true"
    elif which wget >/dev/null; then
        # ok, we could also use wget
        # but note, that wget raises curios ssl errors when trying on a 64 bit cygwin installation (2015-07-07)
        USE_CURL="false"
    else
        Error "Need either wget or curl"
    fi

    if [ "$HOST_SYSTEM" == "Cygwin" ]; then
        # "which unzip" reicht nicht aus, da hier bei cygwin Installationen u.U. ein unzip aus der Windows-Welt gefunden wird
        # welches nichts mit "/tmp/bla" anfangen kann. Deshalb bestehen wir auf "/usr/bin/unzip"
        if ! which /usr/bin/unzip >/dev/null; then
            Error "Need unzip on cygwin host"
        fi
    fi
}

########################################################################################################################
# Set various variables need for download, toolchain build and installation
#-----------------------------------------------------------------------------------------------------------------------
# erwartet gesetzt:
#     GCC_ARM_VERSION
# setzt die Variablen:
#     URL_BASE
#     URL_DIR
#     ARCHIVE_BASENAME
#     ARCHIVE_DIRNAME
#     DOWNLOAD_PARENT_DIR  /tmp
#     DOWNLOAD_DIR
#     INSTALL_BASENAME
#     INSTALL_PARENT_DIR   /opt
#     INSTALL_DIR
#     REBUILD_REQUIRED_UBUNTU_PACKAGES
#     REBUILD_TESTED_UBUNTU_VERSIONS
########################################################################################################################
function setVersionVars() {
    INSTALL_BASENAME=""
    REBUILD_REQUIRED_UBUNTU_PACKAGES=()
    REBUILD_TESTED_UBUNTU_VERSIONS=()
    case "$GCC_ARM_VERSION" in
        4.7-2012-q4) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.7/4.7-2012-q4-major/+download/gcc-arm-none-eabi-4_7-2012q4-20121208"  ;;  # hat kein release.txt ud kein win32.zip
        4.7-2013-q1) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.7/4.7-2013-q1-update/+download/gcc-arm-none-eabi-4_7-2013q1-20130313" ;;
        4.7-2013-q2) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.7/4.7-2013-q2-update/+download/gcc-arm-none-eabi-4_7-2013q2-20130614" ;;
        4.7-2013-q3) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.7/4.7-2013-q3-update/+download/gcc-arm-none-eabi-4_7-2013q3-20130916" ;;
        4.7-2014-q2) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.7/4.7-2014-q2-update/+download/gcc-arm-none-eabi-4_7-2014q2-20140408" ;;

        4.8-2013-q4) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/gcc-arm-none-eabi-4_8-2013q4-20131204"
                 URL_BASE_OSX="https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/gcc-arm-none-eabi-4_8-2013q4-20131218"  ;;  # OSX hat hier einen leicht abweichenden Namen ...
        4.8-2014-q1) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.8/4.8-2014-q1-update/+download/gcc-arm-none-eabi-4_8-2014q1-20140314" ;;
        4.8-2014-q2) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.8/4.8-2014-q2-update/+download/gcc-arm-none-eabi-4_8-2014q2-20140609" ;;
        4.8-2014-q3) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.8/4.8-2014-q3-update/+download/gcc-arm-none-eabi-4_8-2014q3-20140805" ;;

        4.9-2014-q4) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.9/4.9-2014-q4-major/+download/gcc-arm-none-eabi-4_9-2014q4-20141203"  ;;
        4.9-2015-q1) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.9/4.9-2015-q1-update/+download/gcc-arm-none-eabi-4_9-2015q1-20150306" ;;
        4.9-2015-q2) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.9/4.9-2015-q2-update/+download/gcc-arm-none-eabi-4_9-2015q2-20150609" ;; # ok
        4.9-2015-q3) URL_BASE="https://launchpad.net/gcc-arm-embedded/4.9/4.9-2015-q3-update/+download/gcc-arm-none-eabi-4_9-2015q3-20150921"
                     # see also How-to-build-toolchain.pdf: "sudo apt-get install apt-src …" which refers to an example build session on Ubuntu 8.10 32 bit
                     REBUILD_REQUIRED_UBUNTU_PACKAGES_MINGW=(mingw32-runtime)
                     REBUILD_REQUIRED_UBUNTU_PACKAGES=(apt-src scons p7zip-full gawk gzip perl autoconf m4 automake libtool libncurses5-dev gettext gperf dejagnu expect tcl autogen guile-1.6 flex flip bison tofrodos texinfo g++ gcc-multilib libgmp3-dev libmpfr-dev debhelper)
                     # How-to-build-toolchain.pdf wrote, that texlive and texlive-extra-utils were unnecessary, so we don't install them.
                     #REBUILD_REQUIRED_UBUNTU_PACKAGES+=(texlive texlive-extra-utils)
                     REBUILD_TESTED_UBUNTU_VERSIONS=(8.10-32)
                     # TODO: there is no "guile-1.6" on Kubuntu 14.04 / 16.04 but "guile-1.8"
                     # auf 14.04 wird auch "texinfo" benötigt (für command "makeinfo"), baut aber dennoch nicht (auch nicht auf 12.04)
                     # auf 16.04 hab ich das auch noch nicht gebaut bekommen
                     ;;

        5.2-2015-q4) URL_BASE="https://launchpad.net/gcc-arm-embedded/5.0/5-2015-q4-major/+download/gcc-arm-none-eabi-5_2-2015q4-20151219"  ;;
        5.3-2016-q1) URL_BASE="https://launchpad.net/gcc-arm-embedded/5.0/5-2016-q1-update/+download/gcc-arm-none-eabi-5_3-2016q1-20160330" ;;
        5.4-2016-q2) URL_BASE="https://launchpad.net/gcc-arm-embedded/5.0/5-2016-q2-update/+download/gcc-arm-none-eabi-5_4-2016q2-20160622" ;;
        5.4-2016-q3) URL_BASE="https://launchpad.net/gcc-arm-embedded/5.0/5-2016-q3-update/+download/gcc-arm-none-eabi-5_4-2016q3-20160926" ;;

        # Toolchains from https://developer.arm.com/open-source/gnu-toolchain/gnu-rm/downloads
        # Web link:       https://developer.arm.com/open-source/gnu-toolchain/gnu-rm
       #5.4-2016-q3) URL_BASE="https://developer.arm.com/-/media/Files/downloads/gnu-rm/5_4-2016q3/gcc-arm-none-eabi-5_4-2016q3-20160926" ;;
        6.2-2016-q4) URL_BASE="https://developer.arm.com/-/media/Files/downloads/gnu-rm/6-2016q4/gcc-arm-none-eabi-6_2-2016q4-20161216" ;;

        # developer.arm.com again changed the naming conventions
        # Note that gcc --version: arm-none-eabi-gcc (GNU Tools for ARM Embedded Processors 6-2017-q1-update) 6.3.1 20170215 (release) [ARM/embedded-6-branch revision 245512]
        # even if the url contains a "6_1". Thats the reason, why we now set INSTALL_BASENAME manually from here
        6.3-2017-q1) URL_BASE="https://developer.arm.com/-/media/Files/downloads/gnu-rm/6_1-2017q1/gcc-arm-none-eabi-6-2017-q1-update"
                     INSTALL_BASENAME="gcc-arm-none-eabi-6_3-2017q1"
                     # see also How-to-build-toolchain.pdf: "sudo apt-get install apt-src …" which refers to an example build session on Ubuntu 14.04.5 64 Bit
                     # I'd also successfully rebuild the toolchain on Kubuntu 16.04.2 64 Bit
                     # sudo apt-get install -y -t xenial gcc-mingw-w64-i686 g++-mingw-w64-i686 binutils-mingw-w64-i686
                     # sudo apt-get -f install -y build-essential …
                     REBUILD_REQUIRED_UBUNTU_PACKAGES_MINGW=(gcc-mingw-w64-i686 g++-mingw-w64-i686 binutils-mingw-w64-i686)
                     REBUILD_REQUIRED_UBUNTU_PACKAGES=(build-essential autoconf autogen bison dejagnu flex flip gawk git gperf gzip nsis openssh-client p7zip-full perl python-dev libisl-dev scons tcl texinfo tofrodos wget zip)
                    # configure: error: Building GCC requires GMP 4.2+, MPFR 2.4.0+ and MPC 0.8.0+.
                    # libgmpv4-dev?
                     # TODO: Check if texlive is really required
                     #REBUILD_REQUIRED_UBUNTU_PACKAGES=(texlive texlive-extra-utils)
                     REBUILD_TESTED_UBUNTU_VERSIONS=(14.04-64 16.04-64)
                     ;;

        *) Error "Sorry, version \"$GCC_ARM_VERSION\" is currently not supported"
        ;;
    esac

    # Even set ARCHIVE_DIRNAME to the (guessed) directory name which is contained in the archive
    # For Linux and OSX, the archive itself contains a directory.
    # The name of the directory is potential (slightly) unknown for us and the conventions differ over the releases.
    # E.g. in
    # - in  4.9-2015-q3: gcc-arm-none-eabi-4_9-2015q3-20150921-linux.tar.bz2 -> gcc-arm-none-eabi-4_9-2015q3
    # - but 6.3-2017-q1: gcc-arm-none-eabi-6-2017-q1-update-linux.tar.bz2 -   > gcc-arm-none-eabi-6-2017-q1-update
    # (But even further a bit different in the src archives, which e.g. contains the date in the 4.9 release ...)
    URL_DIR="$(dirname "$URL_BASE")"
    ARCHIVE_BASENAME="$(basename "$URL_BASE")"
    if [ "$INSTALL_BASENAME" != "" ]; then
        # From beginning with gcc 6.3, ARCHIVE_BASENAME became something like: "gcc-arm-none-eabi-6-2017-q1-update"
        # So, I'd decided to set INSTALL_BASENAME manually (see switch above)
        ARCHIVE_DIRNAME="$ARCHIVE_BASENAME"
        echo -n
    elif [ "${ARCHIVE_BASENAME:28:3}" == "-20" ]; then
        # as long as the url was something like "gcc-arm-none-eabi-6_2-2016q4-20161216"
        # but note that inside of the archive, we find a directory named "gcc-arm-none-eabi-6_2-2016q4"
        # we just strip away that "-20161216" to got "gcc-arm-none-eabi-6_2-2016q4"
        ARCHIVE_DIRNAME="${ARCHIVE_BASENAME:0:28}"
        INSTALL_BASENAME="$ARCHIVE_DIRNAME"
    else
        Error "Errornous name \"$ARCHIVE_BASENAME\""
    fi

    DOWNLOAD_PARENT_DIR="/tmp"
    DOWNLOAD_DIR="$DOWNLOAD_PARENT_DIR/$ARCHIVE_BASENAME"
    INSTALL_PARENT_DIR="/opt"
    INSTALL_DIR="$INSTALL_PARENT_DIR/$INSTALL_BASENAME"

    # Verbose
    if true; then
        echo "GCC_ARM_VERSION  = $GCC_ARM_VERSION"
        echo "URL_DIR          = $URL_DIR"
        echo "URL_BASE         = $URL_BASE"
        echo "ARCHIVE_BASENAME = $ARCHIVE_BASENAME"
        echo "ARCHIVE_DIRNAME  = $ARCHIVE_DIRNAME"
        echo "DOWNLOAD_DIR     = $DOWNLOAD_DIR"
        echo "INSTALL_BASENAME = $INSTALL_BASENAME"
        echo "INSTALL_DIR      = $INSTALL_DIR"
    fi

    [ -e "$DOWNLOAD_DIR" ] && Warning "Download directory $DOWNLOAD_DIR already exist"
    [ -e "$INSTALL_DIR" ] && Warning "Installation directory $INSTALL_DIR already exist"
    return 0
}


########################################################################################################################
# Download packages from web
#-----------------------------------------------------------------------------------------------------------------------
# Need to have setVersionVars() called before
########################################################################################################################
function download() {
    [ -e "$DOWNLOAD_DIR" ] && Error "Download directory $DOWNLOAD_DIR already exist"

    tempdirs+=("$DOWNLOAD_DIR")
    mkdir -p "$DOWNLOAD_DIR"
    pushd "$DOWNLOAD_DIR" >/dev/null

    # https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/gcc-arm-none-eabi-4_8-2013q4-20131204-src.tar.bz2
    # https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/gcc-arm-none-eabi-4_8-2013q4-20131204-linux.tar.bz2
    # https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/gcc-arm-none-eabi-4_8-2013q4-20131218-mac.tar.bz2
    # https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/gcc-arm-none-eabi-4_8-2013q4-20131204-win32.zip
    # https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/gcc-arm-none-eabi-4_8-2013q4-20131204-win32.exe
    # https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/readme.txt
    # https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/release.txt
    # https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/How-to-build-toolchain.pdf
    # https://launchpad.net/gcc-arm-embedded/4.8/4.8-2013-q4-major/+download/license.txt

    local download="wget"
    # curl -L to follow http redirection e.g. from "launchpad.net" to "launchpadlibrarian.net"
    [ "$USE_CURL" == "true" ] && download="curl -LO"

    [ "$INCLUDE_SRC" == "true"   ] && $download "${URL_BASE}-src.tar.bz2"
    if [ "$BUILD_FROM_SOURCE" == "false" ]; then
        [ "$HOST_SYSTEM" == "Linux"  ] && $download "${URL_BASE}-linux.tar.bz2"
        [ "$HOST_SYSTEM" == "Darwin" ] && $download "${URL_BASE}-mac.tar.bz2"
        [ "$HOST_SYSTEM" == "Cygwin" ] && $download "${URL_BASE}-win32.zip"
    fi

    # further files, that we might need later
    #$download ${URL_BASE}-win32.exe
    #$download ${URL_DIR}/readme.txt
    #$download ${URL_DIR}/release.txt
    #$download ${URL_DIR}/license.txt
    #$download ${URL_DIR}/How-to-build-toolchain.pdf

    popd >/dev/null
}


########################################################################################################################
# Check for prerequisites required for toolchain rebuild
#-----------------------------------------------------------------------------------------------------------------------
# See also How-to-build-toolchain.pdf e.g. from inside the source packages.
# - 4.9-2015-q3:
#   Note that How-to-build-toolchain.pdf writes a "apt-src" for apt-get:
#   sudo apt-get install apt-src …
# - 6.3-2017-q1:
#   Note that How-to-build-toolchain.pdf writes a "-t xenial" for mingw:
#   sudo apt-get install -y -t xenial gcc-mingw-w64-i686 g++-mingw-w64-i686 binutils-mingw-w64-i686
# Both above noted things are currently not handled here.
########################################################################################################################
function checkUbuntuPackages() {
    if [ "${#REBUILD_TESTED_UBUNTU_VERSIONS[@]}" == "0" ]; then
        Warning "Build from source for $GCC_ARM_VERSION is currently not tested for Ubuntu $HOST_UBUNTU_VERSION_EXT host"
    elif ! isInArray "$HOST_UBUNTU_VERSION_EXT" REBUILD_TESTED_UBUNTU_VERSIONS[@]; then
        Warning "Build from source for $GCC_ARM_VERSION is currently not tested for Ubuntu $HOST_UBUNTU_VERSION_EXT host but only for: ${REBUILD_TESTED_UBUNTU_VERSIONS[*]}"
    fi
    if [ "${#REBUILD_REQUIRED_UBUNTU_PACKAGES[@]}" == "0" ]; then
        Warning "No required ubuntu packages defined for building $GCC_ARM_VERSION"
        return 0
    fi

    #REBUILD_REQUIRED_UBUNTU_PACKAGES+=(asdf)              ; # just for this script function testing
    #REBUILD_REQUIRED_UBUNTU_PACKAGES+=(kimwitu kimwitu++) ; # just for this script function testing
    #local allAvailable=($(apt-cache pkgnames))
    local notInstalled=()
    local available=()
    local notAvailable=()
    for pkg in "${REBUILD_REQUIRED_UBUNTU_PACKAGES[@]}"; do
        # looking for already installed packages
        # if dpkg -l "$pkg" >/dev/null 2>&1; then hmm, wont work reliable
        # apt-cache policy outputs a couple of lines including e.g.
        #    "  Installed: (none)"
        # or "N: Unable to locate package …"
        local status="$(LANG= apt-cache policy "$pkg" | egrep "^  Installed: " || echo "UNAVAILABLE")"
        # Note that e.g. apt-cache policy guile-1.6 returns "  Installed: (none)" but also "  Candidate: (none)"
        [ "$status" == "  Installed: (none)" ] && LANG= apt-cache policy "$pkg" | egrep "^  Candidate: \(none\)$" && status="UNAVAILABLE"
        #echo "status($pkg)=\"$status\""
        if [ "$status" == "UNAVAILABLE" ]; then
            notInstalled+=($pkg)
            notAvailable+=($pkg)
        elif [ "$status" == "  Installed: (none)" ]; then
            # package not installed
            notInstalled+=($pkg)
            available+=($pkg)
        else
            # package seems to be installed, nothing to do
            echo -n
        fi

        # --- old discarded code ---
        #if true; then
        #    # package seems to be installed, nothing to do
        #    echo -n
        #else
        #    # package not installed
        #    notInstalled+=($pkg)
        #    # Note, that "apt-cache search --names-only" won't work with package "g++" (but works for e.g. " kimwitu++"?!)
        #    # local search=$(apt-cache search --names-only '^'"$pkg"'$')
        #   local search=""; for avpkg in "${allAvailable[@]}"; do if [ "$pkg" == "$avpkg" ]; then search="true"; break; fi; done
        #    if [ "$search" != "" ]; then
        #        available+=($pkg)
        #    else
        #        notAvailable+=($pkg)
        #    fi
        #fi
    done

    if [ "${#notInstalled[@]}" == "0" ]; then
        echo "All package prerequisites were fulfilled"
        return 0
    fi

    local singularPlural="s"
    [ "${#notInstalled[@]}" == "1" ] && singularPlural=""
    echo "${#notInstalled[@]} required package$singularPlural actually not installed:"
    for pkg in "${notInstalled[@]}"; do
        echo "  $pkg"
    done

    if [ "${#notAvailable[@]}" != "0" ]; then
        [ "${#notAvailable[@]}" == "1" ] && singularPlural=""
        Warning "${#notAvailable[@]} required package$singularPlural not available for install. You might retry with after sudo apt-get update."
        for pkg in "${notAvailable[@]}"; do
            echo "  $pkg"
        done
        echo "Press enter to try without em or ctrl+c for cancel."
        read
    fi

    if [ "${#available[@]}" != "0" ]; then
        [ "${#available[@]}" == "1" ] && singularPlural=""
        echo "${#available[@]} required package$singularPlural available for install:"
        for pkg in "${available[@]}"; do
            echo "  $pkg"
        done
        echo "Need mr. sudo to install em."
        sudo apt-get install -y "${available[@]}"
    fi

    #echo "Need to install:"
    #echo "${notInstalled[@]}"
    #echo "Available:"
    #echo "${available[@]}"
    #echo "Not available:"
    #echo "${notAvailable[@]}"
}


########################################################################################################################
# Check for prerequisites required for toolchain rebuild
########################################################################################################################
function checkBuildPrerequisites() {
    local ubuntuVersion="$(lsb_release -rs)"
    echo "Detected Ubuntu version is $ubuntuVersion"

    [ "$HOST_SYSTEM" == "Linux" ] && checkUbuntuPackages
}

########################################################################################################################
# rebuild toolchain from source
#-----------------------------------------------------------------------------------------------------------------------
# See also How-to-build-toolchain.pdf e.g. from inside the source packages.
########################################################################################################################
function buildToolchain() {
    # 4.9, evtl. nur für ppa build: libmpc-dev
                    #--with-gmp=$BUILDDIR_NATIVE/host-libs/usr   ?
                    #--with-mpfr=$BUILDDIR_NATIVE/host-libs/usr  ?
                    #--with-mpc=$BUILDDIR_NATIVE/host-libs/usr   ?
    # --build_type=ppa --skip_steps=manual,gdb-with-python,mingw32,mingw32-gdb-with-python
    #   find: invalid mode '+111'   nach ca. 50min
    # --skip_steps=manual,gdb-with-python,mingw32,mingw32-gdb-with-python

    # guile-1.6 versus guile-1.8 wenn Ubuntu >= 12.04

    [ "$HOST_SYSTEM" != "Linux" ] && Error "Sorry, your host system $HOST_SYSTEM is currently not supported for the build from source feature"
    [ "$DOWNLOAD_DIR" == "" ] && Error "Download directory not specified"
    [ -d "$DOWNLOAD_DIR" ] || Error "Download directory $DOWNLOAD_DIR dont exist"

    echo "Unpacking source package ..."
    mkdir -p "$DOWNLOAD_DIR/src"
    tar -xjf "$DOWNLOAD_DIR/$ARCHIVE_BASENAME-src.tar.bz2" -C"$DOWNLOAD_DIR/src"

    local buildDir="$DOWNLOAD_DIR/src/$ARCHIVE_BASENAME"
    pushd "$buildDir" >/dev/null

    if [ "$HOST_SYSTEM" == "Linux" ]; then
        # fix "find: invalid mode '+111'" in e.g. 4.9-2015-q3
        # not required in at least 6.3-2017-q1
        echo "patching build-toolchain.sh"
        sed -i 's/\+111/\/111/g' build-toolchain.sh
        [ "$BUILD_NANOX" == "true" ] && sed -i 's/-fno-exceptions//g' build-toolchain.sh
    fi

    local buildPrerequisitesParams=""
    local buildToolchainParams=""
    if [ "$BUILD_PPA" != "false" ]; then
        buildToolchainParams+=" --build_type=ppa"
    fi
    if [ "$BUILD_WIN" == "false" ]; then
        buildPrerequisitesParams+=" --skip_steps=mingw32"
        buildToolchainParams+=" --skip_steps=mingw32"
    fi
    if true; then
        # Old toolchain builds (e.g. 4.9-2015-q3) might be bricked on newer ubuntu versions regarding pdf generation.
        # So we need to skip this.
        buildToolchainParams+=" --skip_steps=manual"
    fi

    echo "Unpacking source archives ..."
    cd src
    find -name '*.tar.*' | xargs -I% tar -xf %
    cd ..

    # the toolchain build scripts have trouble with some environment variables which might be set in kubuntu, eg. PULSE_PROP_OVERRIDE_application.icon_name
    local unsetEnv=()
    # TODO: Should generic unset all envvars which includes e.g. dots
    unsetEnv+=(--unset=PULSE_PROP_OVERRIDE_application.icon_name)
    unsetEnv+=(--unset=PULSE_PROP_OVERRIDE_application.name)
    unsetEnv+=(--unset=PULSE_PROP_OVERRIDE_application.version)
    echo "========== build-prerequisites.sh =========="
    env "${unsetEnv[@]}" bash -c "./build-prerequisites.sh $buildPrerequisitesParams"
    echo "========== build-toolchain.sh =========="
    env "${unsetEnv[@]}" bash -c "./build-toolchain.sh $buildToolchainParams"

    echo "---"
    ls -l
    echo "---"
    popd >/dev/null
}


########################################################################################################################
# Install toolchain to target directory
########################################################################################################################
function install() {
    [ -e "$INSTALL_DIR" ] && Error "Installation directory $INSTALL_DIR already exist"

    local maybeSudo=""

    if ! mkdir -p "$INSTALL_PARENT_DIR"; then
        echo "seems that we are not allowed to create the installation directory, maybe mr. sudo will help"
        maybeSudo="sudo"
        $maybeSudo echo "thanx for permission"
        $maybeSudo mkdir -p "$INSTALL_PARENT_DIR"
    fi

    if ! test -w "$INSTALL_PARENT_DIR"; then
        echo "seems that we are not allowed to write into $INSTALL_PARENT_DIR, maybe mr. sudo will help"
        maybeSudo="sudo"
        $maybeSudo echo "thanx for permission"
    fi

    echo "installing to $INSTALL_DIR ..."

    if [ "$HOST_SYSTEM" == "Cygwin" ]; then
        # On Cygwin, we can unpack the files directly into $INSTALL_DIR
        $maybeSudo /usr/bin/unzip -q "$DOWNLOAD_DIR/$ARCHIVE_BASENAME-win32.zip" -d"$INSTALL_DIR"
    else
        # For Linux and OSX, the archive itself contains a directory.
        # The name of the directory is potential (slightly) unknown for us and the conventions differ over the releases.
        # E.g.
        # - in  4.9-2015-q3: gcc-arm-none-eabi-4_9-2015q3-20150921-linux.tar.bz2 -> gcc-arm-none-eabi-4_9-2015q3
        # - but 6.3-2017-q1: gcc-arm-none-eabi-6-2017-q1-update-linux.tar.bz2    -> gcc-arm-none-eabi-6-2017-q1-update
        # - and 4.9-2015-q3: gcc-arm-none-eabi-4_9-2015q3-20150921-src.tar.bz2   -> gcc-arm-none-eabi-4_9-2015q3-20150921
        # - but 6.3-2017-q1: gcc-arm-none-eabi-6-2017-q1-update-src.tar.bz2      -> gcc-arm-none-eabi-6-2017-q1-update
        # TODO: Maybe we want to change the INSTALL_BASENAME to something like "gcc-arm-none-eabi-4_9-2015q3-nanox" and
        #       need to strictly avoid touching "gcc-arm-none-eabi-4_9-2015q3" in any way!
        #       Seems that we have to unpack into a tmp directory for this.
        [ "$HOST_SYSTEM" == "Linux"  ] && $maybeSudo tar -xjf "$DOWNLOAD_DIR/$ARCHIVE_BASENAME-linux.tar.bz2" -C"$INSTALL_PARENT_DIR"
        [ "$HOST_SYSTEM" == "Darwin" ] && $maybeSudo tar -xjf "$DOWNLOAD_DIR/$ARCHIVE_BASENAME-mac.tar.bz2"   -C"$INSTALL_PARENT_DIR"
        # From beginning with gcc 6.3, the archive will be extracted to something like "/opt/gcc-arm-none-eabi-6-2017-q1-update"
        # but we want to name it like "gcc-arm-none-eabi-6_3-2017q1" instead.
        [ "$ARCHIVE_DIRNAME" != "$INSTALL_BASENAME" ] && $maybeSudo mv "$INSTALL_PARENT_DIR/$ARCHIVE_DIRNAME" "$INSTALL_DIR"
    fi

    # checking if the expected folder was created
    [ -d "$INSTALL_DIR" ] || Error "Installing to $INSTALL_DIR failed for unknown reason"

    if [ "$INCLUDE_SRC" == "true" ]; then
        echo "installing sources ..."
        # also unzip some useful gcc sources
        # tar -xjf ../gcc-arm-none-eabi-4_9-2015q2-20150609-src.tar.bz2
        # -> extracts all to ./gcc-arm-none-eabi-4_9-2015q2-20150609 and we have e.g. a "gcc-arm-none-eabi-4_9-2015q2-20150609/src/gcc.tar.bz2"
        # when then "tar -xjf ../gcc-arm-none-eabi-4_9-2015q2-20150609/src/gcc.tar.bz2" we got directory "gcc" with about 500MiB and 100k files.
        # e.g. "gcc/libstdc++-v3/libsupc++/unwind-cxx.h"
        # we want to place this into the toolchain installation at e.g.
        #   /opt/gcc-arm-none-eabi-4_9-2015q2/
        # (there we normally find 4 directories "arm-none-eabi", "bin", "lib", "share")
        # so that we finally got a
        #   /opt/gcc-arm-none-eabi-4_9-2015q2/src/gcc/libstdc++-v3/libsupc++/unwind-cxx.h
        # finally we decide for
        # - gcc.tar.bz2     -> but only the libstdc++-v3 subfolder
        # - newlib.tar.bz2  -> but only the newlib/libc subfolder
        #   -> maybe later newlib/libgloss/arm for e.g. _exit.c
        mkdir -p "$DOWNLOAD_DIR/tmpSrc"
        tar -xjf "$DOWNLOAD_DIR/$ARCHIVE_BASENAME-src.tar.bz2" -C"$DOWNLOAD_DIR/tmpSrc" $ARCHIVE_BASENAME/src/gcc.tar.bz2 $ARCHIVE_BASENAME/src/newlib.tar.bz2
        $maybeSudo mkdir -p "$INSTALL_DIR/src"
        $maybeSudo tar -xjf "$DOWNLOAD_DIR/tmpSrc/$ARCHIVE_BASENAME/src/gcc.tar.bz2"    -C"$INSTALL_DIR/src" gcc/libstdc++-v3
        $maybeSudo tar -xjf "$DOWNLOAD_DIR/tmpSrc/$ARCHIVE_BASENAME/src/newlib.tar.bz2" -C"$INSTALL_DIR/src" newlib/newlib/libc
    fi
}


########################################################################################################################
# Remove temporary files
########################################################################################################################
function cleanup() {
    if [ "$DOWNLOAD_DIR" != "" ]; then
        if [ "$RETAIN_TMP" == "false" ]; then
            echo "Removing temporary directories & files from $DOWNLOAD_DIR"
            rm -rf "$DOWNLOAD_DIR"
        else
            echo "Retaining temporary directories & files in $DOWNLOAD_DIR"
        fi
            tempdirs=()
    fi
}


########################################################################################################################
#   ____                                _
#  |  _ \ __ _ _ __ __ _ _ __ ___   ___| |_ ___ _ __ ___
#  | |_) / _` | '__/ _` | '_ ` _ \ / _ \ __/ _ \ '__/ __|
#  |  __/ (_| | | | (_| | | | | | |  __/ ||  __/ |  \__ \
#  |_|   \__,_|_|  \__,_|_| |_| |_|\___|\__\___|_|  |___/
#
########################################################################################################################

while (("$#")); do
    if [ "$1" == "?" ] || [ "$1" == "-?" ] || [ "$1" == "-h" ] || [ "$1" == "-help" ] || [ "$1" == "--help" ]; then
        ShowHelp
        exit 0
    elif [ "$1" == "--retainTmp" ]; then
        RETAIN_TMP="true"
    elif [ "$1" == "-b" ] || [ "$1" == "--buildFromSrouce" ]; then
        BUILD_FROM_SOURCE="true"
    elif [ "$1" == "--ppa" ]; then
        BUILD_PPA="true"
    elif [ "$1" == "--win" ]; then
        BUILD_WIN="true"
    elif [ "$1" == "--nanox" ]; then
        BUILD_NANOX="true"
    elif [ "$GCC_ARM_VERSION" == "" ]; then
        GCC_ARM_VERSION="$1"
    else
        echo "Unexpected parameter \"$1\"" >&2
        ShowHelp
        exit 1
    fi
    shift
done

[ "$GCC_ARM_VERSION" == "latest" ] && GCC_ARM_VERSION="6.3-2017-q1"

if [ "$GCC_ARM_VERSION" == "" ]; then
    echo "Please specify toolchain version, e.g. \"4.9-2015-q2\"." >/dev/stderr
    ShowHelp
    exit 1
fi

########################################################################################################################
#   __  __       _
#  |  \/  | __ _(_)_ __
#  | |\/| |/ _` | | '_ \
#  | |  | | (_| | | | | |
#  |_|  |_|\__,_|_|_| |_|
########################################################################################################################

detectHost
checkPrerequisites
setVersionVars
download
if [ "$BUILD_FROM_SOURCE" == "true" ]; then
    checkBuildPrerequisites
    buildToolchain
fi
install
cleanup
echo "finish"
