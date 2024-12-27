#!/bin/bash

tag="default"

run_ohos=1

error_exit() {
  echo "$1" 1>&2
  exit 1
}

parse_args() {
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --tag)
        tag="$2"
        shift 2
        ;;
      --ohos)
        run_ohos=0
        shift
        ;;
      *)
        error_exit "Invalid option: $1"
        ;;
    esac
  done
}

build_package() {
  parse_args "$@"
  export tag=$tag
  echo "Building build_package tag:${tag}..."
  sh ./build/ohos_release/build.sh || error_exit "build_package failed!"
  echo "build_package succeeded!"
}

build_and_test() {
  parse_args "$@"
  export run_ohos=$run_ohos
  echo "Building and running build_and_test ..."
  sh ./build/build_and_test/build.sh || error_exit "build_and_test failed!"
  echo "build_and_test succeeded!"
}


# check args
if [ "$#" -lt 1 ]; then
  error_exit "Usage: $0 <command> [--tag <tag>] [--ohos]"
fi

if [ -d "$TOOLS_INSTALL_DIR/go" ]; then
  export GOROOT="$TOOLS_INSTALL_DIR/go"
  export PATH="$GOROOT/bin:$PATH"
fi

COMMAND="$1"
shift
case "$COMMAND" in
  build-package)
    build_package "$@"
    ;;
  build-and-test)
    build_and_test "$@"
    ;;
  *)
    error_exit "Invalid command: $COMMAND"
    ;;
esac