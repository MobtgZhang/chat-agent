Param(
    [string]$AppName = "ChatAgent",
    [string]$Version = "1.0.0",
    # Directory that already contains built binaries and resources (no source code)
    [string]$BuildOutputDir = ".\build\Release",
    # Packaging output root directory
    [string]$OutputRoot = ".\dist",
    # Main executable name (without path)
    [string]$MainExeName = "appChatAgent.exe",
    # Skip Qt deployment step
    [switch]$SkipQtDeploy,
    # Skip MSI generation
    [switch]$ZipOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-FullPath {
    param([string]$Path)
    return [System.IO.Path]::GetFullPath((Join-Path -Path (Get-Location) -ChildPath $Path))
}

$ProjectRoot    = Resolve-FullPath "."
$BuildOutputDir = Resolve-FullPath $BuildOutputDir
$OutputRoot     = Resolve-FullPath $OutputRoot

# ─── Validate build output ──────────────────────────────────────────────────
if (-not (Test-Path $BuildOutputDir)) {
    Write-Error "Build output directory does not exist: $BuildOutputDir`nPlease build the project first (e.g. cmake --build build --config Release)."
    exit 1
}

$MainExePath = Join-Path $BuildOutputDir $MainExeName
if (-not (Test-Path $MainExePath)) {
    Write-Error "Main executable not found: $MainExePath`nPlease build the project first."
    exit 1
}

Write-Host "Build output directory : $BuildOutputDir" -ForegroundColor DarkGray
Write-Host "Main executable        : $MainExePath"   -ForegroundColor DarkGray

# ─── Staging directories ────────────────────────────────────────────────────
$StagingRoot   = Join-Path $OutputRoot "staging"
$ZipOutputDir  = Join-Path $OutputRoot "zip"
$MsiOutputDir  = Join-Path $OutputRoot "msi"
$AppStagingDir = Join-Path $StagingRoot $AppName

Write-Host "Cleaning old packaging directories..." -ForegroundColor Cyan
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $StagingRoot, $ZipOutputDir, $MsiOutputDir

New-Item -ItemType Directory -Force -Path $AppStagingDir | Out-Null
New-Item -ItemType Directory -Force -Path $ZipOutputDir, $MsiOutputDir | Out-Null

Write-Host "Copying build output to staging directory..." -ForegroundColor Cyan
# Only copy the main executable (exclude test binaries)
Copy-Item -Path $MainExePath -Destination $AppStagingDir -Force

# ─── Qt deployment (windeployqt) ─────────────────────────────────────────────
if (-not $SkipQtDeploy) {
    # Detect Qt bin directory from CMakeCache.txt
    $cmakeCache = Join-Path $ProjectRoot "build\CMakeCache.txt"
    $qtBinDir   = $null

    if (Test-Path $cmakeCache) {
        $match = Select-String -Path $cmakeCache -Pattern "CMAKE_PREFIX_PATH[^=]*=(.+)" |
                 Select-Object -First 1
        if ($match) {
            $qtPrefix = $match.Matches[0].Groups[1].Value.Trim().Split(";")[0]
            $candidate = Join-Path $qtPrefix "bin"
            if (Test-Path (Join-Path $candidate "windeployqt.exe")) {
                $qtBinDir = $candidate
            }
        }
    }

    # Fallback: search common Qt installation paths
    if (-not $qtBinDir) {
        $searchRoots = @("C:\Qt", "C:\ProgramData\Qt", "$env:USERPROFILE\Qt")
        foreach ($root in $searchRoots) {
            $found = Get-ChildItem "$root\*\msvc*\bin\windeployqt.exe" -ErrorAction SilentlyContinue |
                     Sort-Object FullName -Descending | Select-Object -First 1
            if ($found) { $qtBinDir = $found.DirectoryName; break }
        }
    }

    $windeployqt = if ($qtBinDir) { Join-Path $qtBinDir "windeployqt.exe" } else { $null }

    if ($windeployqt -and (Test-Path $windeployqt)) {
        Write-Host "Running windeployqt to collect Qt dependencies..." -ForegroundColor Cyan
        $qmlSourceDir = Join-Path $ProjectRoot "src\qml"
        $stagedExe    = Join-Path $AppStagingDir $MainExeName
        $deployArgs   = @("--release", "--no-translations", $stagedExe)
        if (Test-Path $qmlSourceDir) {
            $deployArgs = @("--release", "--no-translations", "--qmldir", $qmlSourceDir, $stagedExe)
        }
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        & $windeployqt @deployArgs 2>&1 | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                Write-Warning "windeployqt: $($_.Exception.Message)"
            } else {
                Write-Host $_
            }
        }
        $ErrorActionPreference = $prevEAP
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "windeployqt exited with code $LASTEXITCODE — packaging will continue."
        }
    } else {
        Write-Warning "windeployqt not found. Qt runtime DLLs will NOT be included in the package."
    }
}

# ─── ZIP package ────────────────────────────────────────────────────────────
$zipName = "$AppName-$Version.zip"
$zipPath = Join-Path $ZipOutputDir $zipName
Write-Host "Creating ZIP package: $zipPath" -ForegroundColor Cyan
Compress-Archive -Path (Join-Path $AppStagingDir "*") -DestinationPath $zipPath -Force
Write-Host "ZIP created: $zipPath" -ForegroundColor Green

if ($ZipOnly) {
    Write-Host "Packaging finished (ZIP only, -ZipOnly flag set)." -ForegroundColor Green
    exit 0
}

# ─── Locate / auto-download WiX v3 toolset ──────────────────────────────────
function Get-WixTool {
    param([string]$ToolName, [string]$LocalDir)

    # 1. Already on PATH or %WIX%
    $cmd = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($null -ne $cmd) { return $cmd.Source }

    if ($env:WIX) {
        $c = Join-Path $env:WIX "bin\$ToolName"
        if (Test-Path $c) { return $c }
    }

    # 2. Common install locations
    foreach ($base in @("C:\Program Files (x86)\WiX Toolset*", "C:\Program Files\WiX Toolset*")) {
        $c = Get-Item "$base\bin\$ToolName" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c) { return $c.FullName }
    }

    # 3. Local cache downloaded by this script
    if ($LocalDir) {
        $c = Join-Path $LocalDir $ToolName
        if (Test-Path $c) { return $c }
    }

    return $null
}

$WixLocalDir = Join-Path $OutputRoot "wix-tools"
$heat   = Get-WixTool "heat.exe"   $WixLocalDir
$candle = Get-WixTool "candle.exe" $WixLocalDir
$light  = Get-WixTool "light.exe"  $WixLocalDir

if (-not $heat -or -not $candle -or -not $light) {
    Write-Host "WiX toolset not found locally. Downloading WiX v3 portable binaries from GitHub..." -ForegroundColor Yellow

    $wixZipUrl  = "https://github.com/wixtoolset/wix3/releases/download/wix3141rtm/wix314-binaries.zip"
    $wixZipTemp = Join-Path $env:TEMP "wix314-binaries.zip"

    try {
        Write-Host "  Downloading $wixZipUrl ..." -ForegroundColor DarkGray
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $wixZipUrl -OutFile $wixZipTemp -UseBasicParsing
        Write-Host "  Extracting to $WixLocalDir ..." -ForegroundColor DarkGray
        New-Item -ItemType Directory -Force -Path $WixLocalDir | Out-Null
        Expand-Archive -Path $wixZipTemp -DestinationPath $WixLocalDir -Force
        Remove-Item $wixZipTemp -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Warning "Failed to download WiX: $_"
        Write-Warning "Only ZIP package will be available. Install WiX Toolset from https://wixtoolset.org to enable MSI generation."
        Write-Host "Packaging finished (ZIP only)." -ForegroundColor Green
        Write-Host "ZIP path: $zipPath"
        exit 0
    }

    $heat   = Get-WixTool "heat.exe"   $WixLocalDir
    $candle = Get-WixTool "candle.exe" $WixLocalDir
    $light  = Get-WixTool "light.exe"  $WixLocalDir

    if (-not $heat -or -not $candle -or -not $light) {
        Write-Warning "WiX tools still not found after download. Only ZIP will be created."
        Write-Host "Packaging finished (ZIP only)." -ForegroundColor Green
        Write-Host "ZIP path: $zipPath"
        exit 0
    }
}

Write-Host "Using WiX tools:" -ForegroundColor DarkGray
Write-Host "  heat  : $heat"   -ForegroundColor DarkGray
Write-Host "  candle: $candle" -ForegroundColor DarkGray
Write-Host "  light : $light"  -ForegroundColor DarkGray

# ─── Generate MSI with WiX ──────────────────────────────────────────────────
$WixWorkDir    = Join-Path $OutputRoot "wix"
New-Item -ItemType Directory -Force -Path $WixWorkDir | Out-Null

$wxsFragments  = Join-Path $WixWorkDir "AppFiles.wxs"
$wxsProduct    = Join-Path $WixWorkDir "Product.wxs"
$wixobjFrag    = [System.IO.Path]::ChangeExtension($wxsFragments, ".wixobj")
$wixobjProd    = [System.IO.Path]::ChangeExtension($wxsProduct,   ".wixobj")
$msiName       = "$AppName-$Version.msi"
$msiPath       = Join-Path $MsiOutputDir $msiName

# Step 1: harvest directory into a component-group fragment
Write-Host "Running heat.exe to harvest directory structure..." -ForegroundColor Cyan
& $heat dir $AppStagingDir `
    -dr   APPLICATIONFOLDER `
    -cg   AppComponents `
    -gg   `
    -srd  `
    -sreg `
    -var  var.SourceDir `
    -out  $wxsFragments
if ($LASTEXITCODE -ne 0) { Write-Error "heat.exe failed with exit code $LASTEXITCODE"; exit 1 }

# Step 2: write a hand-crafted Product.wxs
#   UpgradeCode is a fixed GUID so upgrades detect and replace the previous version.
$upgradeGuid = "A1B2C3D4-E5F6-7890-ABCD-EF1234567890"

@"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi"
     xmlns:ui="http://schemas.microsoft.com/wix/UIExtension">

  <Product Id="*"
           Name="$AppName"
           Language="1033"
           Version="$Version"
           Manufacturer="$AppName"
           UpgradeCode="{$upgradeGuid}">

    <Package InstallerVersion="301"
             Compressed="yes"
             InstallScope="perMachine"
             Description="$AppName $Version Installer" />

    <MajorUpgrade DowngradeErrorMessage="A newer version of [`$ProductName] is already installed." />
    <MediaTemplate EmbedCab="yes" />

    <Property Id="WIXUI_INSTALLDIR" Value="APPLICATIONFOLDER" />
    <UIRef Id="WixUI_InstallDir" />

    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFilesFolder">
        <Directory Id="APPLICATIONFOLDER" Name="$AppName" />
      </Directory>
      <Directory Id="ProgramMenuFolder">
        <Directory Id="ApplicationProgramsFolder" Name="$AppName" />
      </Directory>
    </Directory>

    <DirectoryRef Id="ApplicationProgramsFolder">
      <Component Id="ApplicationShortcuts" Guid="*">
        <Shortcut Id="ApplicationStartMenuShortcut"
                  Name="$AppName"
                  Description="$AppName"
                  Target="[APPLICATIONFOLDER]$MainExeName"
                  WorkingDirectory="APPLICATIONFOLDER" />
        <RemoveFolder Id="CleanUpShortCut" On="uninstall" />
        <RegistryValue Root="HKCU"
                       Key="Software\$AppName"
                       Name="installed"
                       Type="integer"
                       Value="1"
                       KeyPath="yes" />
      </Component>
    </DirectoryRef>

    <Feature Id="ProductFeature" Title="$AppName" Level="1">
      <ComponentGroupRef Id="AppComponents" />
      <ComponentRef Id="ApplicationShortcuts" />
    </Feature>

  </Product>
</Wix>
"@ | Set-Content -Path $wxsProduct -Encoding UTF8

# Step 3: compile both WXS files
Write-Host "Running candle.exe to compile WXS files..." -ForegroundColor Cyan
& $candle `
    "-dSourceDir=$AppStagingDir" `
    -out "$WixWorkDir\" `
    $wxsFragments `
    $wxsProduct
if ($LASTEXITCODE -ne 0) { Write-Error "candle.exe failed with exit code $LASTEXITCODE"; exit 1 }

# Step 4: link into MSI
Write-Host "Running light.exe to link MSI..." -ForegroundColor Cyan
& $light `
    -ext WixUIExtension `
    -ext WixUtilExtension `
    -cultures:en-US `
    -out $msiPath `
    $wixobjFrag `
    $wixobjProd
if ($LASTEXITCODE -ne 0) { Write-Error "light.exe failed with exit code $LASTEXITCODE"; exit 1 }

Write-Host "Packaging finished." -ForegroundColor Green
Write-Host "ZIP path: $zipPath"
Write-Host "MSI path: $msiPath"
