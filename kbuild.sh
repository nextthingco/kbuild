#!/bin/bash
##============================================================================
#%
#% USAGE: kbuild.sh [OPTIONS] COMMAND
#%
#% If no configuration file is specified, it looks for a file named
#% kbuild.cfg in current directory.
#%
#%
#% COMMANDS:
#%   init BOARDNAME       Creates a kbuild.cfg file in the current directory.
#%                        BOARDNAME can be CHIP or CHIPPRO.
#%
#%   all                  Builds everything specified in the CONFIG_FILE file
#%   linux                Only build Linux Debian packages
#%   rtl8723              Only build RTL8723 Wifi drivers packages
#%   chip-mali            Only build Mali GPU drivers for C.H.I.P 
#%
#%   linux-nconfig        Make local changes the Linux configuration
#%   linux-defconfig      Apply defconfig (reset local changes).
#%   linux-savedefconfig  Save local changes to out-of-tree Linux defconfig.
#%
#% OPTIONS:
#%   -h                   Show this help
#%   -v                   Show verbose output
#%
##============================================================================

set -e

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="kbuild.cfg"

function help() {
    head -n 200 "$SCRIPT_DIR/$(basename $0)" | sed -n -e 's/^#%//gp;'
    exit
}

function read_cfg_file() {
  local config_file="$1"
  
  echo "Reading $config_file..."

  source $config_file

  ## MANDATORY VARIABLES
  export          ARCH="${ARCH:?ARCH not set}"
  export     DKPG_ARCH="${DPKG_ARCH:?DKPG_ARCH not set}"
  export CROSS_COMPILE="${CROSS_COMPILE:?CROSS_COMPILE not set}"
  export   DEBFULLNAME="${DEBFULLNAME:?DEB_FULLNAME not set}"
  export      DEBEMAIL="${DEBEMAIL:?DEBEMAIL not set}"
  ## DEFAULT VARIABELS (don't touch)
  export      BUILD_NUMBER="${CI_JOB_ID:-666}"
  export CONCURRENCY_LEVEL=$(( $(nproc) * 2 ))
  export   GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no}"
  export    LOCAL_BUILDDIR="${LOCAL_BUILDDIR:-$PWD/build}"
  export      LINUX_SRCDIR="${LINUX_SRCDIR:-$LOCAL_BUILDDIR/linux}"

  if [[ ! -z "$PRIVATE_DEPLOY_KEY" ]]; then
      eval $(ssh-agent -s)
      ssh-add <(echo "$PRIVATE_DEPLOY_KEY")
  fi
}

function git_clone() {
    local REPO=$1
    local BRANCH=$2
    local SRCDIR=$3

    if [[ ! -d "${SRCDIR}" ]]; then 
        git clone --branch ${BRANCH} --single-branch --depth 1 ${REPO} "${SRCDIR}" || return $?
        pushd "${SRCDIR}"
        git config user.email "${DEBEMAIL}" && \
        git config user.name "${DEBFULLNAME}"
        popd
     fi
}

## KERNEL
function check_linux_vars() {
    LINUX_FLAVOR="${LINUX_FLAVOR:?LINUX_FLAVOR not set}"
      LINUX_DIST="${LINUX_DIST:?LINUX_DIST not set}"
    LINUX_BRANCH="${LINUX_BRANCH:?LINUX_BRANCH not set}"
      LINUX_REPO="${LINUX_REPO:?LINUX_REPO not set}"
    LINUX_CONFIG="${LINUX_CONFIG:?LINUX_CONFIG not set}"
}

function cmd_linux_defconfig() {
    check_linux_vars

    local defconfig

    if [[ "$LINUX_CONFIG" == :* ]]; then #in-tree-defconfig
        defconfig=${LINUX_CONFIG#:}
    else #out-of tree defconfig
        defconfig="__kbuild_defconfig"
        cp -va "${LINUX_CONFIG}" "${LINUX_SRCDIR}/arch/${ARCH}/configs/${defconfig}"
    fi

    pushd "${LINUX_SRCDIR}"
    make $defconfig
    popd
}

function cmd_linux_nconfig() {
    check_linux_vars
    git_clone $LINUX_REPO $LINUX_BRANCH $LINUX_SRCDIR

    pushd "${LINUX_SRCDIR}"
    [[ ! -f .config ]] && linux-defconfig
    make nconfig
    popd
}

function cmd_linux_savedefconfig() {
    check_linux_vars
    git_clone $LINUX_REPO $LINUX_BRANCH $LINUX_SRCDIR

    local defconfig

    pushd "${LINUX_SRCDIR}"
    [[ ! -f .config ]] && cmd_linux_defconfig

    if [[ "$LINUX_CONFIG" == :* ]]; then #in-tree-defconfig
        defconfig="${LINUX_CONFIG#:}"
        if [[ "$command" != "init" ]]; then
            echo "WARNING: you have an in-tree-defconfig in your kbuild.cfg"
            echo "         don't forget to update the kbuild.cfg file"
        fi
    else
        defconfig="${LINUX_CONFIG}"
    fi
    make savedefconfig
    popd

    cp -va "${LINUX_SRCDIR}/defconfig" "${defconfig}"
}

function cmd_linux() {
    check_linux_vars
    git_clone $LINUX_REPO $LINUX_BRANCH $LINUX_SRCDIR

    pushd "${LINUX_SRCDIR}"

    [[ ! -f .config ]] && linux-defconfig
    #git clean -xfd .
    #git checkout .

    export KBUILD_DEBARCH=${ARCH}
    export KDEB_CHANGELOG_DIST=${LINUX_DIST}
    export LOCALVERSION=-${LINUX_FLAVOR}
    export KDEB_PKGVERSION=$(make kernelversion)-${BUILD_NUMBER}

    # remove -gGITREVISION from debian filename
    sed -i "s|CONFIG_LOCALVERSION_AUTO=.*|CONFIG_LOCALVERSION_AUTO=n|" .config

    make -j${CONCURRENCY_LEVEL} prepare modules_prepare scripts
    make -j${CONCURRENCY_LEVEL} deb-pkg

    popd
    mv "${LOCAL_BUILDDIR}/"*.deb "${LOCAL_BUILDDIR}/.."
}

## WIFI
function cmd_rtl8723() {
    RTL8723_BRANCH="${RTL8723_BRANCH:?RTL8723_BRANCH not set}"
    RTL8723_REPO="${RTL8723_REPO:?RTL8723_REPO not set}"
   
    RTL8723_VARIANT="$(echo ${RTL8723_REPO##*/} | tr '[:upper:]' '[:lower:]')"
    RTL8723_SRCDIR="$LOCAL_BUILDDIR/$RTL8723_VARIANT"
	RTL8723_SRCDIR="${RTL8723_SRCDIR:?RTL8723_SRCDIR not set}"
    echo "RTL8723_SRCDIR=$RTL8723_SRCDIR"

    git_clone $LINUX_REPO $LINUX_BRANCH $LINUX_SRCDIR
    pushd $LINUX_SRCDIR; [[ ! -f .config ]] && make $LINUX_CONFIG; popd
    git_clone $RTL8723_REPO $RTL8723_BRANCH $RTL8723_SRCDIR

    pushd $RTL8723_SRCDIR
    #git clean -xfd .
    #git checkout .
 
    [ ! -z $RTL8723_PATCHDIR ] && git am "$RTL8723_PATCHDIR"/*

    export BUILDDIR="${RTL8723_SRCDIR}/build"
    export RTL_VER=$(dpkg-parsechangelog --show-field Version)
    export CC=${CROSS_COMPILE}gcc
    export $(dpkg-architecture -a${DPKG_ARCH})

    export KERNEL_VER=$(cd $LINUX_SRCDIR; make kernelversion)

    dpkg-buildpackage -A -uc -us -nc
    sudo dpkg -i ../${RTL8723_VARIANT}-mp-driver-source_${RTL_VER}_all.deb

    mkdir -p $BUILDDIR/usr_src

    cp -a /usr/src/modules/${RTL8723_VARIANT}-mp-driver/* $BUILDDIR
    pushd /usr/src
    sudo tar -zcvf ${RTL8723_VARIANT}-mp-driver.tar.gz modules/${RTL8723_VARIANT}-mp-driver
    popd

    m-a -t -u $BUILDDIR \
        -l $KERNEL_VER \
        -k $LINUX_SRCDIR \
        build ${RTL8723_VARIANT}-mp-driver-source

    # for some reason, if .deb files are mv'ed, the next build fails
    # unless it's a clean build from scratch - that's why we cp here     
    cp $BUILDDIR/*.deb "$LOCAL_BUILDDIR/.."
    cp $LOCAL_BUILDDIR/*.deb "$LOCAL_BUILDDIR/.."
    popd
}

## chip_mali
function cmd_chip_mali() {
    CHIP_MALI_BRANCH="${CHIP_MALI_BRANCH:?CHIP_MALI_BRANCH not set}"
    CHIP_MALI_REPO="${CHIP_MALI_REPO:?CHIP_MALI_REPO not set}"

    CHIP_MALI_SRCDIR="${LOCAL_BUILDDIR}/$(echo ${CHIP_MALI_REPO##*/} | tr '[:upper:]' '[:lower:]')"
    CHIP_MALI_SRCDIR="${CHIP_MALI_SRCDIR:?CHIP_MALI_SRCDIR not set}"

    git_clone $LINUX_REPO $LINUX_BRANCH $LINUX_SRCDIR
    pushd $LINUX_SRCDIR; [[ ! -f .config ]] && make $LINUX_CONFIG; popd
    git_clone $CHIP_MALI_REPO $CHIP_MALI_BRANCH $CHIP_MALI_SRCDIR
 
	export MALI_SRC="${CHIP_MALI_SRCDIR}/driver/src/devicedrv/mali"
	export DEB_OUTPUT="$MALI_SRC/output"
	export $(dpkg-architecture -a${DPKG_ARCH})
	export KERNEL_VER=$(cd $LINUX_SRCDIR; make kernelversion)

	pushd $MALI_SRC
	mkdir -p $DEB_OUTPUT/usr_src
	export MALI_VER=$(cd $MALI_SRC; dpkg-parsechangelog --show-field Version)
	KDIR="$LINUX_SRCDIR" USING_UMP=0 dpkg-buildpackage -A -uc -us -nc
	sudo dpkg -i $MALI_SRC/../chip-mali-source_${MALI_VER}_all.deb
	m-a -t -u $DEB_OUTPUT -l $KERNEL_VER -k $LINUX_SRCDIR build chip-mali-source
	mv ${DEB_OUTPUT}/*.deb "$LOCAL_BUILDDIR/.."
    popd
}

function cmd_init() {
    [[ -f "$CONFIG_FILE" ]] && echo "ERROR: '$CONFIG_FILE' already exists" && exit 1
    local board="$1"

    case "$board" in
        "")
            echo "ERROR: no boardname specified."
			exit -1
            ;;
        "chip")
			cat >"$CONFIG_FILE" <<EOF
#### kbuild config for CHIP
ARCH=arm
DPKG_ARCH=armhf
DEBFULLNAME="Next Thing Co."
DEBEMAIL="software@nextthing.co"
CROSS_COMPILE=arm-linux-gnueabihf-
####
LINUX_FLAVOR="chip"
  LINUX_DIST="stretch"
LINUX_BRANCH="debian/4.4.13-ntc-mlc"
  LINUX_REPO="git://github.com/nextthingco/CHIP-linux"
LINUX_CONFIG="multi_v7_defconfig"
####
RTL8723_BRANCH="ja/8723-update"
RTL8723_REPO="https://github.com/nextthingco/rtl8723bs"
#### 
CHIP_MALI_BRANCH="debian"
CHIP_MALI_REPO="git://github.com/nextthingco/chip-mali"
EOF
            ;;
        *)
            echo "ERROR: unknown board '$board'."
			return -1
            ;;
    esac
}


while getopts ":hv" opt; do
    case $opt in
        h)
            help
            ;;
        v)
            export VERBOSE_FLAG="-v"
            ;;
        \?)
            echo "invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done
shift "$((OPTIND - 1))"

command="$1"

if [[ "${command}" != "init" ]]; then
  [[ ! -f "${CONFIG_FILE}" ]] && echo "ERROR: cannot find configuration file '$CONFIG_FILE'" && exit 1
  read_cfg_file "${CONFIG_FILE}"
fi

case "$1" in
    init)
        cmd_init $2
        read_cfg_file "${CONFIG_FILE}"
        # generate out-of-tree defconfig from in-tree defconfig
        LINUX_CONFIG=":$LINUX_CONFIG"
        cmd_linux_savedefconfig
        exit $?
        ;;

    linux) cmd_linux;;
    rtl8723) cmd_rtl8723;;
    chip-mali) cmd_chip_mali;;
    all) 
        cmd_linux
        [[ ! -z "$RTL8723_REPO" ]] && cmd_rtl8723
        [[ ! -z "$CHIP_MALI_REPO" ]] && cmd_chip_mali
        ;;

    linux-nconfig) cmd_linux_nconfig;;
    linux-savedefconfig) cmd_linux_savedefconfig;;
    linux-defconfig) cmd_linux_defconfig;;

    "")
        help
        ;;

    *)
        echo "ERROR: unknown command '$command'"
        exit 1
        ;;
esac

