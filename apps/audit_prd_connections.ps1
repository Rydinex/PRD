$ErrorActionPreference = "Stop"
$root = "C:\\Rydinex\\PRD"
$codeFiles = Get-ChildItem -Path $root -Filter code.html -Recurse | Where-Object { $_.FullName -notlike "*\\apps\\*" }

function Get-WorkspaceRelative([string]$path) {
  $full = (Resolve-Path $path).Path
  $rootFull = (Resolve-Path $root).Path
  $trimmed = $full.Substring($rootFull.Length).TrimStart('\')
  return $trimmed.Replace('\', '/')
}

function Get-ExpectedPrefix([string]$relPath) {
  $segments = $relPath.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
  $depth = $segments.Count - 1
  $prefix = ""
  for ($i = 0; $i -lt $depth; $i++) { $prefix += "../" }
  return $prefix
}

$issues = @()
$relSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($f in $codeFiles) {
  $rel = Get-WorkspaceRelative $f.FullName
  $null = $relSet.Add($rel)
  $expected = Get-ExpectedPrefix $rel
  $content = Get-Content -Path $f.FullName -Raw

  $m1 = ('<script src="{0}apps/prd-manifest.js"></script>' -f $expected)
  $m2 = ('<script src="{0}apps/prd-runtime.js"></script>' -f $expected)

  if ($content -notlike "*${m1}*") { $issues += "Missing/incorrect manifest script: $rel" }
  if ($content -notlike "*${m2}*") { $issues += "Missing/incorrect runtime script: $rel" }
}

$manifestPath = Join-Path $root "apps\prd-manifest.js"
$manifestContent = Get-Content -Path $manifestPath -Raw
$manifestJson = ($manifestContent -replace '^\s*window\.PRD_MANIFEST\s*=\s*', '' -replace ';\s*$', '')
$manifestObj = $manifestJson | ConvertFrom-Json
$manifestFiles = @()
$manifestObj.apps.rider | ForEach-Object { $manifestFiles += $_ }
$manifestObj.apps.driver | ForEach-Object { $manifestFiles += $_ }
$manifestObj.apps.admin | ForEach-Object { $manifestFiles += $_ }

$dupManifest = $manifestFiles | Group-Object | Where-Object { $_.Count -gt 1 } | Select-Object -ExpandProperty Name
foreach ($d in $dupManifest) { $issues += "Duplicate in manifest: $d" }

$manifestSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$manifestFiles | ForEach-Object { $null = $manifestSet.Add($_) }

foreach ($rel in $relSet) {
  if (-not $manifestSet.Contains($rel)) { $issues += "Screen missing from manifest: $rel" }
}
foreach ($m in $manifestSet) {
  if (-not $relSet.Contains($m)) { $issues += "Manifest references missing screen: $m" }
}

$hubSpecs = @(
  @{ path = "apps/rider/index.html"; items = $manifestObj.apps.rider; app = "rider" },
  @{ path = "apps/driver/index.html"; items = $manifestObj.apps.driver; app = "driver" },
  @{ path = "apps/admin/index.html"; items = $manifestObj.apps.admin; app = "admin" }
)

foreach ($spec in $hubSpecs) {
  $hubPath = Join-Path $root $spec.path
  if (-not (Test-Path $hubPath)) { $issues += "Missing hub file: $($spec.path)"; continue }
  $hubContent = Get-Content -Path $hubPath -Raw
  foreach ($item in $spec.items) {
    $expectedLink = "../../${item}?app=$($spec.app)"
    if ($hubContent -notmatch [regex]::Escape($expectedLink)) { $issues += "Hub missing link ($($spec.path)): $item" }
  }
}

Write-Output ("Screens total: " + $codeFiles.Count)
Write-Output ("Manifest total: " + $manifestFiles.Count)
Write-Output ("Rider: " + $manifestObj.apps.rider.Count + ", Driver: " + $manifestObj.apps.driver.Count + ", Admin: " + $manifestObj.apps.admin.Count)
Write-Output ("Issues: " + $issues.Count)
if ($issues.Count -gt 0) {
  Write-Output "--- Sample issues ---"
  $issues | Select-Object -First 100
}
