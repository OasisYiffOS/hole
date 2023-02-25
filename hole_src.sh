#!/usr/bin/env bash

I_PREFER="podman"

# if podman isn't installed, change to docker
if ! command -v "$I_PREFER" &>/dev/null; then
  I_PREFER="docker"

  # if docker isn't installed, error out
  if ! command -v "$I_PREFER" &>/dev/null; then
    echo "error: neither podman nor docker are installed! a container system is required for using hole!"
    exit 1
  fi
fi

function install() {
  # if the -i flag was passed, we will install the package that was built
  # make sure that there's a PKGSCRIPT in this directory
  if [ ! -f PKGSCRIPT ]; then
    echo "error: no PKGSCRIPT found in current directory, cannot install package!"
    exit 1
  fi
  # source the PKGSCRIPT
  . PKGSCRIPT

  # copied from sheath
  bulge li "${NAME}-${VERSION}-${EPOCH}.tar.xz"
}

DO_INSTALL=0

while getopts ":i" opt; do
    case $opt in
        i)
          DO_INSTALL=1
          ;;
        \?)
          ;;
    esac
done

# if the only argument is -i, we will just install
if [ "$DO_INSTALL" = "1" ] && [ "$#" -eq 1 ]; then
  install
  exit 0
fi

# now, we will simply run the hole_inner.sh script inside the container
# if PKG_CACHE is set, we will mount it to /pkg_cache and set the PKG_CACHE environment variable to /pkg_cache
if [ -z "$PKG_CACHE" ]; then
  "$I_PREFER" run --rm -it -v "$PWD":/input hole_container_donotremove:latest /factory/hole_inner.sh "$@"
else
  PKG_CACHE=$(realpath "$PKG_CACHE")
  "$I_PREFER" run --rm -it -v "$PWD":/input -v "$PKG_CACHE":/pkg_cache -e PKG_CACHE=/pkg_cache hole_container_donotremove:latest /factory/hole_inner.sh "$@"
fi

if [ "$DO_INSTALL" = "1" ]; then
  install
fi