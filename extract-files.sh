#!/bin/bash
#
# Copyright (C) 2016 The CyanogenMod Project
# Copyright (C) 2017-2020 The LineageOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

ONLY_COMMON=
ONLY_TARGET=
KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        --only-common )
                ONLY_COMMON=true
                ;;
        --only-target )
                ONLY_TARGET=true
                ;;
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
     case "${1}" in
         vendor/lib/libmeson_display_adapter_remote.so)
             "${PATCHELF}" --remove-needed "libhidltransport.so" "${2}"
             "${PATCHELF}" --remove-needed "libhwbinder.so" "${2}"
             ;;
         vendor/lib/libmeson_display_service.so)
             "${PATCHELF}" --remove-needed "libhidltransport.so" "${2}"
             "${PATCHELF}" --remove-needed "libhwbinder.so" "${2}"
             ;;
        vendor/lib/hw/android.hardware.graphics.mapper@3.0-impl-arm.so)
             "${PATCHELF}" --remove-needed "libhidltransport.so" "${2}"
             ;;
        vendor/lib/hw/android.hardware.graphics.allocator@3.0-impl-arm.so)
             "${PATCHELF}" --remove-needed "libhidltransport.so" "${2}"
             ;;
        vendor/bin/hw/android.hardware.graphics.allocator@3.0-service)
             "${PATCHELF}" --remove-needed "libhidltransport.so" "${2}"
             ;;
        vendor/etc/init/fs.rc)
             sed -i '/media 0770 media_rw media_rw/d' "${2}"
             ;;
        vendor/etc/init/tee-supplicant.rc)
             sed -i s#/vendor/lib/#/vendor/lib/modules/#g "${2}"
             ;;
        vendor/etc/wifi/wpa_supplicant_overlay.conf)
             echo "driver_param=use_p2p_group_interface=1">>"${2}"
             ;;
     esac
 }

if [ -z "${ONLY_TARGET}" ]; then
    # Initialize the helper for common device
    setup_vendor "${DEVICE_COMMON}" "${VENDOR_COMMON}" "${ANDROID_ROOT}" true "${CLEAN_VENDOR}"

    extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
    extract "${MY_DIR}/proprietary-files-tee.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

if [ -z "${ONLY_COMMON}" ] && [ -s "${MY_DIR}/../../${VENDOR_DEVICE}/${DEVICE}/proprietary-files.txt" ]; then
    # Reinitialize the helper for device
    source "${MY_DIR}/../../${VENDOR_DEVICE}/${DEVICE}/extract-files.sh"
    setup_vendor "${DEVICE}" "${VENDOR_DEVICE}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

    extract "${MY_DIR}/../../${VENDOR_DEVICE}/${DEVICE}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"
fi

"${MY_DIR}/setup-makefiles.sh"
