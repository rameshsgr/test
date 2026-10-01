[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$InputPattern,

    [Parameter(Position = 1)]
    [string]$OutputFile,

    [switch]$Force
)

# Strip stray surrounding quotes (e.g. when typed at an interactive prompt).
$InputPattern = $InputPattern.Trim().Trim('"', "'")

# Accept either the base name (file.zip) or a part name (file.zip.001).
if ($InputPattern -match '^(?<base>.+)\.\d{3,}$') {
    $InputPattern = $Matches['base']
}

$directory = Split-Path -Path $InputPattern -Parent
if (-not $directory) { $directory = '.' }
$baseName = Split-Path -Path $InputPattern -Leaf

$parts = Get-ChildItem -LiteralPath $directory -File |
    Where-Object { $_.Name -match ('^' + [regex]::Escape($baseName) + '\.(\d{3,})$') } |
    Sort-Object { [int]($_.Name -replace '.*\.(\d+)$', '$1') }

if (-not $parts) {
    throw "No chunk files found matching '$baseName.NNN' in '$directory'."
}

if (-not $OutputFile) {
    $OutputFile = Join-Path $directory $baseName
}

if ((Test-Path -LiteralPath $OutputFile) -and -not $Force) {
    throw "Output file already exists: $OutputFile. Use -Force to overwrite."
}

$outStream = [System.IO.File]::Create($OutputFile)
try {
    $buffer = New-Object byte[] (1MB)
    foreach ($part in $parts) {
        $inStream = [System.IO.File]::OpenRead($part.FullName)
        try {
            while (($read = $inStream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $outStream.Write($buffer, 0, $read)
            }
        }
        finally {
            $inStream.Dispose()
        }
        Write-Host ("Merged {0} ({1:N0} bytes)" -f $part.Name, $part.Length)
    }
}
finally {
    $outStream.Dispose()
}

$totalSize = (Get-Item -LiteralPath $OutputFile).Length
Write-Host ("Done. Reassembled {0} part(s) into '{1}' ({2:N0} bytes)." -f $parts.Count, $OutputFile, $totalSize)
