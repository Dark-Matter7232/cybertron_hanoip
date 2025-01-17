#!/bin/bash

# Initialize variables

BOLD='\033[1m'
GRN='\033[01;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[01;31m'
RST='\033[0m'
ORIGIN_DIR=$(pwd)
BUILD_PREF_COMPILER='clang'
BUILD_PREF_COMPILER_VERSION='proton'
TOOLCHAIN=$(pwd)/build-shit/toolchain
IMAGE=$(pwd)/out/arch/arm64/boot/Image.gz
# export environment variables
export_env_vars() {
    export KBUILD_BUILD_USER=Const
    export KBUILD_BUILD_HOST=Coccinelle

	export ARCH=arm64
	export SUBARCH=arm64
	export HEADER_ARCH=arm64
    export CROSS_COMPILE=aarch64-linux-gnu-
    export CROSS_COMPILE_ARM32=arm-linux-gnueabi-

    # CCACHE
    export USE_CCACHE=1
    export PATH="/usr/lib/ccache/bin/:$PATH"
    export CCACHE_SLOPPINESS="file_macro,locale,time_macros"
    export CCACHE_NOHASHDIR="true"
    export CC=${BUILD_PREF_COMPILER}
}

script_echo() {
    echo "  $1"
}
exit_script() {
    kill -INT $$
}
add_deps() {
    echo -e "${CYAN}"
    if [ ! -d $(pwd)/build-shit ]
    then
        script_echo "Create build-shit folder"
        mkdir $(pwd)/build-shit
    fi

    if [ ! -d $(pwd)/build-shit/toolchain ]
    then
        script_echo "Downloading proton-clang...."
        cd build-shit
        script_echo $(wget -q https://github.com/kdrag0n/proton-clang/archive/refs/tags/20201212.tar.gz -O clang.tar.gz);
        bsdtar xf clang.tar.gz
        rm -rf clang.tar.gz
        mv proton-clang* toolchain
        cd ../
    fi
    verify_toolchain_install
}
verify_toolchain_install() {
    script_echo " "
    if [[ -d "${TOOLCHAIN}" ]]; then
        script_echo "I: Toolchain found at default location"
        export PATH="${TOOLCHAIN}/bin:$PATH"
        export LD_LIBRARY_PATH="${TOOLCHAIN}/lib:$LD_LIBRARY_PATH"
    else
        script_echo "I: Toolchain not found"
        script_echo "   Downloading recommended toolchain at ${TOOLCHAIN}..."
        add_deps
    fi
}
build_kernel_image() {
    cleanup
    script_echo " "
    echo -e "${GRN}"
    read -p "Write the Kernel version: " KV
    echo -e "${YELLOW}"
    script_echo 'Building CosmicFresh Kernel For M21'
    make -C $(pwd) CC=${BUILD_PREF_COMPILER} AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip -j$((`nproc`+1)) LOCALVERSION="—CosmicFresh-R$KV-hanoip" vendor/hanoip_defconfig 2>&1 | sed 's/^/     /'
    make -C $(pwd) CC=${BUILD_PREF_COMPILER} AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip -j$((`nproc`+1)) LOCALVERSION="—CosmicFresh-R$KV-hanoip" 2>&1 | sed 's/^/     /'
    SUCCESS=$?
    echo -e "${RST}"

    if [ $SUCCESS -eq 0 ] && [ -f "$IMAGE" ]
    then
        echo -e "${GRN}"
        script_echo "------------------------------------------------------------"
        script_echo "Compilation successful..."
        script_echo "Image can be found at out/arch/arm64/boot/Image.gz"
        script_echo  "------------------------------------------------------------"
        build_flashable_zip
    elif [ $SUCCESS -eq 130 ]
    then
        echo -e "${RED}"
        script_echo "------------------------------------------------------------"
        script_echo "Build force stopped by the user."
        script_echo "------------------------------------------------------------"
        echo -e "${RST}"
    elif [ $SUCCESS -eq 1 ]
    then
        echo -e "${RED}"
        script_echo "------------------------------------------------------------"
        script_echo "Compilation failed..check build logs for errors"
        script_echo "------------------------------------------------------------"
        echo -e "${RST}"
        cleanup
    fi
}
build_flashable_zip() {
    script_echo " "
    script_echo "I: Building kernel image..."
    echo -e "${GRN}"
    cp $(pwd)/out/arch/arm64/boot/{Image.gz,dtbo.img} CosmicFresh/
	cp $(pwd)/out/arch/arm64/boot/dts/qcom/sdmmagpie-hanoi-base.dtb CosmicFresh/dtb
		which avbtool &>/dev/null && python3 `which avbtool` add_hash_footer \
		--partition_name dtbo \
		--partition_size $((32 * 1024 * 1024)) \
		--image $(pwd)/CosmicFresh/dtbo.img
    cd $(pwd)/CosmicFresh/
    zip -r9 "CosmicFresh-R$KV-hanoip.zip" anykernel.sh META-INF tools Image.gz dtb dtbo.img
    rm -rf {Image.gz,dtb,dtbo.img}
    cd ../
}

cleanup() {
    cd $(pwd)/CosmicFresh/
    rm -rf {Image.gz,*.zip,dtb,dtbo.img}
    cd ../
    rm -rf $(pwd)/out/arch/arm64/boot/*
}
add_deps
export_env_vars
build_kernel_image