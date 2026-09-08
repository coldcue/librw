#!/bin/sh
# Build ANGLE (libEGL/libGLESv2) from vendor/angle with its own gclient/gn/ninja toolchain.
# vendor/angle tracks the coldcue/angle fork (revc branch), which carries the
# FP16 EDR backbuffer and MetalFX upscaling changes as commits.
# Usage: build_angle.sh [DESTDIR]; env overrides: ANGLE_DIR, ANGLE_OUT, ANGLE_GN_ARGS, DEPOT_TOOLS
set -e

LIBRW_DIR=$(cd "$(dirname "$0")" && pwd)
ANGLE_DIR="${ANGLE_DIR:-$LIBRW_DIR/vendor/angle}"
OUT="${ANGLE_OUT:-out/Release}"
DEST="$1"

case "$(uname)" in
Darwin) LIBEXT=dylib ;;
*)      LIBEXT=so ;;
esac

if [ ! -d "$ANGLE_DIR" ]; then
	echo "error: $ANGLE_DIR missing - run: git submodule update --init vendor/angle" >&2
	exit 1
fi

# find or fetch depot_tools
if [ -n "$DEPOT_TOOLS" ]; then
	:
elif command -v gclient >/dev/null 2>&1; then
	DEPOT_TOOLS=$(dirname "$(command -v gclient)")
elif [ -d "$LIBRW_DIR/vendor/depot_tools" ]; then
	DEPOT_TOOLS="$LIBRW_DIR/vendor/depot_tools"
elif [ -d "$LIBRW_DIR/../depot_tools" ]; then
	DEPOT_TOOLS=$(cd "$LIBRW_DIR/../depot_tools" && pwd)
else
	echo "depot_tools not found, cloning into vendor/depot_tools..."
	git clone --depth 1 https://chromium.googlesource.com/chromium/tools/depot_tools.git "$LIBRW_DIR/vendor/depot_tools"
	DEPOT_TOOLS="$LIBRW_DIR/vendor/depot_tools"
fi
PATH="$DEPOT_TOOLS:$PATH"
export PATH

cd "$ANGLE_DIR"

# one-time dependency sync (several GB); stamp only on success so an
# interrupted sync is resumed on the next run
[ -f .gclient ] || python3 scripts/bootstrap.py
if [ ! -f .gclient_synced ]; then
	gclient sync
	touch .gclient_synced
fi

if [ ! -f "$OUT/build.ninja" ]; then
	gn gen "$OUT" --args="${ANGLE_GN_ARGS:-is_debug=false angle_enable_vulkan=false angle_enable_swiftshader=false}"
fi
autoninja -C "$OUT" libEGL libGLESv2

if [ -n "$DEST" ]; then
	mkdir -p "$DEST"
	cp "$OUT/libEGL.$LIBEXT" "$OUT/libGLESv2.$LIBEXT" "$DEST/"
	echo "ANGLE libraries copied to $DEST"
fi
