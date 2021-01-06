#!/bin/sh

set -e

T_HOME_DIR="$HOME/.t.rb"
T_RELEASE="0.1.0"

# make sure the bin path is in place

      [ -n "$PREFIX" ] || PREFIX="/usr/local"
      BIN_PATH="$PREFIX/bin"
      mkdir -p "$BIN_PATH"

# download the release tag and link to the bin path

      mkdir -p "$T_HOME_DIR"
      pushd "$T_HOME_DIR" > /dev/null &&
        rm -rf "t.rb-$T_RELEASE"
        curl -L "https://github.com/redding/t.rb/tarball/$T_RELEASE" | tar xzf - '*/libexec/*'
        mv *-t.rb-* "t.rb-$T_RELEASE"
        ln -sf "t.rb-$T_RELEASE/libexec"
      popd > /dev/null

# install in the bin path

      ln -sf "$T_HOME_DIR/libexec/t.rb" "$BIN_PATH/t"

# done!

      echo "Installed at ${BIN_PATH}/t"
