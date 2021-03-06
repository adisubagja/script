#!/bin/bash
#==================================================================================================================================
# https://github.com/ophub/amlogic-s9xxx-openwrt
# Description: Extract/Replace the kernel for Amlogic S9xxx OpenWrt and Armbian
#
# When the kernel version is upgraded from 5.10 or lower to 5.10 or higher, need to install U-BOOT.
# When there is no U-BOOT file in related directory, the script will auto try to download the file from the server for completion:
# UBOOT_OVERLOAD: https://github.com/ophub/amlogic-s9xxx-openwrt/tree/main/amlogic-s9xxx/amlogic-u-boot"
# MAINLINE_UBOOT: https://github.com/ophub/amlogic-s9xxx-openwrt/tree/main/amlogic-s9xxx/common-files/files/lib/u-boot
#
# Copyright (C) 2020-2021 Flippy
# Copyright (C) 2020-2021 https://github.com/ophub/amlogic-s9xxx-openwrt
#==================================================================================================================================

# Encountered a serious error, abort the script execution
die() {
    echo -e " [Error] ${1}"
    exit 1
}

replace_kernel() {

    echo -e "Start update the openwrt kernel."
    # Operation environment check
    EMMC_NAME=$(lsblk | grep -oE '(mmcblk[0-9])' | sort | uniq)
    P4_PATH="${PWD}"

    # Confirm SOC type from armbian, Openwrt already has this config file by default
    if [[ ! -f "/etc/flippy-openwrt-release" ]]; then
        echo  "The supported SOC types are: s905x3  s905x2  s905x  s905d  s912  s922x"
        echo  "Please enter the SOC type of your device, such as s905x3: "
        read  AMLOGIC_SOC
        echo "SOC='${AMLOGIC_SOC}'" > /etc/flippy-openwrt-release 2>/dev/null
        sync
    fi

    # Download 3 kernel files
    if  [ $( ls ${P4_PATH}/*.tar.gz -l 2>/dev/null | grep "^-" | wc -l ) -ne 3 ]; then

        SERVER_KERNEL_URL="https://api.github.com/repos/ophub/amlogic-s9xxx-openwrt/contents/amlogic-s9xxx/amlogic-kernel"
        echo  "Please enter the kernel version number, such as 5.13.2: "
        read  KERNEL_NUM
        echo -e "Kernel version: ${KERNEL_NUM}"
        echo -e "Start downloading the kernel from github.com ..."

        # Delete tmp files
        rm -f ${P4_PATH}/dtb-amlogic-*.tar.gz ${P4_PATH}/boot-*.tar.gz ${P4_PATH}/modules-*.tar.gz 2>/dev/null
        sync

        # Download boot file
        SERVER_KERNEL_BOOT="$(curl -s "${SERVER_KERNEL_URL}/${KERNEL_NUM}" | grep "download_url" | grep -o "https.*/boot-.*.tar.gz" | head -n 1)"
        SERVER_KERNEL_BOOT_NAME="${SERVER_KERNEL_BOOT##*/}"
        SERVER_KERNEL_BOOT_NAME="${SERVER_KERNEL_BOOT_NAME//%2B/+}"
        wget -c "${SERVER_KERNEL_BOOT}" -O "${P4_PATH}/${SERVER_KERNEL_BOOT_NAME}" >/dev/null 2>&1 && sync
        if [[ "$?" -eq "0" ]]; then
            echo -e "01.01 The boot file download complete."
        else
            die "01.01 The boot file failed to download."
        fi

        # Download dtb file
        SERVER_KERNEL_DTB="$(curl -s "${SERVER_KERNEL_URL}/${KERNEL_NUM}" | grep "download_url" | grep -o "https.*/dtb-amlogic-.*.tar.gz" | head -n 1)"
        SERVER_KERNEL_DTB_NAME="${SERVER_KERNEL_DTB##*/}"
        SERVER_KERNEL_DTB_NAME="${SERVER_KERNEL_DTB_NAME//%2B/+}"
        wget -c "${SERVER_KERNEL_DTB}" -O "${P4_PATH}/${SERVER_KERNEL_DTB_NAME}" >/dev/null 2>&1 && sync
        if [[ "$?" -eq "0" ]]; then
            echo -e "01.02 The dtb file download complete."
        else
            die "01.02 The dtb file failed to download."
        fi

        # Download modules file
        SERVER_KERNEL_MODULES="$(curl -s "${SERVER_KERNEL_URL}/${KERNEL_NUM}" | grep "download_url" | grep -o "https.*/modules-.*.tar.gz" | head -n 1)"
        SERVER_KERNEL_MODULES_NAME="${SERVER_KERNEL_MODULES##*/}"
        SERVER_KERNEL_MODULES_NAME="${SERVER_KERNEL_MODULES_NAME//%2B/+}"
        wget -c "${SERVER_KERNEL_MODULES}" -O "${P4_PATH}/${SERVER_KERNEL_MODULES_NAME}" >/dev/null 2>&1 && sync
        if [[ "$?" -eq "0" ]]; then
            echo -e "01.03 The modules file download complete."
        else
            die "01.03 The modules file failed to download."
        fi

        sync
    fi

    if  [ $( ls ${P4_PATH}/*.tar.gz -l 2>/dev/null | grep "^-" | wc -l ) -ge 3 ]; then

        if  [ $( ls ${P4_PATH}/boot-*.tar.gz -l 2>/dev/null | grep "^-" | wc -l ) -ge 1 ]; then
            build_boot=$( ls ${P4_PATH}/boot-*.tar.gz | head -n 1 ) && build_boot=${build_boot##*/}
            echo -e "Update using [ ${build_boot} ] files. Please wait a moment ..."
            flippy_version=${build_boot/boot-/} && flippy_version=${flippy_version/.tar.gz/}
            kernel_version=$(echo ${flippy_version} | grep -oE '^[1-9].[0-9]{1,2}.[0-9]+')
            kernel_vermaj=$(echo ${kernel_version} | grep -oE '^[1-9].[0-9]{1,2}')
            k510_ver=${kernel_vermaj%%.*}
            k510_maj=${kernel_vermaj##*.}
            if  [ ${k510_ver} -eq "5" ]; then
                if  [ "${k510_maj}" -ge "10" ]; then
                    K510=1
                else
                    K510=0
                fi
            elif [ ${k510_ver} -gt "5" ]; then
                K510=1
            else
                K510=0
            fi
        else
            die "Have no boot-*.tar.gz file found in the ${P4_PATH} directory."
        fi

        if  [ -f ${P4_PATH}/dtb-amlogic-${flippy_version}.tar.gz ]; then
            build_dtb="dtb-amlogic-${flippy_version}.tar.gz"
        else
            die "Have no dtb-amlogic-*.tar.gz file found in the ${P4_PATH} directory."
        fi

        if  [ -f ${P4_PATH}/modules-${flippy_version}.tar.gz ]; then
            build_modules="modules-${flippy_version}.tar.gz"
        else
            die "Have no modules-*.tar.gz file found in the ${P4_PATH} directory."
        fi

        echo -e " \
        Try to using this files to update the kernel: \n \
        boot: ${build_boot} \n \
        dtb: ${build_dtb} \n \
        modules: ${build_modules} \n \
        flippy_version: ${flippy_version} \n \
        kernel_version: ${kernel_version} \n \
        K510: ${K510}"

    else
        echo -e "Please upload the kernel files to [ ${P4_PATH} ], then run [ $0 ] again."
        exit 1
    fi

    MODULES_OLD=$(ls /lib/modules/ 2>/dev/null)
    VERSION_OLD=$(echo ${MODULES_OLD} | grep -oE '^[1-9].[0-9]{1,2}' 2>/dev/null)
    VERSION_ver=${VERSION_OLD%%.*}
    VERSION_maj=${VERSION_OLD##*.}
    if  [ ${VERSION_ver} -eq "5" ]; then
        if  [ "${VERSION_maj}" -ge "10" ]; then
            V510=1
        else
            V510=0
        fi
    elif [ ${VERSION_ver} -gt "5" ]; then
        V510=1
    else
        V510=0
    fi

    # Check version consistency
    if [ "${V510}" -lt "${K510}" ]; then
        echo -e "Update to kernel 5.10 or higher and install U-BOOT."
        if [ -f "/etc/flippy-openwrt-release" ]; then
            # U-BOOT adaptation
            source /etc/flippy-openwrt-release 2>/dev/null
            SOC=${SOC}
            [ -n "${SOC}" ] || die "Unknown SOC, unable to update."
            case ${SOC} in
                s905x3) UBOOT_OVERLOAD="u-boot-x96maxplus.bin"
                        MAINLINE_UBOOT="/lib/u-boot/x96maxplus-u-boot.bin.sd.bin" ;;
                s905x2) UBOOT_OVERLOAD="u-boot-x96max.bin"
                        MAINLINE_UBOOT="/lib/u-boot/x96max-u-boot.bin.sd.bin" ;;
                s905x)  UBOOT_OVERLOAD="u-boot-p212.bin"
                        MAINLINE_UBOOT="" ;;
                s905d)  UBOOT_OVERLOAD="u-boot-n1.bin"
                        MAINLINE_UBOOT="" ;;
                s912)   UBOOT_OVERLOAD="u-boot-zyxq.bin"
                        MAINLINE_UBOOT="" ;;
                s922x)  UBOOT_OVERLOAD="u-boot-gtkingpro.bin"
                        MAINLINE_UBOOT="/lib/u-boot/gtkingpro-u-boot.bin.sd.bin" ;;
                *)      die "Unknown SOC, unable to update to kernel 5.10 and above." ;;
            esac

            GITHUB_RAW="https://raw.githubusercontent.com/ophub/amlogic-s9xxx-openwrt/main/amlogic-s9xxx"

            # Check ${UBOOT_OVERLOAD}
            if [[ -n "${UBOOT_OVERLOAD}" ]]; then
                if [[ ! -s "/boot/${UBOOT_OVERLOAD}" ]]; then
                    echo -e "Try to download the ${UBOOT_OVERLOAD} file from the server."
                    GITHUB_UBOOT_OVERLOAD="${GITHUB_RAW}/amlogic-u-boot/${UBOOT_OVERLOAD}"
                    #echo -e "UBOOT_OVERLOAD: ${GITHUB_UBOOT_OVERLOAD}"
                    wget -c "${GITHUB_UBOOT_OVERLOAD}" -O "/boot/${UBOOT_OVERLOAD}" >/dev/null 2>&1 && sync
                    if [[ "$?" -eq "0" && -s "/boot/${UBOOT_OVERLOAD}" ]]; then
                        echo -e "The ${UBOOT_OVERLOAD} file download is complete."
                    else
                        die "The ${UBOOT_OVERLOAD} file download failed. please try again."
                    fi
                else
                    echo -e "The ${UBOOT_OVERLOAD} file has been found."
                fi
            else
                die "The 5.10 kernel cannot be used without UBOOT_OVERLOAD."
            fi

            # Check ${MAINLINE_UBOOT}
            if [[ -n "${MAINLINE_UBOOT}" ]]; then
                if [[ ! -s "${MAINLINE_UBOOT}" ]]; then
                    echo -e "Try to download the MAINLINE_UBOOT file from the server."
                    GITHUB_MAINLINE_UBOOT="${GITHUB_RAW}/common-files/files${MAINLINE_UBOOT}"
                    #echo -e "MAINLINE_UBOOT: ${GITHUB_MAINLINE_UBOOT}"
                    [ -d "/lib/u-boot" ] || mkdir -p /lib/u-boot
                    wget -c "${GITHUB_MAINLINE_UBOOT}" -O "${MAINLINE_UBOOT}" >/dev/null 2>&1 && sync
                    if [[ "$?" -eq "0" && -s "${MAINLINE_UBOOT}" ]]; then
                        echo -e "The MAINLINE_UBOOT file download is complete."
                    else
                        die "The MAINLINE_UBOOT file download failed. please try again."
                    fi
                fi
            fi
        else
            die "The /etc/flippy-openwrt-release file is missing and cannot be update."
        fi

        # Copy u-boot.ext and u-boot.emmc
        if [ -f "/boot/${UBOOT_OVERLOAD}" ]; then
            cp -f "/boot/${UBOOT_OVERLOAD}" /boot/u-boot.ext && sync && chmod +x /boot/u-boot.ext
            cp -f "/boot/${UBOOT_OVERLOAD}" /boot/u-boot.emmc && sync && chmod +x /boot/u-boot.emmc
            echo -e "The ${UBOOT_OVERLOAD} file copy is complete."
        else
            die "The UBOOT_OVERLOAD file is missing and cannot be update."
        fi

        # Write Mainline bootloader
        if [ -f "${MAINLINE_UBOOT}" ]; then
            echo -e "Write Mainline bootloader: [ ${MAINLINE_UBOOT} ] to [ /dev/${EMMC_NAME} ]"
            dd if=${MAINLINE_UBOOT} of=/dev/${EMMC_NAME} bs=1 count=442 conv=fsync
            dd if=${MAINLINE_UBOOT} of=/dev/${EMMC_NAME} bs=512 skip=1 seek=1 conv=fsync
            echo -e "The MAINLINE_UBOOT file write is complete."
        fi
    fi

    echo -e "Unpack [ ${flippy_version} ] related files ..."

    # 01. for /boot five files
    rm -f /boot/uInitrd /boot/zImage /boot/config-* /boot/initrd.img-* /boot/System.map-* 2>/dev/null && sync
    tar -xzf ${P4_PATH}/${build_boot} -C /boot && sync

    if [[ -f "/boot/uInitrd-${flippy_version}" ]]; then
        i=1
        max_try=10
        while [ "${i}" -le "${max_try}" ]; do
            cp -f /boot/uInitrd-${flippy_version} /boot/uInitrd 2>/dev/null && sync
            uInitrd_original=$(md5sum /boot/uInitrd-${flippy_version} | awk '{print $1}')
            uInitrd_new=$(md5sum /boot/uInitrd | awk '{print $1}')
            if [ "${uInitrd_original}" = "${uInitrd_new}" ]; then
                rm -f /boot/uInitrd-${flippy_version} && sync
                break
            else
                rm -f /boot/uInitrd && sync
                let i++
                continue
            fi
        done
        [ "${i}" -eq "10" ] && die "/boot/uInitrd-${flippy_version} file copy failed."
    else
        die "/boot/uInitrd-${flippy_version} file is missing."
    fi

    if [[ -f "/boot/vmlinuz-${flippy_version}" ]]; then
        i=1
        max_try=10
        while [ "${i}" -le "${max_try}" ]; do
            cp -f /boot/vmlinuz-${flippy_version} /boot/zImage 2>/dev/null && sync
            vmlinuz_original=$(md5sum /boot/vmlinuz-${flippy_version} | awk '{print $1}')
            vmlinuz_new=$(md5sum /boot/zImage | awk '{print $1}')
            if [ "${vmlinuz_original}" = "${vmlinuz_new}" ]; then
                rm -f /boot/vmlinuz-${flippy_version} && sync
                break
            else
                rm -f /boot/zImage && sync
                let i++
                continue
            fi
        done
        [ "${i}" -eq "10" ] && die "/boot/vmlinuz-${flippy_version} file copy failed."
    else
        die "/boot/vmlinuz-${flippy_version} file is missing."
    fi

    [ -f "/boot/config-${flippy_version}" ] || die "/boot/config-${flippy_version} file is missing."
    [ -f "/boot/System.map-${flippy_version}" ] || die "/boot/System.map-${flippy_version} file is missing."

    echo -e "02.01 Unpack [ ${build_boot} ] complete."
    sleep 3

    # 02 for /boot/dtb/amlogic/*
    tar -xzf ${P4_PATH}/${build_dtb} -C /boot/dtb/amlogic && sync
    [ "$( ls /boot/dtb/amlogic -l 2>/dev/null | grep "^-" | wc -l )" -ge "10" ] || die "/boot/dtb/amlogic file is missing."
    echo -e "02.02 Unpack [ ${build_dtb} ] complete."
    sleep 3

    # 03 for /lib/modules/*
    rm -rf /lib/modules/* 2>/dev/null && sync
    tar -xzf ${P4_PATH}/${build_modules} -C /lib/modules && sync
        cd /lib/modules/${flippy_version}/
        rm -f *.ko 2>/dev/null
        find ./ -type f -name '*.ko' -exec ln -s {} ./ \;
        sync && sleep 3
            x=$( ls *.ko -l 2>/dev/null | grep "^l" | wc -l )
            if [ "${x}" -eq "0" ]; then
                die "Error *.ko Files not found."
            fi
    echo -e "02.03 Unpack [ ${build_modules} ] complete."
    sleep 3

    rm -f ${P4_PATH}/dtb-amlogic-*.tar.gz ${P4_PATH}/boot-*.tar.gz ${P4_PATH}/modules-*.tar.gz 2>/dev/null
    sync

    sed -i '/KERNEL_VERSION/d' /etc/flippy-openwrt-release 2>/dev/null
    echo "KERNEL_VERSION='${kernel_version}'" >> /etc/flippy-openwrt-release 2>/dev/null

    sed -i '/K510/d' /etc/flippy-openwrt-release 2>/dev/null
    echo "K510='${K510}'" >> /etc/flippy-openwrt-release 2>/dev/null

    sed -i "s/ Kernel.*/ Kernel: ${flippy_version}/g" /etc/banner 2>/dev/null

    sync
    wait

    echo "The update is complete, Will start automatically, please refresh later!"
    sleep 3
    echo 'b' > /proc/sysrq-trigger
    exit 0
}

replace_kernel

