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

DO_TESTING=0

while getopts ":t" opt; do
    case $opt in
        t)
          DO_TESTING=1
          ;;
        \?)
          ;;
    esac
done

# now, we will simply run the hole_inner.sh script inside the container
# if PKG_CACHE is set, we will mount it to /pkg_cache and set the PKG_CACHE environment variable to /pkg_cache
if [ -z "$PKG_CACHE" ]; then
  "$I_PREFER" run --rm -it -v "$PWD":/input hole_container_donotremove:latest /factory/hole_inner.sh "$@"
else
  PKG_CACHE=$(realpath "$PKG_CACHE")
  "$I_PREFER" run --rm -it -v "$PWD":/input -v "$PKG_CACHE":/pkg_cache -e PKG_CACHE=/pkg_cache hole_container_donotremove:latest /factory/hole_inner.sh "$@"
fi