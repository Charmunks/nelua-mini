# C99 to C89 Converter for Nelua-generated code targeting TASKING cc88

param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,
    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

# ============================================================================
# Function to process a function body - must be defined first
# ============================================================================
function Process-FunctionBody {
    param([string]$header, [string[]]$bodyLines)
    
    $result = @()
    $result += $header
    
    $declarations = @()
    $statements = @()
    $sawStatement = $false
    $loopVarCounter = 0  # To make loop variables unique
    
    foreach ($line in $bodyLines) {
        $trimmed = $line.Trim()
        
        if ($trimmed -eq '' -or $trimmed -eq '{' -or $trimmed -eq '}') {
            $statements += $line
            continue
        }
        
        # Check if this is a declaration (type at start)
        # Include pointer types like nluint8_arr768_ptr, nluint8_ptr, etc.
        $isDecl = $trimmed -match '^(uint8_t|int8_t|uint16_t|int16_t|uint32_t|int32_t|pmhw_Fixed8_8|nluint8_arr768_ptr|nluint8_ptr)\s+(\w+)\s*(=\s*(.+))?;'
        
        if ($isDecl -and -not $sawStatement) {
            # Still in declaration section
            $statements += $line
        }
        elseif ($isDecl -and $sawStatement) {
            # Declaration after statement - extract decl, keep assignment
            $type = $matches[1]
            $varName = $matches[2]
            $hasInit = ($matches[3] -ne $null -and $matches[3] -ne '')
            $initExpr = if ($hasInit) { $matches[4] } else { $null }
            
            $lineIndent = $line -replace '^(\s*).*', '$1'
            $declarations += "$lineIndent$type $varName;"
            
            if ($hasInit) {
                $statements += "$lineIndent$varName = $initExpr;"
            }
        }
        else {
            $sawStatement = $true
            
            # Check for for-loop with multi-var declaration
            if ($trimmed -match '^for\s*\(\s*(int16_t|uint16_t|int8_t|uint8_t)\s+(\w+)\s*=\s*([^,;]+),\s*(\w+)\s*=\s*([^;]+);\s*([^;]+);\s*([^)]+)\)\s*\{') {
                $type = $matches[1]; $v1 = $matches[2]; $i1 = $matches[3].Trim()
                $v2 = $matches[4]; $i2 = $matches[5].Trim()
                $cond = $matches[6].Trim(); $incr = $matches[7].Trim()
                $lineIndent = $line -replace '^(\s*).*', '$1'
                
                # Make variable names unique if needed
                $newV1 = if ($v1 -eq '_end') { "_end$loopVarCounter" } else { $v1 }
                $newV2 = if ($v2 -eq '_end') { "_end$loopVarCounter" } else { $v2 }
                $loopVarCounter++
                
                # Update condition and increment to use new names
                $newCond = $cond -replace '\b_end\b', $newV2
                $newIncr = $incr
                
                $declarations += "$lineIndent$type $newV1;"
                $declarations += "$lineIndent$type $newV2;"
                $statements += "$lineIndent$newV1 = $i1;"
                $statements += "$lineIndent$newV2 = $i2;"
                $statements += "${lineIndent}for(; $newCond; $newIncr) {"
            }
            elseif ($trimmed -match '^for\s*\(\s*(uint16_t|int16_t|uint8_t|int8_t)\s+(\w+)\s*=\s*([^;]+);\s*([^;]+);\s*([^)]+)\)\s*\{') {
                $type = $matches[1]; $var = $matches[2]; $init = $matches[3].Trim()
                $cond = $matches[4].Trim(); $incr = $matches[5].Trim()
                $lineIndent = $line -replace '^(\s*).*', '$1'
                $declarations += "$lineIndent$type $var;"
                $statements += "$lineIndent$var = $init;"
                $statements += "${lineIndent}for(; $cond; $incr) {"
            }
            else {
                $statements += $line
            }
        }
    }
    
    # Insert declarations after opening brace
    if ($declarations.Count -gt 0) {
        $insertIdx = 0
        for ($j = 0; $j -lt $statements.Count; $j++) {
            if ($statements[$j].Trim() -eq '{') {
                $insertIdx = $j + 1
                break
            }
        }
        
        $newStatements = @()
        for ($j = 0; $j -lt $insertIdx; $j++) {
            $newStatements += $statements[$j]
        }
        $newStatements += $declarations
        for ($j = $insertIdx; $j -lt $statements.Count; $j++) {
            $newStatements += $statements[$j]
        }
        $statements = $newStatements
    }
    
    $result += $statements
    return $result
}

# ============================================================================
# Main script
# ============================================================================

$content = Get-Content $InputFile -Raw

# Find DECLARATIONS section
$declStart = $content.IndexOf("/* ------------------------------ DECLARATIONS")
if ($declStart -lt 0) {
    Write-Host "Could not find DECLARATIONS section" -ForegroundColor Red
    exit 1
}

$codeSection = $content.Substring($declStart)

# PASS 1: Simple text replacements
$codeSection = $codeSection -replace 'struct NELUA_MAYALIAS', 'struct'
$codeSection = $codeSection -replace 'union NELUA_MAYALIAS', 'union'
$codeSection = $codeSection -replace 'NELUA_STATIC_ASSERT\([^;]+;', ''
$codeSection = $codeSection -replace 'NELUA_INLINE ', ''
$codeSection = $codeSection -replace 'NELUA_NOINLINE ', ''
$codeSection = $codeSection -replace 'NELUA_LIKELY\(([^)]+)\)', '$1'
$codeSection = $codeSection -replace 'NELUA_UNLIKELY\(([^)]+)\)', '$1'
$codeSection = $codeSection -replace 'NELUA_ALIGNOF\([^)]+\)', '1'

# Designated initializers
$codeSection = $codeSection -replace '\{\.raw = ([^}]+)\}', '{$1}'
$codeSection = $codeSection -replace '\{\.v = \{([^}]+)\}\}', '{{$1}}'

# bool/true/false
$codeSection = $codeSection -replace '\bbool\b', 'int'
$codeSection = $codeSection -replace '\btrue\b', '1'
$codeSection = $codeSection -replace '\bfalse\b', '0'

# PASS 2: Compound literals
$codeSection = $codeSection -replace 'return \(pmhw_Fixed8_8\)\{([^}]+)\};', 'pmhw_Fixed8_8 _r; _r.raw = $1; return _r;'
$codeSection = $codeSection -replace '(pmhw_Fixed8_8)\s+(\w+)\s*=\s*\(pmhw_Fixed8_8\)\{([^}]+)\};', '$1 $2; $2.raw = $3;'
$codeSection = $codeSection -replace '(\w+\.\w+) = \(pmhw_Fixed8_8\)\{([^}]+)\};', '$1.raw = $2;'
$codeSection = $codeSection -replace '(\w+) = \(pmhw_Fixed8_8\)\{([^}]+)\};', '$1.raw = $2;'

# PASS 3: Process function by function
$lines = $codeSection -split "`r?`n"
$output = @()
$inFunction = $false
$braceDepth = 0
$funcLines = @()
$funcStartLine = ""

for ($i = 0; $i -lt $lines.Count; $i++) {
    $line = $lines[$i]
    $trimmed = $line.Trim()
    
    if (-not $inFunction) {
        if ($trimmed -match '^(static\s+)?(void|int|int16_t|uint8_t|pmhw_Fixed8_8)\s+\w+\s*\([^)]*\)\s*\{$') {
            $inFunction = $true
            $braceDepth = 1
            $funcStartLine = $line
            $funcLines = @()
            continue
        }
        $output += $line
    }
    else {
        $opens = ([regex]::Matches($line, '\{')).Count
        $closes = ([regex]::Matches($line, '\}')).Count
        $braceDepth += $opens - $closes
        
        if ($braceDepth -eq 0) {
            $funcLines += $line
            $processedFunc = Process-FunctionBody $funcStartLine $funcLines
            $output += $processedFunc
            $inFunction = $false
            $funcLines = @()
        }
        else {
            $funcLines += $line
        }
    }
}

$codeSection = $output -join "`r`n"

# PASS 4: Fix linkage - add static to all internal function definitions
# Match function definitions that are NOT "void main(" or "int main("
$codeSection = $codeSection -replace '(\r?\n)(pmhw_Fixed8_8|int16_t|int|void|uint8_t) ((?!main\()[a-zA-Z_]\w*)\s*\(', '$1static $2 $3('

# PASS 5: Build output
$finalOutput = @"
/* Generated for Pokemon Mini (TASKING cc88) */
/* Converted from Nelua C99 output to C89 */

/* Type definitions for S1C88 (16-bit int, 32-bit long) */
typedef unsigned char uint8_t;
typedef signed char int8_t;
typedef unsigned int uint16_t;
typedef signed int int16_t;
typedef unsigned long uint32_t;
typedef signed long int32_t;

$codeSection
"@

# Remove includes and preprocessor
$finalOutput = $finalOutput -replace '#include <stdint\.h>', '/* stdint types above */'
$finalOutput = $finalOutput -replace '#include <stdbool\.h>', '/* bool = int */'
$finalOutput = $finalOutput -replace '(?s)#if defined\(__clang__\).*?#endif', ''
$finalOutput = $finalOutput -replace '(?s)#if defined\(__GNUC__\).*?#endif', ''  
$finalOutput = $finalOutput -replace '(?s)#if defined\(_WIN32\).*?#endif', ''
$finalOutput = $finalOutput -replace '(?s)#if __STDC_VERSION__.*?#endif', ''
$finalOutput = $finalOutput -replace '(?s)#if !defined\(_FILE_OFFSET_BITS\).*?#endif', ''
$finalOutput = $finalOutput -replace '(?s)#if !defined\(_POSIX_C_SOURCE\).*?#endif', ''
$finalOutput = $finalOutput -replace '(?s)#ifdef __GNUC__.*?#endif', ''
$finalOutput = $finalOutput -replace '#define NELUA_\w+[^\r\n]*', ''
$finalOutput = $finalOutput -replace '(\r?\n){3,}', "`r`n`r`n"
$finalOutput = $finalOutput.Trim()

Set-Content -Path $OutputFile -Value $finalOutput -Encoding ASCII
Write-Host "Converted: $InputFile -> $OutputFile" -ForegroundColor Green
