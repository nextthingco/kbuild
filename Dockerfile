FROM debian:stretch

RUN  \
dpkg --add-architecture armhf && \
dpkg --add-architecture arm64 && \
\
apt -y update && apt -y upgrade && apt -y install \
  dpkg-dev dh-make dh-systemd dkms module-assistant bc \
  libncurses5-dev \
  crossbuild-essential-arm64 \
  crossbuild-essential-armhf \
  git vim wget && \
\
wget https://releases.linaro.org/components/toolchain/binaries/4.9-2016.02/arm-linux-gnueabihf/gcc-linaro-4.9-2016.02-x86_64_arm-linux-gnueabihf.tar.xz -O- | tar -C /opt -xJ && \
echo unpacking...
ENV PATH="/opt/gcc-linaro-4.9-2016.02-x86_64_arm-linux-gnueabihf/bin:${PATH}"
ADD kbuild.sh /usr/bin/kbuild.sh
