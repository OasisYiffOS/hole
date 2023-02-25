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
  for export in $EXPORTS; do
    echo "exporting $export to sheath environment"
    export "${export?}"
  done
  "$SHEATH" "$@"
}

function get_dependency() {
  # fixme: awful hack to prevent overwriting gcc with gcc-libs, this will be fixed in the future
  if [ "$1" = "gcc-libs" ]; then
    echo "=== Refusing to install gcc-libs ==="
    return
  fi
  # if PKG_CACHE is set, check that first
  if [ -n "$PKG_CACHE" ]; then
    if [ -d "$PKG_CACHE/$1" ]; then
      if [ -f "$PKG_CACHE/$1/PKGSCRIPT" ]; then
        # source the PKGSCRIPT and check that there's a tar.xz file with ${NAME?}-${VERSION?}.tar.xz
        . "$PKG_CACHE/$1/PKGSCRIPT"
        if [ -f "$PKG_CACHE/$1/${NAME?}-${VERSION?}-${EPOCH?}.tar.xz" ]; then
          echo "=== Installing dependency $1 from cache ==="
          CURRENT_DIR=$(pwd)
          cd "$PKG_CACHE/$1" || exit 1
          yes | "$SHEATH" -i
          cd "$CURRENT_DIR" || exit 1
          return
        fi
      fi
    fi
  fi

  # otherwise, download it
  yes | "$BULGE" i "$1"
}

### runs sheath and downloads dependencies
function run_sheath_get_deps() {
  # source the PKGSCRIPT
  . "$INPUT_DIR/PKGSCRIPT"

  echo "=== Updating bulge database ==="

  yes | "$BULGE" s
  yes | "$BULGE" u

  for dep in "${DEPENDS[@]}"; do
    echo "=== Installing dependency $dep ==="
    get_dependency "$dep"
  done

  for mkdep in "${MK_DEPENDS[@]}"; do
    echo "=== Installing build dependency $mkdep ==="
    get_dependency "$mkdep"
  done

  for optdep in "${OPT_DEPENDS[@]}"; do
    echo "=== Installing optional dependency $mkdep ==="
    get_dependency "$mkdep"
  done

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
            # todo: implement install system
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
  echo "=== Testing mode activated ==="
  echo "=== Type 'exit' to exit ==="
  /usr/bin/env -i   \
  	HOME=/root                  \
  	TERM="$TERM"                \
  	PS1='(yiffOS testing) \u:\w\$ ' \
  	PATH=/usr/bin:/usr/sbin     \
  	/bin/bash --login
fi