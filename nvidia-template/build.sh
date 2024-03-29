#!/bin/bash -x

# Port of https://github.com/NVIDIA/yum-packaging-precompiled-kmod/blob/main/dnf-kmod-nvidia.spec
STRIP="strip -g --strip-unneeded"
_LD="/usr/bin/ld.gold"
MODULES="nvidia nvidia-uvm nvidia-modeset nvidia-drm"

NAME=$1
VERSION=$2
KVER=$3
DESTDIR=$4

unset LD_RUN_PATH
unset LD_LIBRARY_PATH

tar zxvf "${NAME}-${VERSION}.dkms.tar.gz"
cd dkms_source_tree

# Debian applies some custom patches that we also have to apply.
# The list of patches are included in the dkms.conf file
source <(grep "PATCH" dkms.conf)
for p in ${PATCH[@]}
do
    patch -p1 < patches/${p}
done

make KERNEL_UNAME=${KVER} modules

${STRIP} nvidia/nv-interface.o
${STRIP} nvidia-uvm.o
${STRIP} nvidia-drm.o
${STRIP} nvidia-modeset/nv-modeset-interface.o

rm nvidia.o
rm nvidia-modeset.o

${_LD} -r -o nvidia.o nvidia/nv-interface.o nvidia/nv-kernel.o
${_LD} -r -o nvidia-modeset.o nvidia-modeset/nv-modeset-interface.o nvidia-modeset/nv-modeset-kernel.o

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

DEST_PATH="${DESTDIR}/usr/lib/nvidia/${NAME}-${VERSION}/$KVER"
# Copy needed files
install -d ${DEST_PATH}
# Copy .ko files for signing service only! They sould not be shipped publicly
install -m 644 *.ko ${DEST_PATH}

# driver
install nvidia.mod.o ${DEST_PATH}
install -d ${DEST_PATH}/nvidia
install nvidia/nv-interface.o ${DEST_PATH}/nvidia/
if [ -f nvidia/nv-kernel-amd64.o_binary ]
then
	install nvidia/nv-kernel-amd64.o_binary ${DEST_PATH}/nvidia/nv-kernel.o
elif [ -f nvidia/nv-kernel.o ]
then
	install nvidia/nv-kernel.o ${DEST_PATH}/nvidia/nv-kernel.o
else
	echo "Did not find a version of nvidia/nv-kernel.o or nvidia/nv-kernel-amd64.o_binary"
	exit 1
fi

# uvm
install nvidia-uvm.mod.o ${DEST_PATH}
install -d ${DEST_PATH}/nvidia-uvm
install nvidia-uvm.o ${DEST_PATH}/nvidia-uvm/

# modeset
install nvidia-modeset.mod.o ${DEST_PATH}
install -d ${DEST_PATH}/nvidia-modeset
install nvidia-modeset/nv-modeset-interface.o ${DEST_PATH}/nvidia-modeset/
install nvidia-modeset/nv-modeset-kernel.o ${DEST_PATH}/nvidia-modeset/

# drm
install nvidia-drm.mod.o ${DEST_PATH}
install -d ${DEST_PATH}/nvidia-drm
install nvidia-drm.o ${DEST_PATH}/nvidia-drm/

# Copy linker and module.lds, we need the exact version to make this work.
install -m 755 ${_LD} ${DEST_PATH}
install -m 755 "/usr/src/linux-headers-${KVER}/arch/x86/module.lds" ${DEST_PATH}
