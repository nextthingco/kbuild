# kbuild

![kbuild logo](logo.png)

A Docker based script that builds Debian packages for the Linux kernel as well
as for external kernel modules.


## Requirements

While the script can be run in any Debian based Linux Distribution (given all
necessary dependencies are installed), it has only been tested runnning Debian
Stretch on amd64 compatible machines.
Therefore, it is strongly recommended to make use of Docker which allows for
building the kernel and module packages in a defined environment - even with
Windows or Mac OS as host OS.
The kbuild script has been tested with Docker version 17.12.0-ce.


## Installation

Make sure Docker is installed and in the search PATH - there is plenty of
information how to do that on the internet, https://docs.docker.com is a good
start.

Installation of kbuild itself is easy. Just download the `kbuild` script
from this repository and put it in your executeable search PATH, e.g.:
```
sudo wget https://ntc.githost.io/nextthingco/kbuild/raw/unstable/kbuild -O /usr/local/bin/kbuild
```

## External kernel modules

Currently the following external kernel modules are supported:
 - RTL8723 DS / BS Wifi drivers
 - Mali 400 drivers for C.H.I.P


## Configuration files

The script needs to know certain parameters, e.g. the architecture to build
and where to find the sources for the kernel and external modules.
These can be specified either as environment variables or be read from a
configuration file usually named `kconfig.cfg`.

### Generic options

 - **ARCH**: Target architecture, e.g. `arm`, or `arm64`
 - **DPKG_ARCH**: Debian package architecture, can be `arm`, `armhf` or `arm64`
 - **DEBFULLNAME**: Name or Company who builds the .deb packages
 - **DEBEMAIL**: Contact e-mail of the packager
 - **CROSS_COMPILE**: Cross compiler toolchain prefix e.g. `arm-linux-gnueabihf-`

### Linux options
 - **LINUX_FLAVOR**: Random flavor name e.g. `chip`
 - **LINUX_DIST**: Debian release e.g. `jessie` or `stretch`
 - **LINUX_REPO**: Git repository to clone Linux source code from, e.g. git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
 - **LINUX_BRANCH**: Branch of the Linux repository, e.g. `master`
 - **LINUX_CONFIG**: e.g. `multi_v7_defconfig`

### RTL8723 options
 - **RTL8723_REPO**: Git repository to clone the RTL8723 source code from, e.g. https://github.com/nextthingco/rtl8723bs
 - **RTL8723_BRANCH**: Branch of the RTL8723 repository, e.g. `ja/8723-update`

### MALI options
 - **CHIP_MALI_BRANCH**: Branch of the CHIP Mali repository, e.g. `debian`
 - **CHIP_MALI_REPO**: Git repository to clone CHIP Mali source code from, e.g. git://github.com/nextthingco/chip-mali


## Usage

[...]


## Example: 

[...]
