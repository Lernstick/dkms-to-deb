#!/bin/sh -x

# Based on the idea of https://github.com/NVIDIA/yum-packaging-precompiled-kmod/blob/main/dnf-kmod-nvidia.spec
STRIP="strip -g --strip-unneeded"
_LD="/usr/bin/ld.gold"
MODULES="wl"


NAME=$1
VERSION=$2
KVER=$3
DESTDIR=$4

unset LD_RUN_PATH
unset LD_LIBRARY_PATH

tar zxvf "${NAME}-${VERSION}.dkms.tar.gz"
cd dkms_source_tree

make KVER=${KVER}


${STRIP} src/wl/sys/wl_cfg80211_hybrid.o
${STRIP} src/wl/sys/wl_iw.o
${STRIP} src/wl/sys/wl_linux.o
${STRIP} src/shared/linux_osl.o


${_LD} -r -o wl.o src/wl/sys/wl_cfg80211_hybrid.o src/wl/sys/wl_iw.o src/wl/sys/wl_linux.o src/shared/linux_osl.o

for m in ${MODULES}
do
	${STRIP} ${m}.o --keep-symbol=init_module --keep-symbol=cleanup_module
	rm ${m}.ko

    #TODO make this arch independent
	${_LD} -r \
		-z max-page-size=0x200000 -T "/usr/src/linux-headers-${KVER}/arch/x86/module.lds" \
		--build-id -r \
		-o ${m}.ko \
		${m}.o \
		${m}.mod.o
done


DEST_PATH="${DESTDIR}/usr/lib/broadcom-sta/${NAME}-${VERSION}/$KVER"
# Copy needed files
install -d ${DEST_PATH}
# Copy .ko files for signing service only! They sould not be shipped publicly
install -m 644 *.ko ${DEST_PATH}

# driver
install wl.mod.o ${DEST_PATH}
install -d ${DEST_PATH}/src/wl/sys
install -d ${DEST_PATH}/src/shared
install src/wl/sys/wl_cfg80211_hybrid.o ${DEST_PATH}/src/wl/sys
install src/wl/sys/wl_iw.o ${DEST_PATH}/src/wl/sys
install src/wl/sys/wl_linux.o ${DEST_PATH}/src/wl/sys
install src/shared/linux_osl.o ${DEST_PATH}/src/shared

# Copy linker and module.lds, we need the exact version to make this work.
install -m 755 ${_LD} ${DEST_PATH}
install -m 755 "/usr/src/linux-headers-${KVER}/arch/x86/module.lds" ${DEST_PATH}