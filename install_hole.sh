#!/usr/bin/env bash
### hole - containerised yiffOS build system based on sheath
### usage is currently the same as sheath, and will likely remain compatible
### hole is unofficial! use at your own risk!

WORKING_DIR=$(realpath "$(dirname "$0")")
if [ -z "$WORKING_DIR" ]; then
  echo "error: could not determine working directory!"
  exit 1
fi

if [ -z "$INSTALL_PATH" ]; then
  INSTALL_PATH="$WORKING_DIR"
fi

INSTALL_PATH=$(realpath "$INSTALL_PATH")

# check if sheath was cloned; if not, init submodules
if [ ! -d "$WORKING_DIR/sheath" ]; then
  echo "warning: sheath not found in working directory, initialising submodules"
  git submodule update --init --recursive
fi

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

# build the container
echo "building hole container..."
cd "$WORKING_DIR" || exit
"$I_PREFER" build -t hole_container_donotremove:latest .

# copy the hole_src.sh script to the install path as `hole` and chmod +x it
echo "copying hole_src.sh to $INSTALL_PATH/hole"
cp "$WORKING_DIR/hole_src.sh" "$INSTALL_PATH/hole"

# make sure the hole script is executable
chmod +x "$INSTALL_PATH/hole"

echo "hole installed! you can now run hole from $INSTALL_PATH/hole"
echo "you may want to add $INSTALL_PATH to your PATH variable so you can run hole from anywhere!"