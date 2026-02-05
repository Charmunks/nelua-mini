param(
    [Parameter(Position=0)]
    [ValidateSet("all", "clean", "c-only", "rebuild", "run", "asm-only")]
    [string]$Target = "all"
)

$ExampleDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ToolsDir = Join-Path (Split-Path -Parent (Split-Path -Parent $ExampleDir)) "tools"

& "$ToolsDir\build.ps1" -Target $Target -Source "$ExampleDir\main.nelua"
