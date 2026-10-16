# Editor Setup

This project is **IDE- and OS-agnostic by design**. C++ language intelligence comes from
[clangd](https://clangd.llvm.org/), QML intelligence from Qt's `qmlls`, and both are LSP servers
every major editor can drive. The build is configured with CMake Presets, so the same commands work
on Windows, Linux, and macOS.

## How the configuration is split

| Layer | Files | Who reads it |
|-------|-------|--------------|
| **Shared / portable** | `.clangd`, `.clang-tidy`, `.clang-format`, `.qmlformat.ini`, `.editorconfig`, `compile_commands.json`, `.qmlls.ini` (generated) | Every clangd/qmlls-based editor, identically. |
| **Per-editor launcher** | `.vscode/settings.json` (`clangd.arguments`), Neovim `cmd`, CLion settings, … | Each editor separately. These flags **cannot** live in `.clangd`. |

`.clangd` holds all the *semantic* behavior (background index, IncludeCleaner, inlay hints,
clang-tidy integration). The launcher flags below are the bits clangd only accepts on its
command line — most importantly `--query-driver`, which clangd refuses to read from a project
`.clangd` for security reasons.

## Prerequisites

- **LLVM/clangd** — `clangd`, `clang-format`, `clang-tidy` (`scripts/setup-windows.ps1` / `scripts/setup-ubuntu.sh` install them)
- **CMake ≥ 3.28** and **Ninja**
- **vcpkg** (auto-detected; see `cmake/config_vcpkg.cmake`). Qt comes from it — the first configure
  builds Qt from source (~1h), later configures restore it from vcpkg's binary cache.
- **Windows:** configure/build from a *Developer PowerShell for VS 2022* (or an IDE that sets up the
  MSVC environment) so clang-cl finds the Windows SDK and linker. If that shell points `VCPKG_ROOT` at
  Visual Studio's bundled vcpkg, pin yours with `VCPKG_ROOT_PATH` (see `CMakeUserPresets.json.example`).

## Step 1 — configure a preset (all editors)

clangd needs a compilation database and qmlls needs `.qmlls.ini`; configuring any preset writes both
(the `mirror_compile_commands` target copies `compile_commands.json` to the project root):

```sh
cmake --preset clang-cl-debug         # Windows
cmake --preset clang-linux-debug      # Linux
cmake --preset appleclang-debug       # macOS

cmake --build --preset clang-cl-debug
```

List everything available with `cmake --list-presets`.

## Step 2 — the canonical clangd launch flags

These mirror `.vscode/settings.json`. Replicate them in whatever editor you use:

```
--query-driver=**/clang*,**/clang-cl*,**/clang++*,**/g++*,**/gcc*,**/c++*
--header-insertion=iwyu
--header-insertion-decorators
--completion-style=detailed
--function-arg-placeholders=true
--pch-storage=memory
-j=4
```

`--query-driver` lets clangd interrogate your compiler (gcc / clang / clang-cl) for its system
include paths — essential on Windows and for any non-default-named driver.

## QML in any editor

- **Language server:** `qmlls` ships with Qt (vcpkg puts it in `build/<preset>/vcpkg_installed/<triplet>/tools/Qt6/bin/`).
  CMake writes `.qmlls.ini` next to the QML sources (`QT_QML_GENERATE_QMLLS_INI`), which tells qmlls
  where the build's `App` module lives — so completion knows `CounterViewModel` and the components.
  It's machine-specific and gitignored.
- **Formatting:** `.qmlformat.ini` is read by `qmlformat`, Qt Creator and the Qt VS Code extension;
  `cmake --build --preset <p> --target format` formats C++ and QML together, `format-check` fails CI on drift.
- **Linting:** `cmake --build --preset <p> --target all_qmllint`.
- **Profiling QML:** Qt's QML Profiler (Qt Creator) or `qmlprofiler`. Tracy (`ENABLE_TRACY`) covers the C++ side.

---

## VS Code

Already configured. Install the recommended extensions (`.vscode/extensions.json`): **clangd**,
**CMake Tools**, **CodeLLDB** (debugging), **EditorConfig**, and the official **Qt Qml** / **Qt C++**
extensions (qmlls, QML formatting, Qt type visualizers). The MS C/C++ extension (`cpptools`) is
**optional** — only its *debugger* is used (MSVC and GDB launch configs); its IntelliSense,
formatting, and analysis are disabled in settings, so it never competes with clangd.

## Qt Creator

Open `CMakeLists.txt`; Qt Creator imports `CMakePresets.json` and offers the presets as kits/build
configurations. Qt comes from the preset's vcpkg toolchain, not from a Qt version registered in
Qt Creator, so pick the preset-based configuration rather than a Qt-installer kit. `.clang-format`,
`.qmlformat.ini` and the QML tooling (qmlls, QML Profiler, QML debugger) are used natively.

## CLion

CLion has native support for everything in this template — **no plugins needed**.

1. **Open the project folder.** CLion detects `CMakePresets.json` and lists the presets under
   *Settings → Build, Execution, Deployment → CMake*. Enable the preset(s) for your platform.
   The vcpkg toolchain file is wired in by the preset.
2. **clang-format / clang-tidy** — read from `.clang-format` / `.clang-tidy` automatically.
3. **Run/Debug** — CLion creates run configurations from the CMake targets (app, `unit_tests`,
   `viewmodel_tests`, `qml_tests`) automatically.
4. **QML** — CLion has basic QML highlighting; for qmlls-level completion use Qt Creator or VS Code.

> CLion does **not** read the project `.clangd` or `compile_commands.json` — it builds its own code
> model from CMake. `.clang-format` and `.clang-tidy` are honored; clangd *semantic toggles* (inlay
> hints etc.) are set in its GUI. `.idea/` and `cmake-build-*/` are gitignored.

## Visual Studio (full IDE)

Visual Studio 2022 (17.4+) opens the folder and lists `CMakePresets.json` presets in the configuration
dropdown — pick `msvc-debug` or a `clang-cl-*` preset. VS uses its own IntelliSense (not clangd), honors
`.clang-format`, `.clang-tidy` and `.editorconfig`, and runs the target from `bin/<preset>/`. There is
no QML language support beyond highlighting.

## Neovim (nvim-lspconfig)

```lua
require('lspconfig').clangd.setup({
  cmd = {
    'clangd',
    '--query-driver=**/clang*,**/clang-cl*,**/clang++*,**/g++*,**/gcc*,**/c++*',
    '--header-insertion=iwyu',
    '--header-insertion-decorators',
    '--completion-style=detailed',
    '--function-arg-placeholders=true',
    '--pch-storage=memory',
    '-j=4',
  },
})
require('lspconfig').qmlls.setup({}) -- qmlls on PATH; reads the generated .qmlls.ini
```

## Emacs

**eglot** (built-in, Emacs 29+):

```elisp
(add-to-list 'eglot-server-programs
             '((c++-mode c-mode)
               . ("clangd"
                  "--query-driver=**/clang*,**/clang-cl*,**/clang++*,**/g++*,**/gcc*,**/c++*"
                  "--header-insertion=iwyu" "--completion-style=detailed"
                  "--function-arg-placeholders=true" "--pch-storage=memory" "-j=4")))
```

**lsp-mode**: set `(setq lsp-clients-clangd-args '("--query-driver=..." ...))`.

## Zed / Helix / Vim / Sublime

Pass the same flag list from Step 2 to the editor's clangd configuration (`lsp.clangd.arguments` in
Zed, `[language-server.clangd] args` in Helix, `coc-clangd` / `LSP-clangd` settings in Vim/Sublime).
For QML, point the editor's LSP client at `qmlls`.

---

## Debugging

The `*-debug` presets build with symbols, and each preset writes to its own `bin/<preset>/`. On
Windows the debug build keeps a console (qDebug/QML warnings visible); release builds don't.

**VS Code** — press **F5** and pick a config. All use `${command:cmake.launchTargetPath}`, so they follow
the active CMake Tools target/preset:

- **Debug (LLDB · all OS)** — default, via CodeLLDB. Clang, Apple Clang, clang-cl, GCC.
- **Debug (Windows MSVC · cppvsdbg)** — native Microsoft debugger; best PDB/Qt visualization on Windows.
- **Debug (GDB · GCC Linux)** — `cppdbg` + GDB with pretty-printing.

**CLI** — build a debug preset, then point your debugger at the preset's binary:

```sh
cmake --build --preset clang-linux-debug
lldb ./bin/clang-linux-debug/qt_qml_simple_hello
```

---

## Sanitizers

Sanitizers are exposed as presets (each builds and runs the sanitizer "trip-wire" death tests via ctest):

| Preset | Sanitizers | Platform |
|--------|-----------|----------|
| `clang-linux-asan` | UBSan + ASan + LSan | Linux |
| `clang-linux-tsan` | UBSan + TSan | Linux |
| `msvc-asan` | ASan | Windows (MSVC) |

```bash
cmake --preset clang-linux-asan && cmake --build --preset clang-linux-asan && ctest --preset test-clang-linux-asan
```

ASan and TSan are **mutually exclusive** (one per build); UBSan is the GCC/Clang baseline. Windows has
ASan only. MemorySanitizer is not offered: it needs every library, Qt included, built with it.

Windows notes:

- **`msvc-asan` is the Windows path.** cl.exe ASan uses the debug CRT (`/MDd`), matching vcpkg's debug libraries.
- **clang-cl ASan needs the release CRT (`/MD`)**, so every dependency (Qt included) would have to be
  built `/MD` too — no preset is provided for it.
- **STL container annotations are disabled under Windows ASan** (`_DISABLE_STRING_ANNOTATION` /
  `_DISABLE_VECTOR_ANNOTATION`) because prebuilt deps aren't ASan-instrumented.
- The **ASan runtime DLL** is deployed next to the executables automatically (`deploy_asan_runtime`
  in `cmake/sanitizers.cmake`).

---

## Alternative: machine-wide clangd flags

If you'd rather not repeat the flags per editor, put them in your **user** clangd config
(`~/.config/clangd/config.yaml` on Linux/macOS, `%LocalAppData%\clangd\config.yaml` on Windows).
`--query-driver` and the other launch flags remain command-line only; the user config covers the same
keys as the project `.clangd`.
