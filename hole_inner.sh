#!/usr/bin/env bash

EXPORTS=""

# assert that the PKGSCRIPT exists at /input/PKGSCRIPT
INPUT_DIR=/input
if [ ! -f "$INPUT_DIR/PKGSCRIPT" ]; then
  echo "error: PKGSCRIPT not found in input directory!"
  exit 1
fi

# assert that sheath exists at /factory/sheath
SHEATH=/factory/sheath
if [ ! -f "$SHEATH" ]; then
  echo "error: sheath not found in factory directory!"
  exit 1
fi

# assert that bulge is installed
BULGE="$(which bulge)"
if [ -z "$BULGE" ]; then
  echo "error: bulge not found in PATH!"
  exit 1
fi

### runs sheath without getting dependencies
function run_sheath_no_get_deps() {
  cd "$INPUT_DIR" || exit 1
  for export in "${EXPORTS[@]}"; do
    echo "exporting $export to sheath environment"
    export ${export?}
  done
  "$SHEATH" "$@"
}

function install_local_dependency() {
  eval "$(. "$1/PKGSCRIPT";
  echo "NAME=$NAME";
  echo "VERSION=$VERSION";
  echo "EPOCH=$EPOCH";)"
  if [ -f "$1/${NAME}-${VERSION}-${EPOCH}.tar.xz" ]; then
    echo "HOLE: Installing from local cache: $1/${NAME}-${VERSION}-${EPOCH}.tar.xz"
    # install dependencies
    get_deps 0 0 "$1"
    # re-source due to clobbering
    eval "$(. "$1/PKGSCRIPT";
    echo "NAME=$NAME";
    echo "VERSION=$VERSION";
    echo "EPOCH=$EPOCH";)"
    # install the package
    yes | "$BULGE" li "$1/${NAME}-${VERSION}-${EPOCH}.tar.xz" &>/dev/null
    return 0
  else
    return 1
  fi
}

function get_dependency() {
  # fixme: awful hack to prevent overwriting gcc with gcc-libs, this will be fixed in the future
  if [ "$1" = "gcc-libs" ]; then
    echo "HOLE: Refusing to install gcc-libs"
    return
  fi
  # if the package is already installed, don't download it
  if [ -f "/factory/installed_packages" ]; then
    if grep -q "$1" "/factory/installed_packages"; then
      echo "HOLE: $1 is already installed, skipping"
      return
    fi
  fi

  # add the dependency to the list of installed packages
  echo "$1" >> "/factory/installed_packages"

  NEEDS_DOWNLOAD=1
  # if PKG_CACHE is set, check that first
  if [ -n "$PKG_CACHE" ]; then
    if [ -d "$PKG_CACHE/$1" ]; then
      if [ -f "$PKG_CACHE/$1/PKGSCRIPT" ]; then
        PKG_DIR="$PKG_CACHE/$1"
        # check result of install_local_dependency
        if install_local_dependency "$PKG_DIR"; then
          NEEDS_DOWNLOAD=0
        fi
      fi
    fi
  fi

  # otherwise, download it
  if [ "$NEEDS_DOWNLOAD" = "1" ]; then
    echo "HOLE: Downloading dependency $1"
    # if bulge outputs "was not found!" we can assume that a package with that name does not exist
    if yes | "$BULGE" i "$1" | grep -q "was not found!"; then
      echo "HOLE: CRITICAL ERROR! dependency $1 not found!"
      exit 1
    fi
  fi
}

function get_deps() {
  # GET_MAKE_DEPS="$1"
  # GET_OPT_DEPS="$2"
  # PKG_DIR="$3"
  # source the PKGSCRIPT
  eval "$(. "$3/PKGSCRIPT";
  echo "DEPENDS=(${DEPENDS[*]})";
  echo "MK_DEPENDS=(${MK_DEPENDS[*]})";
  echo "OPT_DEPENDS=(${OPT_DEPENDS[*]})";)"

  for dep in "${DEPENDS[@]}"; do
    echo "HOLE: Installing dependency $dep"
    get_dependency "$dep"
  done

  if [ "$1" = "1" ]; then
    # re-source due to clobbering
    eval "$(. "$3/PKGSCRIPT";
    echo "DEPENDS=(${DEPENDS[*]})";
    echo "MK_DEPENDS=(${MK_DEPENDS[*]})";
    echo "OPT_DEPENDS=(${OPT_DEPENDS[*]})";)"
    for mkdep in "${MK_DEPENDS[@]}"; do
      echo "HOLE: Installing build dependency $mkdep"
      get_dependency "$mkdep"
    done
  fi

  if [ "$2" = "1" ]; then
    # re-source due to clobbering
    eval "$(. "$3/PKGSCRIPT";
    echo "DEPENDS=(${DEPENDS[*]})";
    echo "MK_DEPENDS=(${MK_DEPENDS[*]})";
    echo "OPT_DEPENDS=(${OPT_DEPENDS[*]})";)"
    for optdep in "${OPT_DEPENDS[@]}"; do
      echo "HOLE: Installing optional dependency $optdep"
      get_dependency "$optdep"
    done
  fi
}

### runs sheath and downloads dependencies
function run_sheath_get_deps() {
  echo "HOLE: Updating bulge database"

  yes | "$BULGE" s &>/dev/null
  yes | "$BULGE" u &>/dev/null

  # get dependencies
  get_deps 1 1 "$INPUT_DIR"

  # we should now be able to just run sheath
  run_sheath_no_get_deps "$@"
}

# depending on what the user wants to do, we may not need to do much if anything and possibly just pass through to sheath

NEEDS_GET_DEPS=0
NEW_ARGS=""
TESTING=0

while getopts ":hbicpfte:" opt; do
    case $opt in
        e) # special case for hole: pass env
            EXPORTS="$EXPORTS $OPTARG"
            ;;
        t) # special case for hole: activate testing mode after everything else
            TESTING=1
            ;;
        h)
            NEW_ARGS="$NEW_ARGS -h"
            ;;
        b)
            NEW_ARGS="$NEW_ARGS -b"
            NEEDS_GET_DEPS=1
            ;;
        i)
            # don't do anything, installs are handled outside of the container
            ;;
        c)
            NEW_ARGS="$NEW_ARGS -c"
            ;;
        p)
            NEW_ARGS="$NEW_ARGS -p"
            ;;
        f)
            echo "this shouldn't be called!?"
            ;;
        \?)
            NEW_ARGS="$NEW_ARGS -$opt"
            ;;
    esac
done

if [ "$NEEDS_GET_DEPS" -eq 1 ]; then
  run_sheath_get_deps ${NEW_ARGS}
else
  run_sheath_no_get_deps ${NEW_ARGS}
fi

if [ "$TESTING" -eq 1 ]; then
  echo ""
  echo ""
  echo "HOLE: Testing mode activated"
  echo "HOLE: Type 'exit' to exit"
  /usr/bin/env -i   \
  	HOME=/root                  \
  	TERM="$TERM"                \
  	PS1='(yiffOS testing) \u:\w\$ ' \
  	PATH=/usr/bin:/usr/sbin     \
  	/bin/bash --login
fi