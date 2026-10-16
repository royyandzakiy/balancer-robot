#requires -Version 5.1
<#
  scripts/setup-windows.ps1 — install the native Windows C++/Qt toolchain via winget + vcpkg.
  Idempotent. clang-cl / MSVC path. Qt itself comes from vcpkg on first configure (~1h, then cached).

    pwsh -File scripts/setup-windows.ps1
#>
param([switch]$WithVcpkg) # accepted for compatibility; vcpkg is always installed now
$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Write-Error "winget not found. Install 'App Installer' from the Microsoft Store, then re-run."
}

function Install-WinGet([string]$Id) {
  if (winget list --id $Id --exact 2>$null | Select-String -SimpleMatch $Id) {
    Write-Host "  = $Id (already installed)"
  } else {
    Write-Host "  + installing $Id"
    winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements
  }
}

Write-Host "==> toolchain (LLVM/clang-cl, CMake, Ninja, Git, Python, ccache)"
Install-WinGet 'LLVM.LLVM'          # provides clang, clangd, clang-format, clang-tidy, lld AND clang-cl
Install-WinGet 'Kitware.CMake'
Install-WinGet 'Ninja-build.Ninja'
Install-WinGet 'Git.Git'
Install-WinGet 'Python.Python.3.12'
Install-WinGet 'Ccache.Ccache'

Write-Host "==> Visual Studio 2022 Build Tools (MSVC C++ + Windows SDK + Clang)"
# clang-cl.exe itself comes from LLVM.LLVM above; what it still NEEDS is the MSVC headers,
# CRT, and Windows SDK from the VCTools workload — the same pieces the msvc preset uses.
# Run unconditionally: if Build Tools (or full Visual Studio) is already present, winget just
# reports "already installed" and moves on — no harm.
$vsArgs = @(
  '--quiet', '--wait', '--norestart',
  '--add', 'Microsoft.VisualStudio.Workload.VCTools',
  '--add', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64',
  '--add', 'Microsoft.VisualStudio.Component.Windows11SDK.22621',
  '--add', 'Microsoft.VisualStudio.Component.VC.Llvm.Clang',       # VS-side clang-cl toolset
  '--add', 'Microsoft.VisualStudio.Component.VC.Llvm.ClangToolset',
  '--includeRecommended'
) -join ' '
winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --silent `
  --accept-package-agreements --accept-source-agreements --override "$vsArgs"
if ($LASTEXITCODE -ne 0) {
  Write-Warning "winget returned $LASTEXITCODE for VS Build Tools (commonly 'already installed' — harmless)."
  $global:LASTEXITCODE = 0
}

Write-Host "==> vcpkg (C:\vcpkg)"
if (-not (Test-Path 'C:\vcpkg')) {
  git clone https://github.com/microsoft/vcpkg.git C:\vcpkg
  & C:\vcpkg\bootstrap-vcpkg.bat -disableMetrics
}
[Environment]::SetEnvironmentVariable('VCPKG_ROOT', 'C:\vcpkg', 'User')

Write-Host ""
Write-Host "Done. clang-cl is provided by LLVM.LLVM; the MSVC headers + Windows SDK come from the"
Write-Host "VS Build Tools C++ workload installed above. Open a NEW terminal so PATH refreshes, then:"
Write-Host "  cmake --preset clang-cl-debug -D BUILD_TESTING=ON && cmake --build --preset clang-cl-debug"
Write-Host "  ctest --preset test-clang-cl-debug"
Write-Host "(Run these from a 'Developer PowerShell for VS 2022' so clang-cl finds the SDK and linker.)"
