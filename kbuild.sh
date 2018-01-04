#!/bin/bash

set -e

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
CONFIG_FILE=${CONFIG_FILE:-$1}
echo "CONFIG_FILE=$CONFIG_FILE"
[[ -z "${CONFIG_FILE}" ]] && [[ -f "kbuild.cfg" ]] && echo huh!  && export CONFIG_FILE="kbuild.cfg"
[[ ! -z "${CONFIG_FILE}" ]] && read_cfg_file "${CONFIG_FILE}"
echo "CONFIG_FILE=$CONFIG_FILE"

## OPTIONAL VARIABLES
# ...
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
export LINUX_SRCDIR="${LINUX_SRCDIR:-$PWD/linux}"
    
if [[ ! -z "$PRIVATE_DEPLOY_KEY" ]]; then
   eval $(ssh-agent -s)
   ssh-add <(echo "$PRIVATE_DEPLOY_KEY")
fi

## KERNEL
function linux() {
    ## MANDATORY VARIABLES
    LINUX_FLAVOR="${LINUX_FLAVOR:?LINUX_FLAVOR not set}"
      LINUX_DIST="${LINUX_DIST:?LINUX_DIST not set}"
    LINUX_BRANCH="${LINUX_BRANCH:?LINUX_BRANCH not set}"
      LINUX_REPO="${LINUX_REPO:?LINUX_REPO not set}"
    LINUX_CONFIG="${LINUX_CONFIG:?LINUX_CONFIG not set}"

    [[ ! -d "${LINUX_SRCDIR}" ]] && git clone --branch ${LINUX_BRANCH} --single-branch --depth 1 ${LINUX_REPO} "${LINUX_SRCDIR}"

    pushd "${LINUX_SRCDIR}"
    git clean -xfd .
    git checkout .


    export KBUILD_DEBARCH=${ARCH}
    export KDEB_CHANGELOG_DIST=${LINUX_DIST}
    export LOCALVERSION=-${LINUX_FLAVOR}
    export KDEB_PKGVERSION=$(make kernelversion)-${BUILD_NUMBER}

    git config user.email "${DEBEMAIL}"
    git config user.name "${DEBFULLNAME}"

    make ${LINUX_CONFIG}

    # remove -gGITREVISION from debian filename
    sed -i "s|CONFIG_LOCALVERSION_AUTO=.*|CONFIG_LOCALVERSION_AUTO=n|" .config

    make -j${CONCURRENCY_LEVEL} prepare modules_prepare scripts
    make -j${CONCURRENCY_LEVEL} deb-pkg

    popd
}

## RTL
function rtl8723() {

    ## OPTIONAL VARIABLES
    
    ## MADATORY VARIABLES
		RTL8723_BRANCH="${RTL8723_BRANCH:?RTL8723_BRANCH not set}"
		  RTL8723_REPO="${RTL8723_REPO:?RTL8723_REPO not set}"
   
    RTL8723_SRCDIR="$(echo ${RTL8723_REPO##*/} | tr '[:upper:]' '[:lower:]')"
	RTL8723_SRCDIR="${RTL8723_SRCDIR:?RTL8723_SRCDIR not set}"

    echo RTL8723_SRCDIR=$RTL8723_SRCDIR

    [[ ! -d "${LINUX_SRCDIR}" ]] && git clone --branch ${RTL8723_BRANCH} --single-branch --depth 1 ${RTL8723_REPO} "${RTL8723_SRCDIR}"

    pushd $RTL8723_SRCDIR
    git clean -xfd .
    git checkout .

    git config user.email "${DEBEMAIL}"
    git config user.name "${DEBFULLNAME}"
 
    [ ! -z $RTL8723_PATCHDIR ] && git am "$RTL8723_PATCHDIR"/*

    export BUILDDIR="${RTL8723_SRCDIR}/build"
    export RTL_VER=$(dpkg-parsechangelog --show-field Version)
    export CC=${CROSS_COMPILE}gcc
    export $(dpkg-architecture -a${DPKG_ARCH})

    export KERNEL_VER=$(cd $LINUX_SRCDIR; make kernelversion)

    dpkg-buildpackage -A -uc -us -nc
    sudo dpkg -i ../${RTL8723_SRCDIR}-mp-driver-source_${RTL_VER}_all.deb

    mkdir -p $BUILDDIR/usr_src

    cp -a /usr/src/modules/${RTL8723_SRCDIR}-mp-driver/* $BUILDDIR
    pushd /usr/src
    sudo tar -zcvf ${RTL8723_SRCDIR}-mp-driver.tar.gz modules/${RTL8723_SRCDIR}-mp-driver
    popd

    echo m-a -t -u $BUILDDIR \
        -l $KERNEL_VER \
        -k $LINUX_SRCDIR \
        build ${RTL8723_SRCDIR}-mp-driver-source
    m-a -t -u $BUILDDIR \
        -l $KERNEL_VER \
        -k $LINUX_SRCDIR \
        build ${RTL8723_SRCDIR}-mp-driver-source
     
    mv $BUILDDIR/*.deb ../
    popd
}

## chip_mali
function chip_mali() {

    ## OPTIONAL VARIABLES
    
    ## MADATORY VARIABLES
		CHIP_MALI_BRANCH="${CHIP_MALI_BRANCH:?CHIP_MALI_BRANCH not set}"
		  CHIP_MALI_REPO="${CHIP_MALI_REPO:?CHIP_MALI_REPO not set}"

    CHIP_MALI_SRCDIR="$(echo ${CHIP_MALI_REPO##*/} | tr '[:upper:]' '[:lower:]')"
    CHIP_MALI_SRCDIR="${CHIP_MALI_SRCDIR:?CHIP_MALI_SRCDIR not set}"

    git clone --branch ${CHIP_MALI_BRANCH} --single-branch --depth 1 ${CHIP_MALI_REPO} "${CHIP_MALI_SRCDIR}"

	export MALI_SRC="$(pwd)/${CHIP_MALI_SRCDIR}/driver/src/devicedrv/mali"
	export DEB_OUTPUT="$MALI_SRC/output"
	export $(dpkg-architecture -a${DPKG_ARCH})
	export KERNEL_VER=$(cd $LINUX_SRCDIR; make kernelversion)

	pushd $MALI_SRC
	mkdir -p $DEB_OUTPUT/usr_src
	export MALI_VER=$(cd $MALI_SRC; dpkg-parsechangelog --show-field Version)
	KDIR="$LINUX_SRCDIR" USING_UMP=0 dpkg-buildpackage -A -uc -us -nc
	sudo dpkg -i $MALI_SRC/../chip-mali-source_${MALI_VER}_all.deb
	m-a -t -u $DEB_OUTPUT -l $KERNEL_VER -k $LINUX_SRCDIR build chip-mali-source
	mv ${DEB_OUTPUT}/*.deb ${LINUX_SRCDIR}/../
    popd
}

## BUILD !
linux #linux is always build!
[[ ! -z "$RTL8723_REPO" ]]   && rtl8723
[[ ! -z "$CHIP_MALI_REPO" ]] && chip_mali

