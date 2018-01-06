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
#%   all                  Builds everything specified in the CONFIG_FILE file
#%   linux                Only build Linux Debian packages
#%   rtl8723              Only build RTL8723 Wifi drivers packages
#%   chip-mali            Only build Mali GPU drivers for C.H.I.P 
#%
#%   linux-nconfig        Allows to modify the Linux configuration
#%   linux-savedefconfig  Save Linux defconfig
#%
#% OPTIONS:
#%   -h                   Show this help
#%   -v                   Show verbose output
#%   -c CONFIG_FILE       Use custom config file
#%
##============================================================================

set -ex

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

function help() {
    head -n 200 "$SCRIPT_DIR/$(basename $0)" | sed -n -e 's/^#%//gp;'
    exit
}

while getopts ":hvc:" opt; do
    case $opt in
        h)
            help
            ;;
        v)
            export VERBOSE_FLAG="-v"
            ;;
        c)
            CONFIG_FILE="${OPTARG}"
            ;;
        \?)
            echo "invalid option: -$OPTARG"
            exit 1
            ;;
    esac
done
shift "$((OPTIND - 1))"

function read_cfg_file() {
  local config_file="$1"
  
  echo "Reading $config_file..."

  local regex='(https?|ftp)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'
  if [[ $config_file =~ $regex ]]
  then
      echo "Downloading config file..."
      eval $(wget $config_file -O-)
  else
      source $config_file
  fi
}

# CONFIG_FILE either spacified as environment variable or as first command line parameter
CONFIG_FILE=${CONFIG_FILE:-kbuild.cfg}
[[ ! -f "kbuild.cfg" ]] && echo "ERROR: cannot find configuration file '$CONFIG_FILE'" && exit 1
read_cfg_file "${CONFIG_FILE}"

command="$1"
case "$1" in
    linux)
        ;;
    rtl8723)
        ;;
    chip-mali)
        ;;
    all)
        #command="linux; [[ ! -z "$RTL8723_REPO" ]] && rtl8723; [[ ! -z "$CHIP_MALI_REPO" ]] && chip-mali"
        command="[[ ! -z "$RTL8723_REPO" ]] && rtl8723; [[ ! -z "$CHIP_MALI_REPO" ]] && chip-mali"
        ;;

    linux-nconfig)
        ;;
    linux-savedefconfig)
        ;;

    "")
        help
        ;;

    *)
        echo "ERROR: unknown command '$command'"
        exit 1
        ;;
esac


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
export LOCAL_BUILDDIR="${LOCAL_BUILDDIR:-$PWD/build}"
export LINUX_SRCDIR="${LINUX_SRCDIR:-$LOCAL_BUILDDIR/linux}"
    
if [[ ! -z "$PRIVATE_DEPLOY_KEY" ]]; then
   eval $(ssh-agent -s)
   ssh-add <(echo "$PRIVATE_DEPLOY_KEY")
fi

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
function linux-nconfig() {
    LINUX_FLAVOR="${LINUX_FLAVOR:?LINUX_FLAVOR not set}"
      LINUX_DIST="${LINUX_DIST:?LINUX_DIST not set}"
    LINUX_BRANCH="${LINUX_BRANCH:?LINUX_BRANCH not set}"
      LINUX_REPO="${LINUX_REPO:?LINUX_REPO not set}"
    LINUX_CONFIG="${LINUX_CONFIG:?LINUX_CONFIG not set}"

    git_clone $LINUX_REPO $LINUX_BRANCH $LINUX_SRCDIR

    echo huh
    pushd "${LINUX_SRCDIR}"
    [[ ! -f .config ]] && make $LINUX_CONFIG
    make nconfig
    popd
}

function linux-savedefconfig() {
    LINUX_FLAVOR="${LINUX_FLAVOR:?LINUX_FLAVOR not set}"
      LINUX_DIST="${LINUX_DIST:?LINUX_DIST not set}"
    LINUX_BRANCH="${LINUX_BRANCH:?LINUX_BRANCH not set}"
      LINUX_REPO="${LINUX_REPO:?LINUX_REPO not set}"
    LINUX_CONFIG="${LINUX_CONFIG:?LINUX_CONFIG not set}"

    git_clone $LINUX_REPO $LINUX_BRANCH $LINUX_SRCDIR

    pushd "${LINUX_SRCDIR}"
    [[ ! -f .config ]] && echo "ERROR: no .config to save"
    make savedefconfig && cp -va defconfig arch/$ARCH/configs/$LINUX_CONFIG
    popd
 }


function linux() {
    ## MANDATORY VARIABLES
    LINUX_FLAVOR="${LINUX_FLAVOR:?LINUX_FLAVOR not set}"
      LINUX_DIST="${LINUX_DIST:?LINUX_DIST not set}"
    LINUX_BRANCH="${LINUX_BRANCH:?LINUX_BRANCH not set}"
      LINUX_REPO="${LINUX_REPO:?LINUX_REPO not set}"
    LINUX_CONFIG="${LINUX_CONFIG:?LINUX_CONFIG not set}"

    git_clone $LINUX_REPO $LINUX_BRANCH $LINUX_SRCDIR

    pushd "${LINUX_SRCDIR}"

    [[ ! -f .config ]] && make $LINUX_CONFIG
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
    mv *.deb "${LOCAL_BUILDDIR}/.."
}

## RTL
function rtl8723() {

    ## OPTIONAL VARIABLES
    
    ## MADATORY VARIABLES
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
    echo PWD=$PWD
    dpkg -i ../${RTL8723_VARIANT}-mp-driver-source_${RTL_VER}_all.deb

    mkdir -p $BUILDDIR/usr_src

    cp -a /usr/src/modules/${RTL8723_VARIANT}-mp-driver/* $BUILDDIR
    pushd /usr/src
    tar -zcvf ${RTL8723_VARIANT}-mp-driver.tar.gz modules/${RTL8723_VARIANT}-mp-driver
    popd

    m-a -t -u $BUILDDIR \
        -l $KERNEL_VER \
        -k $LINUX_SRCDIR \
        build ${RTL8723_VARIANT}-mp-driver-source
     
    mv $BUILDDIR/*.deb "$LOCAL_BUILDDIR/.."
    mv $LOCAL_BUILDDIR/*.deb "$LOCAL_BUILDDIR/.."
    popd
}

## chip_mali
function chip-mali() {

    ## OPTIONAL VARIABLES
    
    ## MADATORY VARIABLES
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
	dpkg -i $MALI_SRC/../chip-mali-source_${MALI_VER}_all.deb
	m-a -t -u $DEB_OUTPUT -l $KERNEL_VER -k $LINUX_SRCDIR build chip-mali-source
	mv ${DEB_OUTPUT}/*.deb "$LOCAL_BUILDDIR/.."
    popd
}

echo "Running command $command"
eval "$command"
