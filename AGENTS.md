# AGENTS.md — openwrt

Full source build for OpenWrt One (mediatek/filogic) via Docker.

## Structure

```
.
├── build.sh       # Clones OpenWrt source, generates .config from pkgs.txt, builds firmware
├── pkgs.txt       # Package list: one per line, # comments, - prefix to exclude
├── Dockerfile     # Ubuntu-based build environment (all deps included)
└── build/         # Working directory (cloned source + output), gitignored
```

## Where to Look

| Task | Location |
|------|----------|
| Add/remove packages | `pkgs.txt` |
| Change OpenWrt version | `build.sh` → `VERSION` (line 4), tag format: `v25.12.3` |
| Change device profile | `build.sh` → `PROFILE` (line 5) |
| Change target/subtarget | `build.sh` → `TARGET` / `SUBTARGET` (lines 6-7) |
| Find built images | `build/openwrt/bin/targets/mediatek/filogic/` |
| Build dependencies | `Dockerfile` |

## Usage

```bash
# Docker build (recommended — no host deps needed)
docker build -t openwrt-builder .
mkdir -p build
docker run --rm -v ./build:/home/builder/build openwrt-builder

# Native build (requires OpenWrt build deps on host)
./build.sh

# Override version or parallelism
VERSION=v25.12.4 ./build.sh
JOBS=8 ./build.sh
```

## Build Process

1. Shallow-clones OpenWrt source from GitHub (skips if already present)
2. Updates feeds (`./scripts/feeds update -a && install -a`)
3. Seeds `.config` with target/subtarget/device + packages from `pkgs.txt`
4. `make defconfig` expands to full config
5. `make download` then `make world`
6. Renames output `.itb` with OpenWrt revision + repo commit hash

First build: 1-3 hours, ~15-25GB disk. Incremental: ~10 min.

## Output

Flash file: `*-squashfs-sysupgrade*.itb` (the 22M one, NOT the initramfs 17M one)

```bash
scp build/openwrt/bin/targets/mediatek/filogic/*squashfs-sysupgrade*.itb root@<router-ip>:/tmp/
ssh root@<router-ip> sysupgrade -v /tmp/openwrt-*-sysupgrade*.itb
```

Or via LuCI: System → Backup / Flash Firmware → upload `.itb`

## Gotchas

- `build/` contains ~15-25GB (full toolchain + source). Delete to force clean rebuild.
- The `_cfg-unknown` suffix means git couldn't resolve HEAD (e.g. inside Docker without `.git` mounted). Mount `.git:ro` to fix.
- OpenWrt One uses `.itb` images, not `.bin`
- Package names change between releases — check release notes if "no such package"
- Dockerfile uses `useradd -u 1000 -o` to match typical host uid for bind mounts
- `make world` and `make` are equivalent (both do full build)
- `.config` seeds target as `CONFIG_TARGET_mediatek_filogic_DEVICE_openwrt_one=y` (no extra DEVICE_ prefix before target)
