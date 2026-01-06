#!/bin/bash

go env
go version

# clean cache
go clean -cache
go clean -testcache

cd src

sed -i "s?unset GOFLAGS?unset GOFLAGS\nexport GOFLAGS=-trimpath?" make.bash #add -trimpath

bash -x ./make.bash -v

if [ $? -ne 0 ]; then
    echo "failed"
    exit 2
else
    echo "succeed"
fi

cd ..

if [ -z "$tag" ]; then
  tag="default"
fi

# package
archtype=$(uname -m | grep x86)
if [[ "$archtype" == "" ]]
then
    packageName="$tag-arm64.tar.gz"
else
    packageName="$tag-amd64.tar.gz"
fi

echo "packageName=$packageName"

if [ -d "$tag" ]; then
    rm -rf "$tag"
fi
mkdir $tag
cp -r * $tag/

tar -czf $packageName $tag --exclude=".git" --exclude="pkg/obj" --exclude="build"

shasum=$(sha256sum $packageName)
echo "SHA256 Checksum： $shasum"

echo "package done."

mkdir target
mv $packageName target/
cd target
ls