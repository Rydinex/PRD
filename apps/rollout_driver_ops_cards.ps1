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

$card = @'
<section class="glass-panel p-5 rounded-2xl border border-primary/20" data-prd-role="ops-card">
<h3 class="font-headline font-bold text-base mb-3">Driver Ops Control</h3>
<div class="text-xs text-on-surface-variant space-y-1 mb-3">
<p>Socket: <span class="text-error font-bold">Disconnected</span></p>
<p>O'Hare (ORD): 41.9742, -87.9073</p>
<p>Midway (MDW): 41.7868, -87.7522</p>
</div>
<div class="flex gap-2 mb-3">
<label class="text-xs px-3 py-1 rounded-full bg-primary/20 border border-primary/30"><input type="checkbox" checked/> Black</label>
<label class="text-xs px-3 py-1 rounded-full bg-primary/20 border border-primary/30"><input type="checkbox" checked/> Black SUV</label>
</div>
<div class="flex items-center justify-between p-3 bg-surface-container rounded-xl mb-3" data-prd-role="queue-group">
<span class="text-xs">Queue Group: Airport+Events</span>
<button class="text-xs px-3 py-2 rounded-lg bg-error-container/30 border border-error/30" data-prd-action="remove-queue-group">Remove Queue Group</button>
</div>
<div class="grid grid-cols-2 gap-2" data-prd-role="state-rules">
<button class="text-xs px-3 py-2 rounded-lg bg-surface-container-highest" data-prd-action="check-tracking">Check Tracking</button>
<button class="text-xs px-3 py-2 rounded-lg bg-primary-container text-white" data-prd-action="save-state-rules">Save State Rules</button>
</div>
<div class="mt-2" data-prd-role="chauffeur">
<button class="w-full text-xs px-3 py-2 rounded-lg bg-emerald-700/40 border border-emerald-400/40" data-prd-action="verify-chauffeur">Verify Chauffeur License</button>
</div>
</section>
'@

$updated = 0
$skippedExisting = 0
$missing = 0

foreach ($rel in $targets) {
  $path = Join-Path $root $rel
  if (-not (Test-Path $path)) {
    $missing++
    continue
  }

  $content = Get-Content -Path $path -Raw
  if ($content -match 'data-prd-role="ops-card"') {
    $skippedExisting++
    continue
  }

  if ($content -match '</main>') {
    $newContent = $content -replace '</main>', ($card + "`r`n</main>")
    Set-Content -Path $path -Value $newContent -Encoding UTF8
    $updated++
  }
}

Write-Output "Targets: $($targets.Count)"
Write-Output "Updated: $updated"
Write-Output "Already had card: $skippedExisting"
Write-Output "Missing files: $missing"
