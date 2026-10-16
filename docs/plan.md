# Balancer Robot — Plan

Status: draft, planning only. Nothing implemented yet.
Date: 2026-10-16

## 1. Goal

Zephyr C++ firmware for a two-wheel self-balancing robot, plus a QML desktop companion, in one monorepo:

- ESP32, IMU for balance, 2 DC motors (+ encoders, see Open questions)
- Driven by an Xbox controller, configured and monitored from the companion app over BLE
- native_sim first: the whole closed loop runs on the PC before any hardware
- Tested with gtest (pure logic), ztest (Zephyr glue), pytest (system)
- Control system easy to swap (priority 1), loop as efficient as possible (priority 2)
- Live telemetry to the app, dynamic control from the app, later high-level commands (go to pose)
- Empty, ready-to-fill auxiliary actuator module

## 2. Repo setup: one monorepo

```
balancer-robot/                 # git: the monorepo (generated from zephyr-project-template, no commits yet)
├─ firmware/                    # Zephyr, built ONLY in the Zephyr devcontainer
├─ companion-app/               # Qt/QML, built natively (Windows: VS Code or Qt Creator; Linux/WSL2/CI)
├─ protocol/                    # robot.proto, read by both via ../protocol
├─ tools/                       # python BLE client, plotter, sysid (used by both)
└─ docs/                        # plan.md, adr/, rfc/  — the one place for planning
```

Why one repo: protocol changes land in one commit (no tags/FetchContent between repos), one plan, one issue
tracker, shared style and pre-commit. The two halves never share a build: no root `CMakeLists.txt`, no root
`CMakePresets.json`. Each subfolder builds standalone, so `git subtree split` can pull either out later.

### 2.1 Cleanup (done 2026-10-16, not committed yet)

| Found | Problem | Fix |
|---|---|---|
| Root files (`.github/workflows/*.yml`, `.vscode/settings.json`, `.gitignore`, `.clangd` comment, `NOTES.md`) point at `apps/<app>` | samples sit in `firmware/`, so CI and the nRF extension find nothing | rewrite paths to `firmware/...` |
| `companion-app/.git` is a nested repo | the monorepo would record it as an embedded repo / gitlink, not files | delete `companion-app/.git` (history is one "reinit" commit) before the first commit |
| `companion-app/.github/` | GitHub only reads `.github/` at the repo root; ignored here | move its workflow + composite action to root (§2.6) |
| Three different `.clang-format` (root LLVM/100/Linux braces, companion Microsoft/tabs, nexus Microsoft/spaces/120) | style drift | one root `.clang-format` (§2.4) |
| `companion-app/.editorconfig` with `root = true`, root `.editorconfig` too | the nested one stops inheritance | one root `.editorconfig`, delete the nested one |
| `companion-app/.pre-commit-config.yaml` | pre-commit only reads the repo root config | merge into root `.pre-commit-config.yaml` |
| `firmware/emul-shell-gpio`, `firmware/renode-test` are template samples | not the product | move to `firmware/samples/` as reference; CI only builds them on demand |
| Old repos `balancer-robot-zephyr`, `balancer-robot-desktop-companion`, `balancer-robot-workspace`, `balancer-robot-fw` | superseded | archive read-only on GitHub (**still to do, by hand**) |

Done as listed, with these deviations from the draft below:

- `companion-app/.gitignore` stays (nested `.gitignore` is plain git, keeps the companion self-contained); the root
  one covers the Zephyr side. `.gitattributes` is merged into the root.
- The root `.vscode/` is the **host window for the companion** (`cmake.sourceDirectory = companion-app`, presets,
  clangd, Qt extensions). The firmware window uses `firmware/.vscode/` inside the devcontainer.
  `companion-app/.vscode/` stays for opening that folder on its own (its `launch.json`/`tasks.json` assume it).
- `firmware/.clangd` sets no `CompilationDatabase`: clangd finds `<app>/build/compile_commands.json` per app
  (build without `-d`).
- `samples.yml` runs on changes to `firmware/samples/**` (not dispatch-only); `firmware.yml` for the real app comes
  with phase 1. The old `build.yml`/`tests.yml`/`renode.yml` are merged into `samples.yml`.
- qmlformat is not a pre-commit hook (needs the vcpkg Qt on PATH); the companion workflow's `qml-format-check`
  target covers it.
- Every tracked C/C++ file was reformatted once with the root `.clang-format` (nexus style).
- `firmware/app/` (copy of the emul-shell-gpio sample) is the start of the balancer app, so the Zephyr app lives in
  `firmware/app/`, not directly in `firmware/` as §5 shows; read §5's `firmware/` tree as `firmware/app/`.

### 2.2 Devcontainer (firmware, must work)

The root template already gives the right base: image `ghcr.io/royyandzakiy/zephyr-devcontainer-devel:z4.4.0-sdk1.0.1`
(Zephyr 4.4.0, Zephyr SDK 1.0.1, Xtensa ESP32/ESP32-S3 toolchains, `hal_espressif` blobs), shared `zephyr-sdks` /
`ncs-sdks` / `cmake-registry` volumes, clangd in the image, CI twin `zephyr-devcontainer-ci` with the same tag.

Layout:

```
.devcontainer/
├─ firmware/devcontainer.json        # default: Windows/Linux, USB via usbipd
└─ firmware-macos/devcontainer.json  # amd64 emulated, no USB (current macos/ moved)
```

- Named configs under `.devcontainer/<name>/`: "Reopen in Container" on the repo root offers the list.
- Mount the **whole repo** (default `workspaceMount`), but set
  `"workspaceFolder": "/workspaces/${localWorkspaceFolderBasename}/firmware"`. The window opens on `firmware/`
  (its `.vscode/`, `.clangd` apply) and `../protocol`, `../tools` are still reachable.
- No companion devcontainer. Qt from vcpkg is a ~1 h source build and GUI/Qt Creator in a container is painful.
  Linux parity for the companion comes from `companion-app/scripts/setup-ubuntu.sh` (WSL2 and CI run the same script).
  Revisit only if CI drift appears.
- Flashing ESP32 from the container: `usbipd attach --wsl --busid <id>` the USB-serial bridge, enable the `/dev` bind
  mount line that is already commented in the config, `west flash --runner esp32 --esp-device /dev/ttyUSB0`.
- One Zephyr version for the whole repo, pinned by the image tag (`z4.4.0-sdk1.0.1`) in both devcontainer files and
  all firmware workflows. Bumping Zephyr = one tag change in three places (grep-able).

Working model: **two editor windows, never one multi-root workspace.**

| Window | Opened on | Where it runs | Toolchain |
|---|---|---|---|
| Firmware | repo root → Reopen in Container → `firmware` | Zephyr devcontainer | west, Zephyr SDK, clangd in image |
| Companion | `companion-app/` | host (Windows) in VS Code **or** Qt Creator; WSL2 for Linux | vcpkg Qt 6.8, clang-cl / clang 21 |

A multi-root workspace would put the companion inside the Zephyr container, where Qt is not installed.

### 2.3 clangd

clangd merges every `.clangd` from the file's directory up to the root; nearer files override.

| File | Content |
|---|---|
| `/.clangd` | shared editor behaviour only: `Index`, `InlayHints`, `Hover`, `Completion` |
| `/firmware/.clangd` | `CompilationDatabase: build` (west default dir); the Xtensa/GCC `Remove:` list from the template; `UnusedIncludes/MissingIncludes: None` (Zephyr headers) |
| `/companion-app/.clangd` | as today: `CompilationDatabase: .` (mirrored by `cmake/clangd.cmake`), `/Fo* /Fd*` removal, `UnusedIncludes: Strict` |

- `firmware/.vscode/settings.json` passes `--query-driver=/workdir/zephyr-sdks/toolchains/**/bin/*-gcc,/usr/bin/*`
  so clangd picks up the Xtensa sysroot and libstdc++ headers. `--query-driver` cannot live in `.clangd`.
- Firmware host unit-test build (§4) writes to `firmware/build-host/<preset>/`; clangd still follows the Zephyr
  build DB, which already compiles `src/core/`.
- `companion-app/.vscode/` stays as is (CMake Tools + presets + clangd + Qt extensions). Qt Creator uses its own
  clangd and reads the same `.clangd` / `.clang-tidy` / `.clang-format`.

### 2.4 Style and lint (shared, C++23)

- **One `/.clang-format`**: nexus style (Microsoft base, spaces, 4 indent, 120 cols, `Standard: Latest`).
  Delete `companion-app/.clang-format`. Reformat the companion once in the first commit.
- **`/.clang-tidy`** = shared base (bugprone, modernize, performance, cppcoreguidelines + the nexus disables,
  `WarningsAsErrors: '*'`).
  - `firmware/.clang-tidy`: `InheritParentConfig: true`; embedded extras off (`pro-type-vararg` for `LOG_*`/`printk`,
    `avoid-magic-numbers` for register-ish constants, `macro-usage` for Zephyr macros); `HeaderFilterRegex: 'src/.*'`.
  - `companion-app/.clang-tidy`: `InheritParentConfig: true`; Qt extras (moc, `Q_OBJECT`); `test/sanitizers/.clang-tidy` kept.
- **`/.editorconfig`** single file (C/C++ 4 spaces, CMake 2, YAML 2, JSON per companion's tabs, `.overlay/.dts` 4 spaces).
- **`/.pre-commit-config.yaml`** merged: whitespace/EOL/yaml/json hooks, clang-format (v20.1.8 pin), cmake-format/lint,
  plus a local `qmlformat` hook limited to `companion-app/**/*.qml` (uses `.qmlformat.ini`).
  Devicetree overlays are not run through clang-format.
- `.cmake-format.yaml`: one at root.
- `.gitignore` / `.gitattributes`: root only, union of both (`firmware/**/build*/`, `twister-out*/`,
  `companion-app/build/`, `vcpkg_installed/`, mirrored `compile_commands.json`, `CMakeUserPresets.json`,
  `project_options.local.cmake`, `.qmlls.ini`).

### 2.5 CMakePresets (C++ host builds only)

| Where | What | Why |
|---|---|---|
| `companion-app/CMakePresets.json` | unchanged (msvc / clang-cl / clang-linux / gcc-linux / appleclang, asan/tsan, `clang-cl-e2e`) + **add `clang-linux-e2e`** (Spix on Linux, headless) | Qt Creator and VS Code CMake Tools read presets from the opened folder |
| `firmware/CMakePresets.json` | host unit tests of `src/core/` only: `gcc-linux-debug`, `clang-linux-debug`, `clang-linux-asan`, `clang-cl-debug`; same names and `test-<preset>` test presets as the companion | reuse the same composite CI action; run gtest in the container (gcc) and on Windows (clang-cl) |
| root | **none** | nothing builds both halves together |
| Zephyr app | **no presets**, `west build` | the native Zephyr entry point; boards/overlays/`EXTRA_CONF_FILE` are west arguments |

- `CMakeUserPresets.json.example` in each subfolder, real file gitignored.
- `cmake/` modules stay per subfolder (copies from the templates), so each half stays self-contained and template
  re-syncs remain a plain diff. Firmware host build needs only `compiler`, `sanitizers`, `coverage`,
  `configure_target`, `clangd`.

### 2.6 GitHub workflows (all at root `.github/`)

```
.github/
├─ actions/cmake-build-test/action.yaml   # moved from companion; used by companion + firmware host tests
└─ workflows/
   ├─ firmware.yml     # paths: firmware/**, protocol/**, .github/**
   ├─ companion.yml    # paths: companion-app/**, protocol/**, .github/**
   └─ samples.yml      # workflow_dispatch only: the moved template samples (emul-shell-gpio, renode)
```

`firmware.yml` (container `zephyr-devcontainer-ci:z4.4.0-sdk1.0.1`):

- `build`: matrix `native_sim/native`, `esp32s3_devkitc/esp32s3/procpu` (`--no-sysbuild` until MCUboot phase).
- `twister`: `west twister -T firmware/test -p native_sim` (ztest + pytest harness), upload reports like today's `tests.yml`.
- `host-unit`: composite action with `gcc-linux-debug` and `clang-linux-asan` presets in the same container
  (if the CI image lacks clang, gcc only).

`companion.yml`:

- `windows`: `clang-cl-debug`, `clang-cl-release`, `clang-cl-e2e` (as in the companion today), vcpkg binary cache.
- `linux`: `ubuntu-latest`, run `scripts/setup-ubuntu.sh`, presets `clang-linux-debug`, `clang-linux-asan`,
  `clang-linux-e2e`. Qt tests headless with `QT_QPA_PLATFORM=offscreen`; Spix E2E the same, `xvfb-run` as fallback if
  offscreen rendering misbehaves. vcpkg binary cache keyed on `vcpkg.json` + triplet.

Shared: `concurrency` cancel-in-progress per ref; a `protocol/**` change runs both workflows.

## 3. Ground rules (firmware)

### Platform

- **Upstream Zephyr 4.4.0** (pinned by the devcontainer image tag), not NCS. ESP32 needs `hal_espressif` and its
  blobs, both already in the image.
- **Freestanding app, no west manifest**: the SDK lives in the shared `zephyr-sdks` volume; the repo never pins
  or contains an SDK beyond the image tag.
- In-repo drivers, devicetree bindings and Kconfig work without a manifest: `firmware/zephyr/module.yml`, and the
  app adds itself before `find_package`: `list(APPEND ZEPHYR_EXTRA_MODULES ${CMAKE_CURRENT_SOURCE_DIR})`.
- Zephyr modules come from the image's workspace (`hal_espressif`, `nanopb`, `mcuboot`). Nothing vendored.
- Dropped from the nRF5340 experiments: TF-M, NCS DFU sample, AEM. Kept: MCUboot + MCUmgr SMP (supported on ESP32), SMF.

### C++ conventions (nexus-dll-lib-cmake + companion), C++23 everywhere

- C++23 in all three builds: Zephyr (`CONFIG_STD_CPP2B` / `CONFIG_STD_CPP23` if 4.4 offers it, libstdc++ via
  `CONFIG_GLIBCXX_LIBCPP`), firmware host tests and companion (`CMAKE_CXX_STANDARD 23`).
- Concepts + composition over virtual functions (nexus ADR 0011/0013).
- `std::expected<T, std::error_code>` with the `REGISTER_ERROR_DOMAIN` pattern.
- `m_` members, `kConstants`, snake_case functions, PascalCase types, `// file.hpp — purpose` header line.
- `docs/adr/` and `docs/rfc/` at the repo root for decisions.

### Deliberate differences from the companion (embedded)

- No exceptions, no RTTI (`CONFIG_CPP_EXCEPTIONS=n`, `CONFIG_CPP_RTTI=n`). `std::expected` does not need them.
- No heap after init, no `std::function`, no spdlog/fmt. Zephyr `LOG_*` outside the real-time path only.
- `float` only in control code (ESP32 FPU is single precision; `double` is software), `-fsingle-precision-constant`.

### Most native Zephyr

Prefer the in-tree subsystem every time: sensor API + RTIO streaming, PWM / MCPWM, QDEC (PCNT),
devicetree + bindings, Kconfig, SMF, zbus, settings + NVS, shell, task watchdog, MCUmgr, emul API, twister.

## 4. Build entry points (firmware)

| Build | Entry | Toolchain | Runs |
|---|---|---|---|
| Zephyr app | `firmware/CMakeLists.txt` via `west build -b <board> firmware` | Zephyr SDK (devcontainer / CI image) | native_sim, ESP32-S3 |
| Host unit tests | `firmware/test/unit/` via `firmware/CMakePresets.json` | gcc/clang in container, clang-cl on Windows | gtest on `src/core/`, sanitizers, coverage |

- gtest for the host build via CMake `FetchContent` (no vcpkg in the Zephyr container).
- `firmware/src/core/CMakeLists.txt` defines a plain library target used by both entries.
- `protocol/robot.proto` is referenced as `${CMAKE_CURRENT_SOURCE_DIR}/../protocol` by firmware (nanopb) and
  companion (QtProtobuf, vcpkg `qtgrpc`). Protocol version field checked on connect.

## 5. Repo layout

```
balancer-robot/
├─ .devcontainer/firmware/  .devcontainer/firmware-macos/
├─ .github/actions/cmake-build-test/  .github/workflows/{firmware,companion,samples}.yml
├─ .clang-format .clang-tidy .clangd .cmake-format.yaml .editorconfig .gitattributes .gitignore .pre-commit-config.yaml
├─ README.md                # which window / tool for what, quick commands
├─ docs/  plan.md  adr/  rfc/
├─ protocol/robot.proto     # wire format, single source of truth
├─ tools/                   # python BLE client (bleak), live plotter, tuning / sysid scripts
│
├─ firmware/
│  ├─ CMakeLists.txt  Kconfig  prj.conf  sample.yaml  version.txt  CHANGELOG.md
│  ├─ CMakePresets.json  CMakeUserPresets.json.example   # host unit tests only
│  ├─ .clangd  .clang-tidy  .vscode/                     # firmware-specific overrides
│  ├─ zephyr/module.yml
│  ├─ boards/               # native_sim_native.overlay/.conf, esp32s3_devkitc_esp32s3_procpu.overlay/.conf
│  ├─ conf/                 # debug.conf, sim.conf, ...
│  ├─ cmake/                # compiler, sanitizers, coverage, configure_target, clangd (host build)
│  ├─ src/
│  │  ├─ core/              # pure C++23, NO Zephyr includes, host-buildable
│  │  │  ├─ common/         # units, math, seqlock, spsc_ring, static containers, errors
│  │  │  ├─ estimation/     # concepts.hpp, complementary, kalman, madgwick, estimator_set.hpp
│  │  │  ├─ control/        # concepts.hpp, pid, cascade_pid, lqr, (mpc later), controller_set.hpp
│  │  │  ├─ plant/          # wheeled inverted pendulum model (sim + LQR design)
│  │  │  ├─ motion/         # odometry, trajectory, go_to_pose (outer loop)
│  │  │  ├─ params/         # typed, versioned parameter table
│  │  │  └─ protocol/       # telemetry frame layout, encode/decode helpers
│  │  ├─ main.cpp           # wiring only
│  │  ├─ rt/                # control loop thread, timing, jitter / WCET stats
│  │  ├─ sensing/           # IMU through sensor API (RTIO stream)
│  │  ├─ actuation/drive/   # 2 DC motors (PWM/MCPWM) + encoders (QDEC)
│  │  ├─ actuation/actuator/# auxiliary actuator, empty stub behind a concept
│  │  ├─ comms/ble/         # robot GATT service, gamepad central (HID over GATT), SMP
│  │  ├─ telemetry/         # stream selection, decimation, batching, burst capture
│  │  ├─ supervisor/        # SMF: modes, arming, safety, battery, watchdog
│  │  ├─ settings/          # params persistence (settings + NVS)
│  │  └─ shell/             # robot param/arm/mode/push/... commands
│  ├─ drivers/  dts/bindings/   # sim plant emulator (IMU emul + sim motor), other OOT drivers
│  ├─ test/
│  │  ├─ unit/              # gtest, host CMake build of src/core/
│  │  ├─ ztest/             # native_sim suites (testcase.yaml each)
│  │  └─ pytest/            # twister pytest harness, system tests over shell
│  └─ samples/              # emul-shell-gpio, renode-test (template references)
│
└─ companion-app/           # as generated: CMakeLists, CMakePresets, cmake/, src/core, src/viewmodels, qml/, test/ (gtest, QtTest, Qt Quick Test, Spix e2e), vcpkg.json
   ├─ .clangd  .clang-tidy  .vscode/  .qmlformat.ini           # companion-specific overrides
   └─ (no .git, .github, .editorconfig, .clang-format, .pre-commit-config.yaml: moved to root)
```

Rules:

- `firmware/src/core/` never includes Zephyr. All control logic is plain C++ testable with gtest on the PC.
- The rest of `firmware/src/` only adapts Zephyr devices and threads to `src/core/` concepts.
- Swapping or adding a controller only touches `src/core/control/` (+ one Kconfig entry).
- `firmware/` and `companion-app/` never include each other's code; they meet only at `protocol/`.

## 6. Architecture

### Data flow

```
IMU ──(RTIO, data-ready)──► Estimator ──► Controller ──► Mixer ──► Drive motors
                              ▲              ▲   │
Encoders ──(QDEC)────────────┘   Setpoint ──┘   └──► SPSC ring ──► Telemetry ──► BLE notify
                                   (seqlock)
             Supervisor (mode owner) ◄── Gamepad / App / Planner (go_to_pose)
```

### Threads

| Thread | Priority | Rate (start) | Job |
|---|---|---|---|
| control | cooperative, highest | 500 Hz–1 kHz, set by IMU ODR | read IMU/encoders → estimate → control → motors |
| planner | preemptive | 20–50 Hz | velocity/heading/go-to-pose outer loop, writes setpoints |
| supervisor | preemptive | 50 Hz | SMF modes, safety, battery, watchdog, setpoint source arbitration |
| telemetry | low | 50–100 Hz | drain ring, encode, batch, notify |
| BT RX (Zephyr) | stack-owned | event | decode commands → setpoint / params / zbus events |

### Concepts (swap points)

- `EstimatorConcept`: `reset()`, `update(const ImuSample&, const EncoderSample&, float dt) -> State`
- `ControllerConcept`: `reset()`, `step(const State&, const Setpoint&, const Params&) -> Command`
- `DriveConcept`, `ImuConcept`, `ActuatorConcept`: hardware vs sim backend chosen per board

Hardware-facing concepts are compile-time (template + concept, nexus style): one backend per build, zero cost.

### Swapping controllers at runtime

| Option | Swap at | Cost | Verdict |
|---|---|---|---|
| A. template + concept | compile time | zero, fully inlined | used for hardware backends |
| **B. `std::variant<Pid, CascadePid, Lqr, ...>` + `std::visit`** | **runtime, from the app** | one jump table, no heap/vtable | **chosen for estimators and controllers** |
| C. virtual interface | runtime | indirect call, no inlining | rejected (ADR 0011) |

- Kconfig selects which controllers go into the variant (smaller image, faster visit).
- Switching happens only in `Idle`/`Armed` or with a bumpless-transfer reset.
- Each controller owns its params block; the param table exposes them to the app by id.

### State handoff (lock-free hot path)

- Setpoints: seqlock, written by supervisor/planner, read by control.
- Params: double buffer, pointer swap at the loop boundary, so app tuning never glitches mid-step.
- Telemetry: SPSC ring from control to telemetry; control never blocks on BLE.
- zbus: slow events only (mode change, fault, params changed, link state). Never in the control loop.

## 7. Control loop: efficiency options

Pick by measurement; jitter and WCET are reported in telemetry from day one.

1. **IMU data-ready IRQ → RTIO stream → control thread** (default). Loop is locked to the IMU ODR, async/DMA bus reads, most native.
2. **`k_timer` → semaphore → control thread.** Simplest, independent of the sensor, risk of stale samples. Fallback.
3. **Hardware timer ISR runs the whole loop.** Lowest jitter, no blocking, hard to debug. Only if 1 is not enough.
4. **IMU FIFO watermark batching** (e.g. 4 samples per wake). Fewer wakeups, estimator still sees every sample. Combinable with 1.

Always on:

- `CONFIG_FPU`, `CONFIG_FPU_SHARING`, float only, no `double` literals
- No logging, heap, mutex or zbus in the loop; statically allocated everything
- Hot code in IRAM where it helps (ESP32 flash cache misses cost jitter)
- Loop timing via cycle counter: period jitter, WCET, overrun counter
- Later option: dedicate the second core to the control loop, if Zephyr SMP/AMP on the chosen ESP32 allows it (to verify)

## 8. BLE

### Roles

- Peripheral to the app, central to the Xbox controller, simultaneously (`CONFIG_BT_MAX_CONN >= 2`).
- Request MTU 247, data length extension, 2M PHY. LE Secure Connections, bonds stored in settings.

### GATT

| Service | Characteristic | Props | Payload |
|---|---|---|---|
| Robot | `command` | write w/o resp | setpoint, mode, go_to_pose, arm/disarm (protobuf) |
| Robot | `params` | read/write | param get/set by id, schema version (protobuf) |
| Robot | `telemetry` | notify | packed binary frames, several samples per notification |
| Robot | `status` | read/notify | mode, faults, battery, loop stats |
| SMP | — | — | MCUmgr OTA |

### Encoding

- Commands/params: protobuf via nanopb (Zephyr module). The QML app uses QtProtobuf on the same `robot.proto`.
- Telemetry: fixed little-endian frame `{version, seq, timestamp, stream_mask, samples[]}`, no codec cost.
- Telemetry streams selectable with per-stream decimation. Full loop rate does not fit BLE, so **burst capture**
  records to RAM at full rate and uploads afterwards (for tuning and system identification).

### Modes (owned by supervisor, not BLE)

`Teleop(Gamepad)`, `Teleop(App)`, `Waypoint`, `Tuning`, `Sysid`. The mode decides which source owns setpoints;
each source has a timeout that triggers a failsafe stop.

### Xbox controller

- Upstream Zephyr has no HID-over-GATT (HOGP) client; write a small one: discover HID 0x1812, bond, subscribe to input report, parse Xbox report layout into a `GamepadState`.
- Alternative (see Open questions): controller → app (Qt Gamepad) → robot `command`. Simpler, and the robot then only needs one connection.

## 9. Supervisor and safety

SMF hierarchy: `Boot → Calibrating → Idle → Armed → Balancing → Fault`.

- Tilt limit → motors off, `Fault`
- Setpoint source timeout (gamepad/app link loss) → stop, then disarm
- Battery undervoltage (ADC) → warn, then disarm
- Task watchdog on control, supervisor, telemetry
- Gyro bias calibration at boot; mounting offsets in settings
- Explicit arm required before motors move

## 10. Simulation (native_sim first)

- `src/core/plant/`: wheeled inverted pendulum model (nonlinear, RK4), parameters from the real robot later.
- Emulated IMU driver (Zephyr emul API, custom binding) reads from the plant.
- Sim drive backend pushes motor commands into the plant torque.
- Shell hooks in sim: `sim push <N>`, `sim tilt <deg>`, `sim noise <...>`.
- Result: the same `src/` (core + Zephyr glue) closes the loop on the PC.
- Needs Linux: WSL2 or devcontainer. BLE in sim via BabbleSim, later.

## 11. Testing

| Level | Tool | Target | Examples |
|---|---|---|---|
| Unit | gtest | host CMake build of `src/core/` | PID anti-windup, LQR stabilises linear plant, seqlock, frame encode |
| Integration | ztest | native_sim | params apply at boundary, supervisor transitions, closed loop recovers from 5° step |
| System | pytest (twister harness) | native_sim, later hardware | `sim push 0.3` keeps upright, telemetry seq continuous, failsafe on timeout |

CI: host gtest + twister on native_sim, using the nexus CI-script-plus-thin-pipeline pattern.

## 12. Actuator stub

- `ActuatorConcept`: `init()`, `apply(const ActuatorCommand&)`, `stop()`.
- `NullActuator` backend now, wired through Kconfig/devicetree, command field already in `robot.proto`.
- Real backend later (servo/PWM/GPIO) without touching control code.

## 13. Phases

| # | Phase | Done when |
|---|---|---|
| 0 | Monorepo cleanup (§2.1–2.6): drop `companion-app/.git`, move samples, fix `apps/` paths, named devcontainers, unified style/pre-commit, presets, root workflows, `plan.md` into `docs/`, archive old repos | firmware devcontainer builds `native_sim` + ESP32-S3 hello world and flashes over usbipd; companion builds on Windows and in WSL2; all three workflows green |
| 1 | `src/core/` skeleton: common, concepts, PID, complementary filter, plant model, gtest host build | gtest green, plant open-loop falls as expected |
| 2 | native_sim closed loop: emul IMU, sim drive, control thread, supervisor | ztest: robot balances in sim |
| 3 | Params + shell + settings | tune gains from shell, persisted across reboot |
| 4 | BLE robot service + `protocol/robot.proto` (nanopb) + telemetry, python client in `tools/` | live plot from python, params over BLE |
| 5 | pytest system tests + CI | twister + pytest green in CI |
| 6 | ESP32 hardware bring-up: IMU, motors, encoders, timing measurement | real loop jitter/WCET numbers, balances on hardware |
| 7 | Gamepad input (direct or via app) | drive with Xbox controller |
| 8 | More controllers: cascade PID, LQR, runtime switch | switch controller from app while idle |
| 9 | Odometry + go_to_pose, burst capture, sysid | robot drives to a commanded pose |
| 10 | MCUboot + SMP OTA | update over BLE |
| 11 | Companion app on `../protocol` (QtProtobuf), BLE, telemetry view, param editor; Spix E2E on Windows + Linux (separate plan section later) | companion connects, shows telemetry, edits params; E2E green in CI |

## 14. Open questions

Defaults in brackets are what this plan assumes until answered.

1. Exact ESP32 variant? C2/C3/C6 have no FPU, which changes the loop design. [ESP32-S3]
2. IMU and motor driver part, and are there wheel encoders? [ICM-42688 or LSM6DSO over SPI, TB6612FNG, yes encoders]
3. Xbox controller direct to robot, or through the companion? Via the companion needs a gamepad library there (Qt 6 dropped Qt Gamepad: SDL3 or GameInput/XInput through vcpkg). [direct, with companion route as fallback]
4. OK to archive `balancer-robot-zephyr`, `balancer-robot-desktop-companion`, `balancer-robot-workspace`, `balancer-robot-fw`, `balancer-robot-firmware`? [yes, read-only]
5. Keep the template samples in `firmware/samples/`, or delete them once the real app has its own tests? [keep until phase 2, then delete]
6. "BLE has several modes": the operating modes in §8, or something else (pairing, profiles)? [operating modes]
7. Likely actuator type (servo, arm, LED)? [unknown, null stub]
8. App platform: desktop (Windows) only, or also mobile? [Windows desktop first]
9. Root `.clang-format`: nexus style (spaces, 120 cols) as proposed in §2.4, or the companion's tabs? [nexus]
10. Add a companion devcontainer later for Linux parity, or rely on `setup-ubuntu.sh` in WSL2 + CI? [setup-ubuntu.sh]
