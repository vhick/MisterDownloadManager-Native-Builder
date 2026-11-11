# Optional MDM native lifecycle / login-startup console (MIT license for this script).
[CmdletBinding()]
param([ValidateSet('Menu','Start','Stop','Status','AutostartOn','AutostartOff','RepairAutostart')]
      [string]$Action='Menu', [string]$AppRoot='')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
# Resolve after parameter binding. In Windows PowerShell 5.1, $PSScriptRoot can be
# empty while a script parameter's DEFAULT expression is evaluated. The caller
# also passes -AppRoot explicitly so the console never relies on the CWD.
if ([string]::IsNullOrWhiteSpace($AppRoot)) {
    $scriptFile = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptFile)) {
        $scriptFile = $MyInvocation.MyCommand.Path
    }
    if ([string]::IsNullOrWhiteSpace($scriptFile)) {
        throw 'Cannot locate Manager.ps1. Run Mister-Manager.cmd beside the application or supply -AppRoot.'
    }
    $AppRoot = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($scriptFile))
}
if ([string]::IsNullOrWhiteSpace($AppRoot)) { throw 'Application folder is empty.' }
$root=[IO.Path]::GetFullPath($AppRoot)
$exe=Join-Path $root 'misterdownloadmanager.exe'
$data=Join-Path $root 'data'
$integration=Join-Path $data 'Integration'
$record=Join-Path $integration 'autostart-ownership.json'
$key='Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run'
$name='MisterDownloadManager_NativePortable_Builder'
function ExpectedCommand([string]$path) { return ('"' + $path + '" /startup') }
function Save-Record($state) {
    if (!(Test-Path -LiteralPath $integration)) { [void][IO.Directory]::CreateDirectory($integration) }
    $content=$state | ConvertTo-Json -Depth 5
    $temp="$record.tmp"
    [IO.File]::WriteAllText($temp,$content,(New-Object System.Text.UTF8Encoding($false)))
    if ([IO.File]::Exists($record)) {
        try { [IO.File]::Replace($temp,$record,"$record.bak") }
        catch {
            [IO.File]::Copy($record,"$record.bak",$true)
            [IO.File]::Delete($record)
            [IO.File]::Move($temp,$record)
        }
    } else { [IO.File]::Move($temp,$record) }
}
function Load-Record {
    if (!(Test-Path -LiteralPath $record)) { return $null }
    $state=[IO.File]::ReadAllText($record) | ConvertFrom-Json
    if ($state.schema -ne 1 -or $state.valueName -cne $name -or $state.ownerId -notmatch '^[a-fA-F0-9-]{36}$') {
        throw 'Autostart ownership file invalid, refusing modifications.'
    }
    return $state
}
function Current-Startup {
    if (!(Test-Path -LiteralPath $key)) { return $null }
    $props = Get-ItemProperty -LiteralPath $key -Name $name -ErrorAction SilentlyContinue
    if ($null -eq $props) { return $null }
    $named = $props.PSObject.Properties[$name]
    if ($null -eq $named) { return $null }
    return [string]$named.Value
}
function Owned-Processes {
    # Read-only process inspection; never touch an installed copy with same image name.
    $found=@()
    foreach ($p in @(Get-Process -Name 'misterdownloadmanager' -ErrorAction SilentlyContinue)) {
        try {
            if ([string]::Equals($p.Path,$exe,[StringComparison]::OrdinalIgnoreCase)) { $found+= $p }
        } catch { }
    }
    return @($found)
}
function Status {
    Write-Host "Application: $exe"
    $found=@(Owned-Processes)
    if ($found.Count) { Write-Host "RUNNING: $($found.Count) portable instance(s), PID: $(($found.Id) -join ', ')" }
    else { Write-Host 'NOT RUNNING at this path (no installed application was inspected for control)' }
    $prior=Load-Record
    $current=Current-Startup
    if (!$current) { Write-Host 'Autostart: disabled' }
    elseif ($prior -and $current -ceq $prior.command) { Write-Host "Autostart: owned ($current)" }
    else { Write-Host "Autostart: unowned or changed ($current)" }
}
function Start-App {
    if (!(Test-Path -LiteralPath $exe) -or !(Test-Path -LiteralPath $data)) { throw 'Missing exe/data, refusing startup.' }
    if (@(Owned-Processes).Count -gt 0) { Write-Host 'Already running; no duplicate launched.'; return }
    Start-Process -FilePath $exe -WorkingDirectory $root
    Write-Host 'Start requested (GUI behavior must be manually verified).'
}
function Stop-App {
    if (@(Owned-Processes).Count -eq 0) { Write-Host 'Portable instance not running.'; return }
    $p=Start-Process -FilePath $exe -ArgumentList '/exit' -WorkingDirectory $root -PassThru -Wait
    if ($p.ExitCode -ne 0) { Write-Warning "Exit command returned $($p.ExitCode)" }
    Write-Host 'Graceful /exit requested; no forced process termination.'
}
function Set-Autostart {
    if (!(Test-Path -LiteralPath $exe) -or !(Test-Path -LiteralPath $data)) { throw 'Missing exe/data, not portable.' }
    $prior=Load-Record
    $current=Current-Startup
    if (!$prior -and $current) { throw 'Run entry already exists without our ownership; refusing takeover.' }
    if ($prior -and $current -and $current -cne $prior.command) {
        throw 'Run entry changed since registration; refusing overwrite.'
    }
    $newCmd=ExpectedCommand $exe
    if (!$prior) { $prior=[pscustomobject]@{schema=1;valueName=$name;ownerId=[guid]::NewGuid().ToString();command=$newCmd;state='pending'}; Save-Record $prior }
    New-ItemProperty -Path $key -Name $name -PropertyType String -Value $newCmd -Force | Out-Null
    if ((Current-Startup) -cne $newCmd) { throw 'Autostart verification failed; recovery journal remains.' }
    $prior.command=$newCmd; $prior.state='active'; Save-Record $prior
    Write-Host "Enabled owned, per-user autostart: $newCmd"
}
function Remove-Autostart {
    $prior=Load-Record
    if (!$prior) { throw 'No autostart ownership record; refusing deletion.' }
    $current=Current-Startup
    if ($current -and $current -cne $prior.command) { throw 'Autostart has been changed by another application/user; preserving.' }
    if ($current) { Remove-ItemProperty -LiteralPath $key -Name $name }
    $prior.state='disabled';Save-Record $prior
    Write-Host 'Disabled console-owned autostart only.'
}
function Menu {
    while ($true) {
        Write-Host ''
        Write-Host 'MDM Native Manager (optional - app can always start directly)'
        Write-Host '1 Start | 2 Graceful Stop | 3 Status | 4 Open Data'
        Write-Host '5 Enable login autostart | 6 Disable autostart'
        Write-Host '7 Repair autostart after move | 8 Browser integration console | 9 Exit'
        $answer=Read-Host 'Choose 1-9'
        try {
            switch ($answer) {
                '1' { Start-App }
                '2' { Stop-App }
                '3' { Status }
                '4' { if (Test-Path -LiteralPath $data) { Invoke-Item -LiteralPath $data } }
                '5' { if ((Read-Host 'Type ENABLE to confirm HKCU Run entry') -ceq 'ENABLE') { Set-Autostart } }
                '6' { Remove-Autostart }
                '7' { if ((Read-Host 'Type REPAIR to update an owned stale target') -ceq 'REPAIR') { Set-Autostart } }
                '8' { & (Join-Path $root 'BrowserIntegration.ps1') -Action Menu -AppRoot $root }
                '9' { return }
                default { Write-Host 'Choose 1-9.' }
            }
        } catch { Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red }
    }
}
switch ($Action) {
    'Menu' { Menu }
    'Start' { Start-App }
    'Stop' { Stop-App }
    'Status' { Status }
    'AutostartOn' { Set-Autostart }
    'AutostartOff' { Remove-Autostart }
    'RepairAutostart' { Set-Autostart }
}
