#!/usr/bin/env bash
# scripts/setup-ubuntu.sh — provision the C++/Qt toolchain in an Ubuntu / WSL2 distro.
#
# Idempotent: safe to re-run. This is the SINGLE source of truth for the Linux toolchain (a
# future Linux CI job should run this same script). Clang is PINNED to a
# specific version from apt.llvm.org (not the distro default, which on Ubuntu 24.04 is only
# clang-18), so WSL / container / CI all get the same compiler VERSION — not merely the same
# package names. That version match is what actually stops drift.
#
#   bash scripts/setup-ubuntu.sh              # toolchain + clang + Qt build deps + vcpkg (~/vcpkg)
#
# vcpkg builds Qt from source on first configure (~1h); the X11/xkb/GL dev packages below are what
# qtbase/qtdeclarative need for that. GUI tests run headless via the Linux test presets
# (QT_QPA_PLATFORM=offscreen).
#
# Override the pinned Clang with CLANG_VERSION=NN (must exist on apt.llvm.org for this distro).
set -euo pipefail

CLANG_VERSION="${CLANG_VERSION:-21}"

for arg in "$@"; do
  case "$arg" in
    --with-vcpkg) ;; # accepted for compatibility; vcpkg is always installed now
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

SUDO=""
if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi
export DEBIAN_FRONTEND=noninteractive

echo "==> apt: base C++ toolchain"
$SUDO apt-get update -y
$SUDO apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build ccache mold pkg-config gdb \
  git curl zip unzip tar ca-certificates gnupg lsb-release \
  python3 python3-pip pipx

echo "==> apt: build deps for Qt from vcpkg (qtbase/qtdeclarative) + Qt runtime libs"
$SUDO apt-get install -y --no-install-recommends   autoconf autoconf-archive automake libtool bison flex python3-venv   '^libxcb.*-dev' libx11-xcb-dev libxrender-dev libxi-dev libxext-dev libxkbcommon-dev   libxkbcommon-x11-dev libgl1-mesa-dev libglu1-mesa-dev libegl1-mesa-dev libfontconfig1-dev   libfreetype-dev

echo "==> Clang ${CLANG_VERSION} (pinned, from apt.llvm.org)"
# The distro's unversioned clang lags (Ubuntu 24.04 ships clang-18); pin a specific version so
# every environment matches. .asc key works directly with signed-by — no gpg dearmor needed.
if ! command -v "clang-${CLANG_VERSION}" >/dev/null 2>&1; then
  CODENAME="$(. /etc/os-release && echo "${VERSION_CODENAME}")"
  $SUDO install -d -m 0755 /etc/apt/keyrings
  curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key | $SUDO tee /etc/apt/keyrings/llvm.asc >/dev/null
  echo "deb [signed-by=/etc/apt/keyrings/llvm.asc] http://apt.llvm.org/${CODENAME}/ llvm-toolchain-${CODENAME}-${CLANG_VERSION} main" \
    | $SUDO tee "/etc/apt/sources.list.d/llvm-${CLANG_VERSION}.list" >/dev/null
  $SUDO apt-get update -y
fi
# libclang-rt-*-dev = compiler-rt runtime libs (libclang_rt.profile/asan/ubsan/tsan/msan...).
# The clang-* package does NOT include these, yet coverage (-fprofile-instr-generate) and the
# sanitizer presets need them — without it the link fails: "cannot open libclang_rt.profile.a".
# llvm-* provides the LLVM tools (llvm-cov, llvm-profdata) the `coverage` target uses to merge
# profiles and report — without it the target isn't created and `--target coverage` fails.
$SUDO apt-get install -y --no-install-recommends \
  "clang-${CLANG_VERSION}" "clangd-${CLANG_VERSION}" "clang-tidy-${CLANG_VERSION}" \
  "clang-format-${CLANG_VERSION}" "lld-${CLANG_VERSION}" "lldb-${CLANG_VERSION}" \
  "libclang-rt-${CLANG_VERSION}-dev" "llvm-${CLANG_VERSION}"

# Make the unversioned tools resolve to the pinned version — the project, presets and CI all
# invoke clang / clangd / clang-tidy / clang-format without a version suffix.
for tool in clang clang++ clangd clang-tidy clang-format lld ld.lld lldb llvm-cov llvm-profdata; do
  if [ -x "/usr/bin/${tool}-${CLANG_VERSION}" ]; then
    # High priority (1000) so the pinned version beats any pre-installed clang on a CI runner.
    $SUDO update-alternatives --install "/usr/bin/${tool}" "${tool}" "/usr/bin/${tool}-${CLANG_VERSION}" 1000
  fi
done

echo "==> gcc-16 (best effort — kept if your distro has it)"
if ! $SUDO apt-get install -y g++-16 gcc-16 2>/dev/null; then
  echo "    g++-16 not in this distro's repos — skipping (default gcc/clang remain)."
fi

echo "==> vcpkg (~/vcpkg)"
if [ ! -d "$HOME/vcpkg" ]; then
  git clone https://github.com/microsoft/vcpkg.git "$HOME/vcpkg"
  "$HOME/vcpkg/bootstrap-vcpkg.sh" -disableMetrics
fi
# For GitHub Actions: expose VCPKG_ROOT to subsequent steps
if [ -n "${GITHUB_ENV:-}" ]; then
  echo "VCPKG_ROOT=$HOME/vcpkg" >> "$GITHUB_ENV"
  echo "$HOME/vcpkg" >> "$GITHUB_PATH"
fi
if ! grep -q 'VCPKG_ROOT=' "$HOME/.bashrc" 2>/dev/null; then
  {
    echo 'export VCPKG_ROOT="$HOME/vcpkg"'
    echo 'export PATH="$VCPKG_ROOT:$PATH"'
  } >> "$HOME/.bashrc"
fi

echo ""
echo "Done."
echo "  clang : $(clang --version | head -1)"
echo "  cmake : $(cmake --version | head -1)"
echo "  vcpkg : $HOME/vcpkg (open a new shell to pick up VCPKG_ROOT)"
echo ""
echo "Then (first configure builds Qt in vcpkg, ~1h):"
echo "  cmake --preset clang-linux-debug -D BUILD_TESTING=ON && cmake --build --preset clang-linux-debug"
echo "  ctest --preset test-clang-linux-debug"
