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

[...]


## External kernel modules

Currently the following external kernel modules are supported:
 - RTL8723 DS / BS Wifi drivers
 - Mali 400 drivers for C.H.I.P


## Configuration files

The script needs to know certain parameters, e.g. the architecture to build
and where to find the sources for the kernel and external modules.
These can be specified either as environment variables or be read from a
configuration file usually named `kconfig.cfg`

### Generic options

 - _ARCH_: e.g. `arm`
 - `DPKG_ARCH`: e.g. `armhf`
 - `DEBFULLNAME`: Name / Company who builds the .deb packages
 - `DEBEMAIL`: Contact e-mail of the packager
 - `CROSS_COMPILE`: e.g. `arm-linux-gnueabihf-`

### Linux options
 - `LINUX_FLAVOR`: e.g. "chip"
 - `LINUX_DIST`: Debian release e.g. `jessie` or `stretch`
 - `LINUX_BRANCH`: e.g. `master`
 - `LINUX_REPO`, e.g.  `git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git`
 - `LINUX_CONFIG`, e.g. `multi_v7_defconfig`

### RTL8723 options
 - `RTL8723_BRANCH`: e.g. `ja/8723-update`
 - `RTL8723_REPO`: e.g. https://github.com/lwfinger/rtl8723`

### MALI options
 - `CHIP_MALI_BRANCH`: e.g. `debian`
 - `CHIP_MALI_REPO`: e.g. `git://github.com/nextthingco/chip-mali`


## Usage

[...]


## Example: 

[...]
