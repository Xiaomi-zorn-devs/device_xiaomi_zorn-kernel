#!/bin/bash
#
# Copyright (C) 2023 LHNLM OS
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

### Setup
KERNEL_TREE=
MY_DIR="${BASH_SOURCE%/*}"
HEADERS_FILE="${MY_DIR}/kernel-headers.txt"
HEADERS_DIR="${MY_DIR}/kernel-headers"

function usage() {
    echo "Usage: $0 <kernel_tree_path>"
    echo ""
    echo "Extract kernel headers from a kernel tree based on kernel-headers.txt"
    echo ""
    echo "Arguments:"
    echo "  kernel_tree_path    Path to the kernel source tree"
    echo ""
    echo "This script will:"
    echo "  1. Clean the kernel-headers directory (except Makefile)"
    echo "  2. Extract headers listed in kernel-headers.txt from the kernel tree"
    echo "  3. Copy them to kernel-headers/ preserving the directory structure"
}

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -h | --help )
                usage
                exit 0
                ;;
        * )
                KERNEL_TREE="${1}"
                ;;
    esac
    shift
done

# Check if kernel tree is specified and exists
if [ -z "${KERNEL_TREE}" ]; then
    echo "Error: Please specify the kernel tree path!"
    usage
    exit 1
elif [ ! -d "${KERNEL_TREE}" ]; then
    echo "Error: Unable to find kernel tree at ${KERNEL_TREE}!"
    exit 1
fi

# Check if kernel-headers.txt exists
if [ ! -f "${HEADERS_FILE}" ]; then
    echo "Error: ${HEADERS_FILE} not found!"
    exit 1
fi

# Check if kernel-headers directory exists
if [ ! -d "${HEADERS_DIR}" ]; then
    echo "Error: ${HEADERS_DIR} directory not found!"
    exit 1
fi

echo "Extracting kernel headers from ${KERNEL_TREE}:"

### Cleanup kernel-headers directory (preserve Makefile)
echo "Cleaning kernel-headers directory (preserving Makefile)..."
find "${HEADERS_DIR}" -mindepth 1 ! -name "Makefile" -exec rm -rf {} + 2>/dev/null || true

### Extract headers
TOTAL_HEADERS=$(wc -l < "${HEADERS_FILE}")
CURRENT=0
FOUND=0
NOT_FOUND=0

echo "Processing ${TOTAL_HEADERS} headers..."

while IFS= read -r header_path; do
    # Skip empty lines and comments
    [[ -z "${header_path}" || "${header_path}" =~ ^[[:space:]]*# ]] && continue
    
    CURRENT=$((CURRENT + 1))
    
    # Source and destination paths
    SRC_PATH="${KERNEL_TREE}/include/uapi/${header_path}"
    DEST_PATH="${HEADERS_DIR}/${header_path}"
    DEST_DIR=$(dirname "${DEST_PATH}")
    
    if [ -f "${SRC_PATH}" ]; then
        # Create destination directory if it doesn't exist
        mkdir -p "${DEST_DIR}"
        
        # Copy the header file
        cp "${SRC_PATH}" "${DEST_PATH}"
        
        FOUND=$((FOUND + 1))
        printf "  [%3d/%3d] ✓ %s\n" "${CURRENT}" "${TOTAL_HEADERS}" "${header_path}"
    else
        NOT_FOUND=$((NOT_FOUND + 1))
        printf "  [%3d/%3d] ✗ %s (not found)\n" "${CURRENT}" "${TOTAL_HEADERS}" "${header_path}"
    fi
done < "${HEADERS_FILE}"

echo ""
echo "Summary:"
echo "  Total headers processed: ${TOTAL_HEADERS}"
echo "  Successfully copied: ${FOUND}"
echo "  Not found: ${NOT_FOUND}"

if [ "${NOT_FOUND}" -gt 0 ]; then
    echo ""
    echo "Warning: ${NOT_FOUND} header(s) were not found in the kernel tree."
    echo "This might be normal if the kernel version differs or some headers"
    echo "are not available in the specified kernel tree."
fi

echo ""
echo "Kernel headers extraction completed!"
