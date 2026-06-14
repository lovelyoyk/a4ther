# build-zip.ps1 — gera o ZIP de deploy do scanner A4ther A PARTIR deste repo.
# A versão é lida do próprio index.html (const VERSION), então o nome do zip
# acompanha o código. Uso:
#   powershell -ExecutionPolicy Bypass -File .\build-zip.ps1
# Saída: ..\a4ther-scanner-v<VERSION>.zip  (na pasta pai, ex: Downloads)
param(
  [string]$Root   = $PSScriptRoot,
  [string]$OutDir = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$idx = [System.IO.File]::ReadAllText((Join-Path $Root 'index.html'))
$m   = [regex]::Match($idx, 'const VERSION = "([^"]+)"')
$ver = if ($m.Success) { $m.Groups[1].Value } else { 'unknown' }

# arquivos do deploy WEB (flat na raiz do zip)
$files = @(
  'index.html', 'service-worker.js', 'manifest.webmanifest',
  'icon.svg', 'apple-touch-icon.png', 'icon-192.png', 'icon-512.png'
)

$dest = Join-Path $OutDir "a4ther-scanner-v$ver.zip"
if (Test-Path $dest) { Remove-Item $dest -Force }

$fs  = [System.IO.File]::Open($dest, [System.IO.FileMode]::Create)
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($f in $files) {
    $p = Join-Path $Root $f
    if (-not (Test-Path $p)) { throw "arquivo de deploy faltando: $f" }
    [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
      $zip, $p, $f, [System.IO.Compression.CompressionLevel]::Optimal)
  }
} finally {
  $zip.Dispose(); $fs.Dispose()
}

$kb = [math]::Round((Get-Item $dest).Length / 1KB, 1)
Write-Host "OK  ->  $dest"
Write-Host "    versao v$ver | $($files.Count) arquivos | $kb KB"
