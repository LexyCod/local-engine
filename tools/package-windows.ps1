param(
    [ValidateSet("debug", "release", "dev")]
    [string]$Configuration = "release",
    [string]$OutputDir = "dist\LocalEngine-windows"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$limeArgs = @("run", "lime", "build", "windows")
if ($Configuration -eq "debug") {
    $limeArgs += "-debug"
} elseif ($Configuration -eq "release") {
    $limeArgs += "-D"
    $limeArgs += "RELEASE_BUILD"
}

Write-Host "[Local Engine] Building Windows $Configuration..."
& haxelib @limeArgs

$buildFolder = if ($Configuration -eq "debug") {
    "export\debug\windows\bin"
} elseif ($Configuration -eq "dev") {
    "export\dev\windows\bin"
} else {
    "export\release\windows\bin"
}

if (!(Test-Path $buildFolder)) {
    throw "Build folder not found: $buildFolder"
}

if (Test-Path $OutputDir) {
    Remove-Item -LiteralPath $OutputDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$patterns = @("*.exe", "*.dll", "*.ndll", "*.manifest", "*.json", "*.txt")
foreach ($pattern in $patterns) {
    Get-ChildItem -Path $buildFolder -Filter $pattern -File -ErrorAction SilentlyContinue |
        Copy-Item -Destination $OutputDir -Force
}

foreach ($folder in @("assets", "content", "mods", "videos")) {
    $source = Join-Path $buildFolder $folder
    if (Test-Path $source) {
        Copy-Item -LiteralPath $source -Destination (Join-Path $OutputDir $folder) -Recurse -Force
    }
}

Write-Host "[Local Engine] Package ready: $OutputDir"
Write-Host "Put zip mods into '$OutputDir\content' or '$OutputDir\mods'."
