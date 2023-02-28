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


### BEGIN HACKS (functions to fix issues that should be fixed upstream)

# packages with docbook-xml as a dependency may fail because the docbook-xml postinst script hasn't been run
# this function will run the postinst script
DOCBOOKXML_POSTINST_RUN=0
function hack_docbookxml_postinst() {
  if [ "$DOCBOOKXML_POSTINST_RUN" = "1" ]; then
    return 0
  fi
  POSTINST_URL="https://git.yiffos.gay/Packaging/packages/raw/commit/8c81d4e39e2ac5497c0d96188fcc55182c09b46c/docbook-xml/postinst.sh"
  curl --output /tmp/docbookxml_postinst.sh "$POSTINST_URL" -L &>/dev/null
  chmod +x /tmp/docbookxml_postinst.sh
  /tmp/docbookxml_postinst.sh
  DOCBOOKXML_POSTINST_RUN=1
}

# same as above, docbook-xsl has a postinst script that needs to be run
DOCBOOKXSL_POSTINST_RUN=0
function hack_docbookxsl_postinst() {
    if [ "$DOCBOOKXSL_POSTINST_RUN" = "1" ]; then
        return 0
    fi
    POSTINST_URL="https://git.yiffos.gay/Packaging/packages/raw/commit/d193cc4c5a8d17a42ce4da5e17bd13855c8d4de9/docbook-xsl/postinst.sh"
    curl --output /tmp/docbookxsl_postinst.sh "$POSTINST_URL" -L &>/dev/null
    chmod +x /tmp/docbookxsl_postinst.sh
    /tmp/docbookxsl_postinst.sh
    DOCBOOKXSL_POSTINST_RUN=1
}

### runs sheath without getting dependencies
function run_sheath_no_get_deps() {
  cd "$INPUT_DIR" || exit 1
  for export in "${EXPORTS[@]}"; do
    echo "exporting $export to sheath environment"
    # shellcheck disable=SC2086
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
    echo "HOLE: Deferring install from local cache: $1/${NAME}-${VERSION}-${EPOCH}.tar.xz"
    # install dependencies
    get_deps 0 0 "$1"
    # re-source due to clobbering
    eval "$(. "$1/PKGSCRIPT";
    echo "NAME=$NAME";
    echo "VERSION=$VERSION";
    echo "EPOCH=$EPOCH";)"
    # defer package installation to the end
    echo "$1/${NAME}-${VERSION}-${EPOCH}.tar.xz" >> "/factory/deferred_packages"
    return 0
  else
    return 1
  fi
}

function install_deferred_packages() {
  if [ -f "/factory/deferred_packages" ]; then
    while read -r line; do
      echo "HOLE: Installing deferred package: $line"
      yes | "$BULGE" li "$line" &>/dev/null
    done < "/factory/deferred_packages"
    rm "/factory/deferred_packages"
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
    if grep -q "^$1\$" "/factory/installed_packages"; then
      echo "HOLE: $1 is already installed, skipping"
      return
    fi
  fi

  # if the package is docbook-xml or docbook-xsl, run said package's postinst script
  if [ "$1" = "docbook-xml" ]; then
    echo "HOLE (HACK): Running docbook-xml postinst script"
    hack_docbookxml_postinst
  fi
  if [ "$1" = "docbook-xsl" ]; then
    echo "HOLE (HACK): Running docbook-xsl postinst script"
    hack_docbookxsl_postinst
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

  # install deferred packages
  install_deferred_packages

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

# shellcheck disable=SC2086
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
