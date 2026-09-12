param([string]$CorePath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$sourceFiles = Get-ChildItem -LiteralPath (Join-Path $projectRoot 'src') -File
$cpp = ($sourceFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
$addonRoot = Join-Path $projectRoot 'addon/TurtleCamps'
$toc = Get-Content -LiteralPath (Join-Path $addonRoot 'TurtleCamps.toc')
foreach ($line in $toc) {
    if ($line.Trim() -and -not $line.StartsWith('#') -and -not (Test-Path -LiteralPath (Join-Path $addonRoot $line.Trim()))) { throw "Missing TOC file: $line" }
}
if ($toc -notcontains '## Interface: 11200') { throw 'Wrong interface' }
if ($toc -notcontains '## SavedVariables: TurtleCampsDB') { throw 'Wrong SavedVariables' }
$lua = Get-Content -LiteralPath (Join-Path $addonRoot 'TurtleCamps.lua') -Raw
if ($lua -match 'C_ChatInfo|C_Timer|SetSize\(|SetBackdropTemplate|ChatFrame_AddMessageEventFilter|table\.unpack|string\.gmatch|\bcontinue\b|SetCursorPosition') { throw 'Unverified newer Lua/client API' }
if ($cpp -match '\bsConfigMgr\b|\bAC_[A-Z_]+|Acore::|Trinity::') { throw 'Foreign core API' }
$keys = [regex]::Matches($cpp, '"(Camps\.[A-Za-z]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$config = Get-Content -LiteralPath (Join-Path $projectRoot 'conf/mod-camps-twow.conf.dist')
$configKeys = @($config | Where-Object { $_ -match '^Camps\.' } | ForEach-Object { ($_ -split '=')[0].Trim() })
if (($configKeys | Sort-Object -Unique).Count -ne $configKeys.Count) { throw 'Duplicate configuration key' }
if (Compare-Object $keys ($configKeys | Sort-Object)) { throw 'Config implementation/default mismatch' }
if (-not ($config | Where-Object { $_ -eq '[ModuleConf]' })) { throw 'Missing config section' }
if (-not $cpp.Contains('void Addmod_camps_twowScripts()')) { throw 'Missing canonical loader' }
if (-not $lua.Contains('TCAMP/1~') -or -not $cpp.Contains('TCAMP/1~')) { throw 'Protocol mismatch' }
$ops = [regex]::Matches($lua, 'request\("([A-Z]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
foreach ($op in $ops) { if (-not $cpp.Contains(('r.op=="{0}"' -f $op))) { throw "Missing server operation $op" } }
$runtime = $cpp + $lua
if ($runtime -match 'TODO|FIXME|temporary hack|[A-Za-z]:[\\/]Users[\\/]') { throw 'Unfinished marker or developer path in runtime' }
if ($CorePath) {
    $loader = Join-Path $CorePath 'modules/mod-camps-twow/src/CampsScripts.cpp'
    if (-not (Test-Path -LiteralPath $loader)) { throw 'Module not integrated at canonical location' }
}
Write-Output "PASS: TOC, $($keys.Count) config keys, $($ops.Count) addon operations, protocol identity, API/stale marker checks."
Write-Output 'Lua execution and live realm behavior are NOT tested by this script.'
