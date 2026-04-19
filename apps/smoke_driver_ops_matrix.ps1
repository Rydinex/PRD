$ErrorActionPreference = "Stop"
$root = "C:\\Rydinex\\PRD"

$targets = @(
  "rydinex_driver_airport_intel/code.html",
  "rydinex_driver_airport_queues_1/code.html",
  "rydinex_driver_airport_queues_2/code.html",
  "rydinex_driver_airport_queues_3/code.html",
  "rydinex_driver_airport_staging_tracking/code.html",
  "rydinex_driver_city_event_hub_1/code.html",
  "rydinex_driver_city_event_hub_2/code.html",
  "rydinex_driver_city_event_hub_3/code.html",
  "rydinex_driver_city_event_hub_refined_surge/code.html",
  "rydinex_driver_city_event_hub_updated_surge/code.html",
  "rydinex_driver_event_hub_mccormick_place/code.html",
  "rydinex_driver_event_hub_refined_surge/code.html",
  "rydinex_driver_event_hub_updated_surge/code.html",
  "rydinex_driver_queue_next_3_alert/code.html",
  "rydinex_driver_queue_position_tracker_1/code.html",
  "rydinex_driver_queue_position_tracker_2/code.html",
  "rydinex_driver_queue_position_tracker_3/code.html",
  "rydinex_driver_queue_status_break_mode/code.html",
  "rydinex_driver_short_trip_priority_refined/code.html"
)

$runtimePath = Join-Path $root "apps/prd-runtime.js"
$runtime = Get-Content -Path $runtimePath -Raw

$runtimeChecks = [ordered]@{
  hasNativeWire = $runtime.Contains("function wireDriverNativeControls()")
  hasCheckTracking = $runtime.Contains("data-prd-action") -and $runtime.Contains("check-tracking")
  hasRemoveGroup = $runtime.Contains("remove-queue-group")
  hasSaveRules = $runtime.Contains("save-state-rules")
  hasVerifyChauffeur = $runtime.Contains("verify-chauffeur")
  hasOrd = $runtime.Contains("41.9742, -87.9073")
  hasMdw = $runtime.Contains("41.7868, -87.7522")
}

$rows = @()
foreach ($rel in $targets) {
  $path = Join-Path $root $rel
  if (-not (Test-Path $path)) {
    $rows += [pscustomobject]@{
      file = $rel
      exists = "FAIL"
      opsCard = "FAIL"
      queueGroup = "FAIL"
      checkTracking = "FAIL"
      removeQueueGroup = "FAIL"
      saveStateRules = "FAIL"
      verifyChauffeur = "FAIL"
      ordCoord = "FAIL"
      mdwCoord = "FAIL"
      black = "FAIL"
      blackSuv = "FAIL"
      result = "FAIL"
    }
    continue
  }

  $c = Get-Content -Path $path -Raw

  $exists = "PASS"
  $opsCard = if ($c -match 'data-prd-role="ops-card"') { "PASS" } else { "FAIL" }
  $queueGroup = if ($c -match 'data-prd-role="queue-group"') { "PASS" } else { "FAIL" }
  $checkTracking = if ($c -match 'data-prd-action="check-tracking"') { "PASS" } else { "FAIL" }
  $removeQueueGroup = if ($c -match 'data-prd-action="remove-queue-group"') { "PASS" } else { "FAIL" }
  $saveStateRules = if ($c -match 'data-prd-action="save-state-rules"') { "PASS" } else { "FAIL" }
  $verifyChauffeur = if ($c -match 'data-prd-action="verify-chauffeur"') { "PASS" } else { "FAIL" }
  $ordCoord = if ($c -match '41\.9742, -87\.9073') { "PASS" } else { "FAIL" }
  $mdwCoord = if ($c -match '41\.7868, -87\.7522') { "PASS" } else { "FAIL" }
  $black = if ($c -match '>\s*Black\s*<') { "PASS" } else { "FAIL" }
  $blackSuv = if ($c -match '>\s*Black SUV\s*<') { "PASS" } else { "FAIL" }

  $all = @($exists,$opsCard,$queueGroup,$checkTracking,$removeQueueGroup,$saveStateRules,$verifyChauffeur,$ordCoord,$mdwCoord,$black,$blackSuv)
  $result = if (($all | Where-Object { $_ -eq "FAIL" }).Count -eq 0) { "PASS" } else { "FAIL" }

  $rows += [pscustomobject]@{
    file = $rel
    exists = $exists
    opsCard = $opsCard
    queueGroup = $queueGroup
    checkTracking = $checkTracking
    removeQueueGroup = $removeQueueGroup
    saveStateRules = $saveStateRules
    verifyChauffeur = $verifyChauffeur
    ordCoord = $ordCoord
    mdwCoord = $mdwCoord
    black = $black
    blackSuv = $blackSuv
    result = $result
  }
}

$csvPath = Join-Path $root "apps/driver_ops_smoke_matrix.csv"
$rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

$failedRows = $rows | Where-Object { $_.result -eq "FAIL" }

Write-Output "Runtime checks:"
$runtimeChecks.GetEnumerator() | ForEach-Object { Write-Output ("- {0}: {1}" -f $_.Key, ($(if ($_.Value) {"PASS"} else {"FAIL"}))) }
Write-Output ""
Write-Output ("Screens checked: {0}" -f $rows.Count)
Write-Output ("Passed: {0}" -f (($rows | Where-Object { $_.result -eq "PASS" }).Count))
Write-Output ("Failed: {0}" -f $failedRows.Count)
Write-Output ("Matrix CSV: {0}" -f $csvPath)

if ($failedRows.Count -gt 0) {
  Write-Output ""
  Write-Output "Failed screens:"
  $failedRows | ForEach-Object { Write-Output ("- " + $_.file) }
}
