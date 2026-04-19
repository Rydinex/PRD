$ErrorActionPreference = "Stop"
$root = "C:\\Rydinex\\PRD"

function Get-WorkspaceRelative([string]$path) {
  $full = (Resolve-Path $path).Path
  $rootFull = (Resolve-Path $root).Path
  $trimmed = $full.Substring($rootFull.Length).TrimStart('\')
  return $trimmed.Replace('\', '/')
}

function Detect-AppFromPath([string]$path) {
  $p = ($path | ForEach-Object { $_.ToLowerInvariant() })

  if (
    $p.Contains("admin") -or
    $p.Contains("security_") -or
    $p.Contains("access_") -or
    $p.Contains("regulatory_") -or
    $p.Contains("wizard") -or
    $p.Contains("state_launch") -or
    $p.Contains("market_research") -or
    $p.Contains("expansion_roadmap") -or
    $p.Contains("user_management") -or
    $p.Contains("role_permissions") -or
    $p.Contains("system_") -or
    $p.Contains("onboarding_") -or
    $p.Contains("vehicle_eligibility") -or
    $p.Contains("tnp_financial")
  ) {
    return "admin"
  }

  if (
    $p.Contains("driver") -or
    $p.Contains("earnings_summary") -or
    $p.Contains("incoming_request") -or
    $p.Contains("vehicle_audit") -or
    $p.Contains("incident") -or
    $p.Contains("report_category") -or
    $p.Contains("report_confirmation")
  ) {
    return "driver"
  }

  return "rider"
}

$manifestPath = Join-Path $root "apps\prd-manifest.js"
$manifestContent = Get-Content -Path $manifestPath -Raw
$manifestJson = ($manifestContent -replace '^\s*window\.PRD_MANIFEST\s*=\s*', '' -replace ';\s*$', '')
$manifestObj = $manifestJson | ConvertFrom-Json

$appMap = @{
  rider = @($manifestObj.apps.rider)
  driver = @($manifestObj.apps.driver)
  admin = @($manifestObj.apps.admin)
}

$allFiles = Get-ChildItem -Path $root -Filter code.html -Recurse | Where-Object { $_.FullName -notlike "*\\apps\\*" }
$contentMap = @{}
foreach ($f in $allFiles) {
  $rel = Get-WorkspaceRelative $f.FullName
  $contentMap[$rel] = (Get-Content -Path $f.FullName -Raw)
}

$issues = @()
$checks = [ordered]@{
  totalScreens = 0
  forwardIntentScreens = 0
  backIntentScreens = 0
  formScreens = 0
  placeholderLinkScreens = 0
  appDetectMismatches = 0
}

foreach ($app in @("rider", "driver", "admin")) {
  $list = $appMap[$app]
  $count = $list.Count

  for ($i = 0; $i -lt $count; $i++) {
    $path = $list[$i]
    $checks.totalScreens++

    if (-not $contentMap.ContainsKey($path)) {
      $issues += "Manifest path does not exist: [$app] $path"
      continue
    }

    $content = $contentMap[$path]
    $lc = $content.ToLowerInvariant()

    $hasForwardIntent = [regex]::IsMatch($lc, '(next|continue|proceed|book|request|confirm|approve|reject|submit|save|done|start|go\b|online|offline)')
    $hasBackIntent = [regex]::IsMatch($lc, '(back|previous|cancel|close)')
    $hasForm = $lc.Contains('<form')
    $hasPlaceholderLink = [regex]::IsMatch($lc, 'href\s*=\s*"#"|href\s*=\s*""')

    if ($hasForwardIntent) { $checks.forwardIntentScreens++ }
    if ($hasBackIntent) { $checks.backIntentScreens++ }
    if ($hasForm) { $checks.formScreens++ }
    if ($hasPlaceholderLink) { $checks.placeholderLinkScreens++ }

    if (($hasForwardIntent -or $hasForm -or $hasPlaceholderLink) -and $count -lt 2) {
      $issues += "No next target available for interactive screen: [$app] $path"
    }

    if ($hasBackIntent -and $count -lt 2) {
      $issues += "No previous target available for back/cancel screen: [$app] $path"
    }

    $detected = Detect-AppFromPath $path
    if ($detected -ne $app) {
      $checks.appDetectMismatches++
      $issues += "Runtime app-detect mismatch: path '$path' bucketed as '$app' but detectApp -> '$detected'"
    }

    if ($count -ge 2) {
      $nextIndex = ($i + 1) % $count
      $prevIndex = ($i - 1 + $count) % $count
      if ([string]::IsNullOrWhiteSpace($list[$nextIndex]) -or [string]::IsNullOrWhiteSpace($list[$prevIndex])) {
        $issues += "Broken prev/next index mapping: [$app] $path"
      }
    }
  }
}

Write-Output ("Flow audit screens: " + $checks.totalScreens)
Write-Output ("Forward-intent screens: " + $checks.forwardIntentScreens)
Write-Output ("Back-intent screens: " + $checks.backIntentScreens)
Write-Output ("Form screens: " + $checks.formScreens)
Write-Output ("Placeholder-link screens: " + $checks.placeholderLinkScreens)
Write-Output ("Runtime detect mismatches: " + $checks.appDetectMismatches)
Write-Output ("Issues: " + $issues.Count)

if ($issues.Count -gt 0) {
  Write-Output "--- Sample issues ---"
  $issues | Select-Object -First 120
}
