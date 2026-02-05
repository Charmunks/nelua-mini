# Pokemon Mini Homebrew Build Script (PowerShell)
# Toolchain: Nelua -> C -> cc88 -> lk88 -> lc88 -> srec_cat -> .min
# Run from project root: .\tools\build.ps1 [target]

param(
    [Parameter(Position=0)]
    [ValidateSet("all", "clean", "c-only", "rebuild", "run", "asm-only")]
    [string]$Target = "all",

    [string]$Source = ""
)

# Resolve project root (one level up from tools/)
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Push-Location $ProjectRoot

# Determine source file and project name
if ($Source -eq "") {
    $NeluaSource = "examples\demo\main.nelua"
    $Project = "demo"
} else {
    if ([System.IO.Path]::IsPathRooted($Source)) {
        $NeluaSource = [System.IO.Path]::GetRelativePath($ProjectRoot, $Source)
    } else {
        $NeluaSource = $Source
    }
    $Project = [System.IO.Path]::GetFileNameWithoutExtension($NeluaSource)
}

# Project settings
$CSources = "build\main_c89.c"
$AsmSources = "toolchain\crt0.asm"

# Paths
$BuildDir = "build"
$C88Dir = "C:\Users\isaac\c88-pokemini\c88tools"
$DescFile = "$C88Dir\etc\pokemini.dsc"

# Output files
$ObjFiles = @()
$SrecOutput = "$BuildDir\$Project.sre"
$OutFile = "$BuildDir\$Project.out"
$RomOutput = "$BuildDir\$Project.min"

# Toolchain
$CC88 = "cc88"
$AS88 = "as88"
$LK88 = "lk88"
$LC88 = "lc88"
$SREC_CAT = "$C88Dir\bin\srec_cat.exe"

function Ensure-BuildDir {
    if (-not (Test-Path $BuildDir)) {
        New-Item -ItemType Directory -Path $BuildDir | Out-Null
    }
}

function Build-Asm {
    param([string]$Source)
    $ObjFile = "$BuildDir\$([System.IO.Path]::GetFileNameWithoutExtension($Source)).o"
    Write-Host "[AS88] Assembling $Source..." -ForegroundColor Cyan
    & $AS88 -o $ObjFile $Source 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Assembly failed!" -ForegroundColor Red
        exit 1
    }
    return $ObjFile
}

function Build-C {
    param([string]$Source)
    $ObjFile = "$BuildDir\$([System.IO.Path]::GetFileNameWithoutExtension($Source)).o"
    Write-Host "[CC88] Compiling $Source..." -ForegroundColor Cyan
    & $CC88 -c -o $ObjFile $Source 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Compilation failed!" -ForegroundColor Red
        exit 1
    }
    return $ObjFile
}

function Link-Objects {
    param([string[]]$Objects)
    Write-Host "[LK88] Linking..." -ForegroundColor Cyan
    $libPath = "$C88Dir\lib"
    # Link with -lrts but our crt0 provides __START first
    # The linker should use our __START instead of the library's
    & $LK88 -o $OutFile $Objects -L"$libPath" -lrts 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Linking failed!" -ForegroundColor Red
        exit 1
    }
}

function Locate-Output {
    Write-Host "[LC88] Locating..." -ForegroundColor Cyan
    & $LC88 -f2 -o $SrecOutput -d"$DescFile" $OutFile 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Locating failed!" -ForegroundColor Red
        exit 1
    }
}

function Convert-ToMin {
    Write-Host "[SREC] Converting to .min ROM..." -ForegroundColor Cyan
    # Pokemon Mini ROM format:
    # - File must start with zeros from 0x0000 to 0x20FF
    # - ROM header starts at file offset 0x2100 (memory address 0x2100)
    # - Fill unused space with 0xFF, pad to 64KB
    & $SREC_CAT $SrecOutput -fill 0x00 0x0000 0x2100 -fill 0xFF 0x2100 0x10000 -o $RomOutput -binary 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Conversion failed!" -ForegroundColor Red
        exit 1
    }
    
    $size = (Get-Item $RomOutput).Length
    Write-Host ""
    Write-Host "Build complete: $RomOutput" -ForegroundColor Green
    Write-Host "ROM size: $size bytes" -ForegroundColor Yellow
}

function Clean {
    if (Test-Path $BuildDir) {
        Remove-Item -Recurse -Force $BuildDir
    }
    Write-Host "Cleaned." -ForegroundColor Green
}

function Build-Nelua {
    Write-Host "[NELUA] Compiling $NeluaSource to C..." -ForegroundColor Cyan
    $neluaOutput = "$BuildDir\main_nelua.c"
    & nelua --generator c -L src --output $neluaOutput $NeluaSource 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Nelua compilation failed!" -ForegroundColor Red
        exit 1
    }
    
    # Convert C99 to C89
    Write-Host "[C99->C89] Converting to C89..." -ForegroundColor Cyan
    & "$ScriptDir\c99_to_c89.ps1" -InputFile $neluaOutput -OutputFile $CSources
    if ($LASTEXITCODE -ne 0) {
        Write-Host "C99 to C89 conversion failed!" -ForegroundColor Red
        exit 1
    }
}

function Build-All {
    Ensure-BuildDir
    
    # Build Nelua to C89
    Build-Nelua
    
    # Build assembly files
    $crt0Obj = Build-Asm $AsmSources
    
    # Build C files
    $mainObj = Build-C $CSources
    
    # Link
    Link-Objects @($crt0Obj, $mainObj)
    
    # Locate
    Locate-Output
    
    # Convert to .min
    Convert-ToMin
}

# Main
switch ($Target) {
    "all" {
        Build-All
    }
    "asm-only" {
        Ensure-BuildDir
        Build-Asm $AsmSources
        Write-Host "Assembly complete." -ForegroundColor Green
    }
    "c-only" {
        Ensure-BuildDir
        Build-C $CSources
        Write-Host "C compilation complete." -ForegroundColor Green
    }
    "clean" {
        Clean
    }
    "rebuild" {
        Clean
        Build-All
    }
    "run" {
        if (-not (Test-Path $RomOutput)) {
            Write-Host "ROM not found. Building first..." -ForegroundColor Yellow
            Build-All
        }
        Write-Host "Running in emulator..." -ForegroundColor Cyan
        Start-Process pokemini -ArgumentList $RomOutput
    }
}

Pop-Location
