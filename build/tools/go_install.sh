#!/bin/bash

# check go version
REQUIRED_GO_VERSION="go1.20.7"
INSTALLED_GO_VERSION=$(go version 2>/dev/null | awk '{print $3}')

if [ "$INSTALLED_GO_VERSION" \> "$REQUIRED_GO_VERSION" ]; then
    echo "Go version is already installed: $INSTALLED_GO_VERSION"
    go env
    exit 0
fi

echo "Go version $REQUIRED_GO_VERSION is not installed. Installing now..."

if [ ! -d "$TOOLS_INSTALL_DIR" ]; then
    mkdir -p "$TOOLS_INSTALL_DIR"
    echo "Directory '$TOOLS_INSTALL_DIR' created."
fi

[ -d "$TOOLS_INSTALL_DIR"/go ] && rm -rf "$TOOLS_INSTALL_DIR"/go
# download go
curl -k -s -o "$TOOLS_INSTALL_DIR/$GO_TAR_GZ" "$GO_DOWNLOAD_URL"
cd $TOOLS_INSTALL_DIR
tar -xzf "$GO_TAR_GZ"

GOROOT=$TOOLS_INSTALL_DIR/go
$GOROOT/bin/go env
go_version=$($GOROOT/bin/go version 2>/dev/null | awk '{print $3}')
echo "$go_version"

if [ "$go_version" \> "$REQUIRED_GO_VERSION" ]; then
    echo "Go installed successfully."
else
    echo "Failed to install Go. Please check the installation process."
    exit 1
fi
