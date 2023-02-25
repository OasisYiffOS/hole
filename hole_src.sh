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

# now, we will simply run the hole_inner.sh script inside the container
"$I_PREFER" run --rm -it -v "$PWD":/input hole_container_donotremove:latest /factory/hole_inner.sh "$@"