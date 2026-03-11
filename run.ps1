# =============================================================================
# run.ps1 - Build and run ChatAgent using Qt MSVC kit + Visual Studio
# Usage: from project root, run .\run.ps1
# Requires: Qt with MSVC kit (e.g. msvc2022_64) including WebEngine; Visual Studio with C++
# Supported VS: 2019, 2022, 2025, 2026 (all support Windows 10). Install "Desktop development with C++".
# Optional: $env:QT_INSTALL_DIR = "C:\ProgramData\Qt\6.10.2\msvc2022_64"
# =============================================================================

$ErrorActionPreference = "Stop"

$ProjectRoot = $PSScriptRoot
if (-not $ProjectRoot) { $ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }
Set-Location $ProjectRoot

# Prefer Qt MSVC kit (msvc2022_64, msvc2019_64)
$QtDir = $env:QT_INSTALL_DIR
if (-not $QtDir) {
    $candidates = @(
        "C:\ProgramData\Qt\6.10.2\msvc2022_64",
        "C:\ProgramData\Qt\6.10.2\msvc2019_64",
        "C:\ProgramData\Qt\6.9.2\msvc2022_64",
        "C:\ProgramData\Qt\6.9.2\msvc2019_64",
        "C:\Qt\6.10.2\msvc2022_64",
        "C:\Qt\6.10.2\msvc2019_64",
        "C:\Qt\6.9.2\msvc2022_64",
        "C:\Qt\6.9.2\msvc2019_64",
        "$env:USERPROFILE\Qt\6.10.2\msvc2022_64",
        "$env:USERPROFILE\Qt\6.10.2\msvc2019_64"
    )
    foreach ($c in $candidates) {
        if (-not (Test-Path $c -PathType Container)) { continue }
        $bin = Join-Path $c "bin"
        $hasQt = (Test-Path (Join-Path $bin "Qt6Core.dll") -PathType Leaf) -or
                 (Test-Path (Join-Path $bin "qmake.exe") -PathType Leaf) -or
                 (Test-Path (Join-Path $c "lib\cmake\Qt6") -PathType Container)
        if (-not $hasQt -and (Test-Path $bin -PathType Container)) {
            $any = Get-ChildItem -Path $bin -Filter "Qt6*.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($any) { $hasQt = $true }
        }
        if ($hasQt) {
            $QtDir = $c
            break
        }
    }
}
if (-not $QtDir -or -not (Test-Path (Join-Path $QtDir "bin") -PathType Container)) {
    Write-Host "Qt MSVC kit not found. Install Qt with MSVC (e.g. msvc2022_64) and set QT_INSTALL_DIR, e.g.:" -ForegroundColor Yellow
    Write-Host '  $env:QT_INSTALL_DIR = "C:\ProgramData\Qt\6.10.2\msvc2022_64"' -ForegroundColor Cyan
    exit 1
}

# Check Qt WebEngine (required for Markdown/LaTeX rendering)
$qtWebEngineCmake = if ($QtDir) { Join-Path $QtDir "lib\cmake\Qt6WebEngineQuick\Qt6WebEngineQuickConfig.cmake" } else { $null }
$hasWebEngine = $qtWebEngineCmake -and (Test-Path -LiteralPath $qtWebEngineCmake -PathType Leaf)
if (-not $hasWebEngine) {
    Write-Host ""
    Write-Host "Error: Qt WebEngine (Qt6WebEngineQuick) not found in this Qt kit." -ForegroundColor Red
    Write-Host "Add 'Qt WebEngine' for the MSVC kit in Qt Maintenance Tool." -ForegroundColor Yellow
    Write-Host "Current Qt dir: $QtDir" -ForegroundColor Gray
    exit 1
}

# Find Visual Studio (vcvarsall.bat) via vswhere
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = $null
$vsGenerator = $null
if (Test-Path $vswhere -PathType Leaf) {
    $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($vsPath) {
        $vcvars = Join-Path $vsPath "VC\Auxiliary\Build\vcvarsall.bat"
        if (Test-Path $vcvars -PathType Leaf) {
            if ($vsPath -match "\\2026\\") { $vsGenerator = "Visual Studio 18 2026" }
            elseif ($vsPath -match "\\2025\\") { $vsGenerator = "Visual Studio 17 2025" }
            elseif ($vsPath -match "\\2022\\") { $vsGenerator = "Visual Studio 17 2022" }
            else { $vsGenerator = "Visual Studio 16 2019" }
        } else { $vsPath = $null }
    }
}
if (-not $vsPath) {
    Write-Host "Visual Studio (with C++ workload) not found." -ForegroundColor Red
    Write-Host "Install VS 2019, 2022, 2025, or 2026 with 'Desktop development with C++' (all support Windows 10)." -ForegroundColor Yellow
    exit 1
}
$vcvarsall = Join-Path $vsPath "VC\Auxiliary\Build\vcvarsall.bat"
Write-Host "Using Visual Studio: $vsPath"
Write-Host "Using CMake generator: $vsGenerator -A x64"

$BuildDir = "build"
$BuildPath = Join-Path $ProjectRoot $BuildDir
$ExeName = "appChatAgent"

Write-Host "========================================"
Write-Host "Building ChatAgent with Qt (MSVC)..."
Write-Host "  Qt: $QtDir"
Write-Host "========================================"

if (-not (Test-Path $BuildPath -PathType Container)) { New-Item -ItemType Directory -Path $BuildPath -Force | Out-Null }
Set-Location $BuildPath

$cmakeExe = "cmake"
$qtCmake = Join-Path $QtDir "bin\cmake.exe"
if (Test-Path $qtCmake -PathType Leaf) { $cmakeExe = $qtCmake }

# Clear cache if generator changed
$cache = Join-Path $BuildPath "CMakeCache.txt"
$cacheDir = Join-Path $BuildPath "CMakeFiles"
if (Test-Path $cache -PathType Leaf) {
    $content = Get-Content $cache -Raw -ErrorAction SilentlyContinue
    if ($content -and $content -notmatch "CMAKE_GENERATOR:INTERNAL=$([regex]::Escape($vsGenerator))") {
        Remove-Item $cache -Force -ErrorAction SilentlyContinue
        if (Test-Path $cacheDir -PathType Container) { Remove-Item $cacheDir -Recurse -Force -ErrorAction SilentlyContinue }
        Write-Host "Cleared old CMake cache, using generator: $vsGenerator"
    }
}

$NProc = $env:NUMBER_OF_PROCESSORS
if (-not $NProc) { $NProc = 4 }

# Configure and build in one CMD so vcvarsall env is used (paths quoted for spaces)
$buildCmd = "call `"$vcvarsall`" x64 && `"$cmakeExe`" -G `"$vsGenerator`" -A x64 -DCMAKE_PREFIX_PATH=`"$QtDir`" .. && `"$cmakeExe`" --build . --config Release --parallel $NProc"
Write-Host "Configuring and building..."
cmd /c $buildCmd
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Set-Location $ProjectRoot

# VS multi-config: exe in build\Release\
$ExePath = Join-Path (Join-Path (Join-Path $ProjectRoot $BuildDir) "Release") "$ExeName.exe"
if (-not (Test-Path $ExePath -PathType Leaf)) {
    $ExePath = Join-Path (Join-Path $ProjectRoot $BuildDir) "$ExeName.exe"
}
if (-not (Test-Path $ExePath -PathType Leaf)) {
    Write-Host "Executable not found: $ExePath" -ForegroundColor Red
    exit 1
}

Write-Host "Build succeeded, launching..."
Write-Host "========================================"

$env:PATH = "$QtDir\bin;$env:PATH"
$env:QT_PLUGIN_PATH = "$QtDir\plugins"
$env:QML2_IMPORT_PATH = "$QtDir\qml"

& $ExePath $args
