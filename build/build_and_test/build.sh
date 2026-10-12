#!/bin/bash

go env
go version

# clean cache
go clean -cache
go clean -testcache

cd src

umask 0022

run_command() {
    local command_name=$1
    local command=$2

    echo "$command"
    bash -c "$command"
    local ret=$?

    if [ $ret -ne 0 ]; then
        echo "$command_name failed..."
        return 1
    else
        echo "$command_name succeed..."
        return 0
    fi
}

# build
bash ./all.bash -v
x86_build_test_result=$?
if [ $x86_build_test_result -ne 0 ]; then
    echo "x86_build_test failed..."
    exit 1
else
    echo "x86_build_test succeed..."
fi

parent_dir=$(dirname "$(pwd)")
export GOROOT=$parent_dir
export PATH=$parent_dir/bin:$PATH
go env
# x86 purego_test：
echo "linux-x86 purego_test:"
run_command "linux-x86 purego_test" "CGO_ENABLED='0' ../bin/go tool dist test -compile-only $@ 2>&1"
x86_purego_result=$?

# x86 cgo_test
echo "linux-x86 cgo_test:"
run_command "linux-x86 cgo_test" "CGO_ENABLED='1' ../bin/go tool dist test -compile-only $@ 2>&1"
x86_cgo_result=$?

# arm64 purego_test：
echo "linux-arm64 purego_test:"
run_command "linux-arm64 purego_test" "CGO_ENABLED='0' GOOS=linux GOARCH=arm64 ../bin/go tool dist test -compile-only $@ 2>&1"
arm64_purego_result=$?

# check result
if [ $x86_purego_result -ne 0 ] || [ $x86_cgo_result -ne 0 ] || [ $arm64_purego_result -ne 0 ]; then
    echo "test is failed, please check log 'failed...'"
    exit 2
fi

# openharmony：
if [ "${run_ohos}" -eq 0 ]; then
    export GOOS=openharmony
    export GOARCH=arm64
    export CC=${COMMANDLINE_TOOLS_PATH}/aarch64-unknown-linux-ohos-clang
    export CXX=${COMMANDLINE_TOOLS_PATH}/aarch64-unknown-linux-ohos-clang++

    # openharmony purego_test：
    echo "openharmony purego_test:"
    run_command "openharmony purego_test" "CGO_ENABLED='0' GOOS=openharmony GOARCH=arm64 ../bin/go tool dist test -compile-only $@ 2>&1"
    openharmony_purego_result=$?

    # openharmony cgo_test：
    echo "openharmony cgo_test:"
    run_command "openharmony cgo_test" "CGO_ENABLED='1' GOOS=openharmony GOARCH=arm64 ../bin/go tool dist test -compile-only $@ 2>&1"
    openharmony_cgo_result=$?
    if [ $openharmony_purego_result -ne 0 ] || [ $openharmony_cgo_result -ne 0 ]; then
        echo "test is failed, please check log 'failed...'"
        exit 2
    fi
fi