$ErrorActionPreference = "Stop"
$root = "C:\\Rydinex\\PRD"
$appsDir = Join-Path $root "apps"
New-Item -ItemType Directory -Path $appsDir -Force | Out-Null

$runtimePath = Join-Path $appsDir "prd-runtime.js"
if (-not (Test-Path $runtimePath)) {
  throw "Missing runtime at $runtimePath"
}

$codeFiles = Get-ChildItem -Path $root -Filter code.html -Recurse | Where-Object { $_.FullName -notlike "*\\apps\\*" }

function Get-WorkspaceRelative([string]$path) {
  $full = (Resolve-Path $path).Path
  $rootFull = (Resolve-Path $root).Path
  if ($full.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase)) {
    $trimmed = $full.Substring($rootFull.Length).TrimStart('\')
    return $trimmed.Replace('\', '/')
  }
  throw "Path '$path' is not inside workspace root '$root'."
}

function Get-AppsPrefixForFile([string]$filePath) {
  $relative = Get-WorkspaceRelative $filePath
  $segments = $relative.Split('/', [System.StringSplitOptions]::RemoveEmptyEntries)
  if ($segments.Count -le 1) {
    return ""
  }
  $depth = $segments.Count - 1
  $prefix = ""
  for ($i = 0; $i -lt $depth; $i++) {
    $prefix += "../"
  }
  return $prefix
}

function Get-AppCategory([string]$folderName) {
  $n = $folderName.ToLower()

  if ($n -match "^(rydinex_admin_|admin_|security_|access_|role_permissions|user_management|system_|onboarding_|vehicle_eligibility|tnp_financial|regulatory_|new_state_wizard|state_launch|expansion_roadmap|market_research)") {
    return "admin"
  }

  if ($n -match "driver" -or $n -match "earnings_summary" -or $n -match "incoming_request" -or $n -match "vehicle_audit" -or $n -match "incident" -or $n -match "report_category" -or $n -match "report_confirmation") {
    return "driver"
  }

  return "rider"
}

$apps = @{ rider = @(); driver = @(); admin = @() }
foreach ($file in $codeFiles) {
  $rel = Get-WorkspaceRelative $file.FullName
  $folder = Split-Path -Path $rel -Parent
  $folderName = Split-Path -Path $folder -Leaf
  $cat = Get-AppCategory $folderName
  $apps[$cat] += $rel
}

$apps.rider = $apps.rider | Sort-Object -Unique
$apps.driver = $apps.driver | Sort-Object -Unique
$apps.admin = $apps.admin | Sort-Object -Unique

$manifestObj = @{
  generatedAt = (Get-Date).ToString("s")
  apps = $apps
}
$manifestJson = $manifestObj | ConvertTo-Json -Depth 6
$manifest = "window.PRD_MANIFEST = $manifestJson;"
Set-Content -Path (Join-Path $appsDir "prd-manifest.js") -Value $manifest -Encoding UTF8

function New-HubHtml([string]$title, [string]$subtitle, [array]$items, [string]$appName) {
  $cards = ($items | ForEach-Object {
    $screenPath = $_
    $folder = Split-Path -Path $screenPath -Parent
    $name = Split-Path -Path $folder -Leaf
    "<a class='card' href='../../${screenPath}?app=${appName}'><span class='k'>$name</span><span class='p'>$screenPath</span></a>"
  }) -join "`n"

  return @"
<!DOCTYPE html>
<html lang='en'>
<head>
<meta charset='utf-8'/>
<meta name='viewport' content='width=device-width, initial-scale=1'/>
<title>$title</title>
<style>
:root{--bg:#0f1720;--panel:#16202b;--ink:#eaf1ff;--soft:#8ea3bd;--line:#29415f;--accent:#4ec2ff}
*{box-sizing:border-box}body{margin:0;font-family:Segoe UI,Arial,sans-serif;background:radial-gradient(circle at 20% -10%,#1f3348 0,#0f1720 45%,#0a1017 100%);color:var(--ink);min-height:100vh}
main{max-width:1100px;margin:0 auto;padding:28px 18px 44px}h1{margin:0 0 8px;font-size:34px}p{margin:0 0 20px;color:var(--soft)}
.top{display:flex;gap:10px;flex-wrap:wrap;margin-bottom:20px}.btn{background:#1d3147;color:#dff3ff;border:1px solid #38638a;border-radius:10px;padding:10px 14px;text-decoration:none;font-weight:700;font-size:13px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(250px,1fr));gap:12px}.card{display:block;padding:14px;border-radius:12px;background:linear-gradient(180deg,#152231,#111b27);border:1px solid var(--line);text-decoration:none;color:var(--ink)}
.card:hover{transform:translateY(-2px);border-color:var(--accent)}.k{display:block;font-weight:700;font-size:13px;margin-bottom:6px}.p{display:block;color:var(--soft);font-size:12px;word-break:break-all}
</style>
</head>
<body>
<main>
<h1>$title</h1>
<p>$subtitle</p>
<div class='top'>
<a class='btn' href='../index.html'>All Apps</a>
<a class='btn' href='../../apps/rider/index.html'>Rider</a>
<a class='btn' href='../../apps/driver/index.html'>Driver</a>
<a class='btn' href='../../apps/admin/index.html'>Admin</a>
</div>
<div class='grid'>
$cards
</div>
</main>
</body>
</html>
"@
}

New-Item -ItemType Directory -Path (Join-Path $appsDir "rider") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $appsDir "driver") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $appsDir "admin") -Force | Out-Null

$riderHub = New-HubHtml -title "Rydinex Rider App" -subtitle "Interactive rider flow screens" -items $apps.rider -appName "rider"
$driverHub = New-HubHtml -title "Rydinex Driver App" -subtitle "Interactive driver flow screens" -items $apps.driver -appName "driver"
$adminHub = New-HubHtml -title "Rydinex Admin App" -subtitle "Interactive admin console screens" -items $apps.admin -appName "admin"

Set-Content -Path (Join-Path $appsDir "rider\index.html") -Value $riderHub -Encoding UTF8
Set-Content -Path (Join-Path $appsDir "driver\index.html") -Value $driverHub -Encoding UTF8
Set-Content -Path (Join-Path $appsDir "admin\index.html") -Value $adminHub -Encoding UTF8

$rootIndex = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<title>Rydinex PRD Apps</title>
<style>
:root{--bg:#071019;--ink:#ecf4ff;--soft:#9db4ce;--r:#3bb5ff;--d:#16d39a;--a:#ff8f5a}
*{box-sizing:border-box}body{margin:0;font-family:Segoe UI,Arial,sans-serif;background:radial-gradient(circle at 30% -20%,#20334a 0,#071019 55%,#050b12 100%);color:var(--ink);min-height:100vh;display:grid;place-items:center}
.wrap{width:min(980px,92vw)}h1{margin:0 0 8px;font-size:42px}p{margin:0 0 24px;color:var(--soft)}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:14px}
.card{display:block;padding:20px;border-radius:14px;text-decoration:none;color:var(--ink);border:1px solid rgba(255,255,255,.15);background:linear-gradient(180deg,rgba(255,255,255,.06),rgba(255,255,255,.02))}
.card h2{margin:0 0 6px;font-size:22px}.card p{margin:0;font-size:13px}
.rider{box-shadow:inset 0 0 0 1px rgba(59,181,255,.35)}.driver{box-shadow:inset 0 0 0 1px rgba(22,211,154,.35)}.admin{box-shadow:inset 0 0 0 1px rgba(255,143,90,.35)}
</style>
</head>
<body>
<div class="wrap">
<h1>Rydinex PRD Launcher</h1>
<p>Separated app hubs with fully interactive prototype behavior enabled.</p>
<div class="grid">
<a class="card rider" href="apps/rider/index.html"><h2>Rider App</h2><p>Booking, map, profile, safety, tracking flows.</p></a>
<a class="card driver" href="apps/driver/index.html"><h2>Driver App</h2><p>Dashboard, navigation, earnings, request and compliance flows.</p></a>
<a class="card admin" href="apps/admin/index.html"><h2>Admin App</h2><p>Operations, security, analytics, approvals and launch workflows.</p></a>
</div>
</div>
</body>
</html>
'@
Set-Content -Path (Join-Path $root "index.html") -Value $rootIndex -Encoding UTF8

$injectedCount = 0
foreach ($file in $codeFiles) {
  $content = Get-Content -Path $file.FullName -Raw
  $appsPrefix = Get-AppsPrefixForFile $file.FullName
  $manifestPath = "${appsPrefix}apps/prd-manifest.js"
  $runtimeRelPath = "${appsPrefix}apps/prd-runtime.js"

  $content = [regex]::Replace($content, '(?im)^\s*<script\s+src=""\s*>\s*</script>\s*', '')
  $content = [regex]::Replace($content, '(?im)^\s*<script\s+src="[^"]*apps/prd-manifest.js"\s*>\s*</script>\s*', '')
  $content = [regex]::Replace($content, '(?im)^\s*<script\s+src="[^"]*apps/prd-runtime.js"\s*>\s*</script>\s*', '')

  $inject = "<script src=`"$manifestPath`"></script>`r`n<script src=`"$runtimeRelPath`"></script>`r`n"
  if ($content -match "</body>") {
    $updated = $content -replace "</body>", ($inject + "</body>")
    Set-Content -Path $file.FullName -Value $updated -Encoding UTF8
    $injectedCount++
  }
}

Write-Output ("Screens found: {0}" -f $codeFiles.Count)
Write-Output ("Screens injected: {0}" -f $injectedCount)
Write-Output ("Rider screens: {0}" -f $apps.rider.Count)
Write-Output ("Driver screens: {0}" -f $apps.driver.Count)
Write-Output ("Admin screens: {0}" -f $apps.admin.Count)
