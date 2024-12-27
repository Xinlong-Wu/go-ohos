#!/bin/bash

TOOLS_DOWNLOAD_DIR=commandline-tools
if [ ! -d "${TOOLS_DOWNLOAD_DIR}" ]; then
    mkdir "${TOOLS_DOWNLOAD_DIR}"
    echo "Directory '${TOOLS_DOWNLOAD_DIR}' created."
fi

if [ ! -d "${TOOLS_INSTALL_DIR}" ]; then
    mkdir -p "${TOOLS_INSTALL_DIR}"
    echo "Directory '${TOOLS_INSTALL_DIR}' created."
fi

cd "${TOOLS_DOWNLOAD_DIR}"
[ -d "$TOOLS_INSTALL_DIR"/command-line-tools ] && rm -rf "${TOOLS_INSTALL_DIR}"/command-line-tools
echo "curl -s -o commandline-tools-linux.zip ${COMMANDLINE_TOOLS_URL}"
curl -k -s -o commandline-tools-linux.zip "${COMMANDLINE_TOOLS_URL}"
unzip commandline-tools-linux.zip -d "${TOOLS_INSTALL_DIR}"