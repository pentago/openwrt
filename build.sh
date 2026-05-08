#!/usr/bin/env bash
set -euo pipefail

VERSION="${VERSION:-v25.12.3}"
PROFILE="${PROFILE:-openwrt_one}"
TARGET="mediatek"
SUBTARGET="filogic"
JOBS="${JOBS:-$(nproc)}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKDIR="${WORKDIR:-$SCRIPT_DIR/build}"
SRC_DIR="$WORKDIR/openwrt"

PKGS_FILE="${SCRIPT_DIR}/pkgs.txt"
if [[ ! -f "$PKGS_FILE" ]]; then
  echo "error: $PKGS_FILE not found" >&2
  exit 1
fi

echo "Version:   $VERSION"
echo "Profile:   $PROFILE"
echo "Target:    $TARGET/$SUBTARGET"
echo "Jobs:      $JOBS"
echo ""

mkdir -p "$WORKDIR"

if [[ ! -d "$SRC_DIR/.git" ]]; then
  echo "Cloning OpenWrt source..."
  git clone --branch "$VERSION" --depth 1 https://github.com/openwrt/openwrt.git "$SRC_DIR"
else
  echo "Source already cloned."
  cd "$SRC_DIR"
  CURRENT_TAG=$(git describe --tags --exact-match 2>/dev/null || true)
  if [[ "$CURRENT_TAG" != "$VERSION" ]]; then
    echo "Switching to $VERSION..."
    git fetch --depth 1 origin tag "$VERSION"
    git checkout "$VERSION"
  fi
fi

cd "$SRC_DIR"

echo "Updating feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

echo "Generating .config..."
cat > .config <<EOF
CONFIG_TARGET_${TARGET}=y
CONFIG_TARGET_${TARGET}_${SUBTARGET}=y
CONFIG_TARGET_${TARGET}_${SUBTARGET}_DEVICE_${PROFILE}=y
EOF

while IFS= read -r line; do
  line="${line%%#*}"
  line="$(echo "$line" | xargs)"
  [[ -z "$line" ]] && continue
  if [[ "$line" == -* ]]; then
    pkg="${line#-}"
    echo "# CONFIG_PACKAGE_${pkg} is not set" >> .config
  else
    echo "CONFIG_PACKAGE_${line}=y" >> .config
  fi
done < "$PKGS_FILE"

make defconfig

echo "Building (jobs=$JOBS)..."
make -j"$JOBS" download
make -j"$JOBS" world

OWRT_REV=$(sed -n 's/^REVISION:=//p' include/version.mk 2>/dev/null || true)
MY_REV=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
SUFFIX="${OWRT_REV:+_${OWRT_REV}}_cfg-${MY_REV}"

OUTPUT_DIR="bin/targets/${TARGET}/${SUBTARGET}"
for img in "${OUTPUT_DIR}"/*-sysupgrade.itb; do
  [[ -f "$img" ]] || continue
  dest="${img%.itb}${SUFFIX}.itb"
  mv "$img" "$dest"
  echo "Renamed: $(basename "$dest")"
done

echo ""
echo "Done. Images are in:"
echo "  $SRC_DIR/$OUTPUT_DIR/"
