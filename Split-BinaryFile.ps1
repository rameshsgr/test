[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$FileName,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$ChunkSize,

    [Parameter(Position = 2)]
    [string]$OutputDirectory
)

# Convert a human-friendly size (e.g. 10MB, 512KB, 1048576) into bytes.
function ConvertTo-Bytes {
    param([string]$Size)

    $Size = $Size.Trim()
    if ($Size -match '^(?<num>[\d\.]+)\s*(?<unit>KB|MB|GB|B)?$') {
        $num = [double]$Matches['num']
        switch ($Matches['unit']) {
            'KB'    { return [long]($num * 1KB) }
            'MB'    { return [long]($num * 1MB) }
            'GB'    { return [long]($num * 1GB) }
            default { return [long]$num }
        }
    }
    throw "Invalid chunk size '$Size'. Use a number optionally suffixed with KB, MB, or GB."
}

# Strip stray surrounding quotes (e.g. when typed at an interactive prompt).
$FileName = $FileName.Trim().Trim('"', "'")

$resolved = Resolve-Path -LiteralPath $FileName -ErrorAction Stop
$FileName = $resolved.Path

if (-not (Test-Path -LiteralPath $FileName -PathType Leaf)) {
    throw "File not found: $FileName"
}

$chunkBytes = ConvertTo-Bytes $ChunkSize
if ($chunkBytes -le 0) {
    throw "Chunk size must be greater than zero."
}

if (-not $OutputDirectory) {
    $OutputDirectory = Split-Path -Path $FileName -Parent
}
if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$baseName = Split-Path -Path $FileName -Leaf
$totalSize = (Get-Item -LiteralPath $FileName).Length
$partIndex = 0

$inStream = [System.IO.File]::OpenRead($FileName)
try {
    $buffer = New-Object byte[] $chunkBytes
    while (($read = $inStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $partIndex++
        $partName = '{0}.{1:D3}' -f $baseName, $partIndex
        $partPath = Join-Path $OutputDirectory $partName

        $outStream = [System.IO.File]::Create($partPath)
        try {
            $outStream.Write($buffer, 0, $read)
        }
        finally {
            $outStream.Dispose()
        }

        Write-Host ("Created {0} ({1:N0} bytes)" -f $partName, $read)
    }
}
finally {
    $inStream.Dispose()
}

Write-Host ("Done. Split {0} ({1:N0} bytes) into {2} chunk(s) in '{3}'." -f $baseName, $totalSize, $partIndex, $OutputDirectory)
