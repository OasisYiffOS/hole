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

### runs sheath and downloads dependencies
function run_sheath_get_deps() {
  # source the PKGSCRIPT
  . "$INPUT_DIR/PKGSCRIPT"

  echo "=== Updating bulge database ==="

  yes | "$BULGE" s
  yes | "$BULGE" u

  for dep in "${DEPENDS[@]}"; do
    echo "=== Installing dependency $dep ==="
    yes | "$BULGE" i "$dep"
  done

  for mkdep in "${MK_DEPENDS[@]}"; do
    # if not, install it
    echo "=== Installing build dependency $mkdep ==="
    yes | "$BULGE" i "$mkdep"
  done

  # we should now be able to just run sheath
  run_sheath_no_get_deps "$@"
}

# depending on what the user wants to do, we may not need to do much if anything and possibly just pass through to sheath

NEEDS_GET_DEPS=0

while getopts ":hbicpfe:" opt; do
    case $opt in
        e) # special case for hole: pass env
            EXPORTS="$EXPORTS $OPTARG"
            ;;
        h)
            ;;
        b)
            NEEDS_GET_DEPS=1
            ;;
        i)
            ;;
        c)
            ;;
        p)
            ;;
        f)
            echo "this shouldn't be called!?"
            ;;
        \?)
            ;;
    esac
done

if [ "$NEEDS_GET_DEPS" -eq 1 ]; then
  run_sheath_get_deps "$@"
else
  run_sheath_no_get_deps "$@"
fi