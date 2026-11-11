# Mister Download Manager - optional per-user browser integration.
# License: MIT for this builder-specific script. MDM itself is GPL-3.0-or-later.
# Does not call upstream --register: upstream intentionally refuses portable mode
# and its --register / --unregister can overwrite/remove installed-app keys.
[CmdletBinding()]
param(
    [ValidateSet('Menu','Register','Repair','Unregister','Status')]
    [string]$Action = 'Menu',
    [string]$AppRoot = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$utf8 = New-Object System.Text.UTF8Encoding($false)
$hostName = 'com.misterdownloadmanager.host'
# Resolve after parameter binding, not as a parameter default. This works on
# Windows PowerShell 5.1 when run from CMD, PowerShell, or another directory.
if ([string]::IsNullOrWhiteSpace($AppRoot)) {
    $scriptFile = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptFile)) {
        $scriptFile = $MyInvocation.MyCommand.Path
    }
    if ([string]::IsNullOrWhiteSpace($scriptFile)) {
        throw 'Cannot locate BrowserIntegration.ps1. Run Mister-Browser-Integration.cmd beside the application or supply -AppRoot.'
    }
    $AppRoot = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($scriptFile))
}
if ([string]::IsNullOrWhiteSpace($AppRoot)) { throw 'Application folder is empty.' }
$root = [IO.Path]::GetFullPath($AppRoot)
$hostExe = Join-Path $root 'misterdownloadmanager-nmhost.exe'
$appExe = Join-Path $root 'misterdownloadmanager.exe'
$data = Join-Path $root 'data'
$integration = Join-Path $data 'Integration'
$ownershipPath = Join-Path $integration 'browser-registration.json'
$chromiumPath = Join-Path $integration 'com.misterdownloadmanager.host.json'
$firefoxPath = Join-Path $integration 'com.misterdownloadmanager.host.firefox.json'
$keys = @(
    'Registry::HKEY_CURRENT_USER\Software\Google\Chrome\NativeMessagingHosts\com.misterdownloadmanager.host',
    'Registry::HKEY_CURRENT_USER\Software\Chromium\NativeMessagingHosts\com.misterdownloadmanager.host',
    'Registry::HKEY_CURRENT_USER\Software\Microsoft\Edge\NativeMessagingHosts\com.misterdownloadmanager.host',
    'Registry::HKEY_CURRENT_USER\Software\BraveSoftware\Brave-Browser\NativeMessagingHosts\com.misterdownloadmanager.host',
    'Registry::HKEY_CURRENT_USER\Software\Mozilla\NativeMessagingHosts\com.misterdownloadmanager.host'
)
# Verified from upstream crates/ipc/src/extension.rs, v0.5.2.
$ids = @('oogbclbbninliongijffeeggalppliok','ejoleppdfgjdndddcjoehopknmlglojp')
$firefoxId = 'integration@misterdownloadmanager.com'

function Read-Ownership {
    if (-not [IO.File]::Exists($ownershipPath)) { return $null }
    $obj = [IO.File]::ReadAllText($ownershipPath) | ConvertFrom-Json
    if ($obj.schema -ne 1 -or $obj.hostName -cne $hostName -or
        $obj.ownerId -notmatch '^[0-9a-fA-F-]{36}$' -or
        @($obj.keys).Count -ne $keys.Count) { throw 'Ownership file invalid; refusing registry changes.' }
    for ($i=0; $i -lt $keys.Count; $i++) {
        if ([string]$obj.keys[$i] -cne $keys[$i]) { throw 'Ownership key list changed; refusing changes.' }
    }
    return $obj
}
function Write-JsonAtomic([string]$path, $obj) {
    $temp = "$path.tmp"
    $str = ConvertTo-Json -InputObject $obj -Depth 10
    [IO.File]::WriteAllText($temp, $str, $utf8)
    if ([IO.File]::Exists($path)) {
        # Same-directory replace is atomic on NTFS; backup kept if replacement fails.
        $backup = "$path.bak"
        try { [IO.File]::Replace($temp, $path, $backup) }
        catch {
            # FAT/exFAT may not support Replace. Keep a recoverable backup.
            [IO.File]::Copy($path, $backup, $true)
            [IO.File]::Delete($path)
            [IO.File]::Move($temp, $path)
        }
    } else { [IO.File]::Move($temp, $path) }
}
function Get-KeyDefault([string]$key) {
    if (-not (Test-Path -LiteralPath $key)) { return $null }
    $rk = Get-Item -LiteralPath $key
    return [string]$rk.GetValue('', $null)
}
function Key-Exists([string]$key) { return (Test-Path -LiteralPath $key) }
# HKLM registrations can take precedence or conflict even if our HKCU keys are empty.
# Never shadow browser integration that belongs to a conventional installation.
function Assert-NoInstalledGlobalHost {
    foreach ($view in @([Microsoft.Win32.RegistryView]::Registry64, [Microsoft.Win32.RegistryView]::Registry32)) {
        try {
            $global = [Microsoft.Win32.RegistryKey]::OpenBaseKey(
                [Microsoft.Win32.RegistryHive]::LocalMachine, $view)
        } catch { continue } # A 32-bit OS may have no 64-bit registry view.
        try {
            foreach ($key in $keys) {
                $relative = $key.Substring('Registry::HKEY_CURRENT_USER\'.Length)
                $occupied = $global.OpenSubKey($relative)
                if ($null -ne $occupied) {
                    $occupied.Dispose()
                    throw "Installed/system-wide native messaging registration exists (HKLM $view): $relative. Refusing browser takeover."
                }
            }
        } finally { $global.Dispose() }
    }
}
function Assert-PortableApp {
    if (-not [IO.File]::Exists($hostExe) -or -not [IO.File]::Exists($appExe)) {
        throw 'Missing MDM EXEs. Place this console beside misterdownloadmanager.exe and misterdownloadmanager-nmhost.exe.'
    }
    if (-not [IO.Directory]::Exists($data)) { throw 'Missing data folder: refusing to register nonportable application.' }
    $test = Join-Path $data ('.mdm-portable-test-' + [guid]::NewGuid().ToString('N'))
    try { [IO.File]::WriteAllText($test, 'probe', $utf8) }
    finally { if ([IO.File]::Exists($test)) { [IO.File]::Delete($test) } }
}
function Desired-ManifestFor([string]$key) {
    if ($key -match 'Mozilla') { return $firefoxPath }
    return $chromiumPath
}
function Get-RecordState {
    $obj = Read-Ownership
    Write-Host "Portable directory: $root"
    Write-Host "Portable data:      $data"
    if ($null -eq $obj) { Write-Host 'This console has no ownership record.' }
    else {
        Write-Host ("Registration state:  " + $obj.state)
        Write-Host ("Previously owned:    " + $obj.manifestChromium)
    }
    foreach ($key in $keys) {
        if (-not (Key-Exists $key)) { Write-Host "ABSENT: $key"; continue }
        $actual = Get-KeyDefault $key
        $owned = $false
        if ($null -ne $obj) {
            $expected = if ($key -match 'Mozilla') { [string]$obj.manifestFirefox } else { [string]$obj.manifestChromium }
            $owned = [string]::Equals($actual, $expected, [StringComparison]::OrdinalIgnoreCase)
        }
        if ($owned) { Write-Host "OWNED:  $key = $actual" }
        else { Write-Host "OTHER:  $key = $actual" }
    }
    Write-Host 'Existing HKLM registrations are never changed or removed by this console.'
}
function Register-Portable {
    Assert-PortableApp
    Assert-NoInstalledGlobalHost
    if (-not [IO.Directory]::Exists($integration)) { [IO.Directory]::CreateDirectory($integration) | Out-Null }
    $record = Read-Ownership
    if ($null -eq $record) {
        # Protect pre-existing installed-app registration and files. No takeover option.
        foreach ($key in $keys) { if (Key-Exists $key) { throw "Existing key belongs to another installation: $key. No changes made." } }
        foreach ($path in @($chromiumPath, $firefoxPath)) {
            if ([IO.File]::Exists($path)) { throw "Unowned manifest exists: $path. No changes made." }
        }
        $record = [pscustomobject]@{
            schema=1; hostName=$hostName; ownerId=[guid]::NewGuid().ToString()
            state='pending'; manifestChromium=$chromiumPath; manifestFirefox=$firefoxPath
            hostExecutable=$hostExe; keys=@($keys)
        }
        # Create crash-recovery journal BEFORE writing the registry.
        Write-JsonAtomic $ownershipPath $record
    }
    # For moved folders: only update values this console previously registered.
    foreach ($key in $keys) {
        if (-not (Key-Exists $key)) { continue }
        $actual = Get-KeyDefault $key
        $recorded = if ($key -match 'Mozilla') { [string]$record.manifestFirefox } else { [string]$record.manifestChromium }
        if (-not [string]::Equals($actual, $recorded, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Registry collision/change at $key. Refusing repair; original state preserved."
        }
        $rk = Get-Item -LiteralPath $key
        if ($rk.GetValueNames().Count -gt 1 -or $rk.GetSubKeyNames().Count -gt 0) {
            throw "Unexpected values or child keys at $key. Refusing modification."
        }
    }
    $chromium = [ordered]@{
        name=$hostName; description='Mister Download Manager (opt-in portable registration)'
        path=$hostExe; type='stdio'; allowed_origins=@($ids | ForEach-Object { "chrome-extension://$_/" })
    }
    $firefox = [ordered]@{
        name=$hostName; description='Mister Download Manager (opt-in portable registration)'
        path=$hostExe; type='stdio'; allowed_extensions=@($firefoxId)
    }
    Write-JsonAtomic $chromiumPath $chromium
    Write-JsonAtomic $firefoxPath $firefox
    foreach ($key in $keys) {
        $desired = Desired-ManifestFor $key
        if (-not (Key-Exists $key)) { New-Item -Path $key -Force | Out-Null }
        Set-Item -LiteralPath $key -Value $desired
        if (-not [string]::Equals((Get-KeyDefault $key), $desired, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Registration verification failed: $key (journal preserved for retry)."
        }
    }
    $record.state = 'active'
    $record.manifestChromium = $chromiumPath
    $record.manifestFirefox = $firefoxPath
    $record.hostExecutable = $hostExe
    Write-JsonAtomic $ownershipPath $record
    Write-Host 'SUCCESS: Browser native messaging registered per-user (HKCU) for this portable copy.'
    Write-Host 'Restart each browser. Install the official MDM browser extension if absent.'
}
function Unregister-Portable {
    $record = Read-Ownership
    if ($null -eq $record) { throw 'No ownership journal. Refusing to remove any registry entries.' }
    $allRemoved = $true
    foreach ($key in $keys) {
        if (-not (Key-Exists $key)) { continue }
        $expected = if ($key -match 'Mozilla') { [string]$record.manifestFirefox } else { [string]$record.manifestChromium }
        $actual = Get-KeyDefault $key
        if (-not [string]::Equals($actual, $expected, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Warning "Preserved changed/unowned registry key: $key"; $allRemoved=$false; continue
        }
        $rk = Get-Item -LiteralPath $key
        if ($rk.GetValueNames().Count -gt 1 -or $rk.GetSubKeyNames().Count -gt 0) {
            Write-Warning "Preserved registry key with extra contents: $key"; $allRemoved=$false; continue
        }
        Remove-Item -LiteralPath $key -Force
    }
    if (-not $allRemoved) {
        Write-Warning 'Some keys remain. Ownership journal preserved for review.'
        return
    }
    # Do not delete manifest or ownership files; they are a recovery record in Data.
    $record.state='unregistered'
    Write-JsonAtomic $ownershipPath $record
    Write-Host 'SUCCESS: Removed only console-owned HKCU browser host keys. Data and audit record kept.'
}
function Show-Menu {
    while ($true) {
        Write-Host ''
        Write-Host 'Mister Download Manager - OPTIONAL Browser Integration'
        Write-Host '1) Register or repair (Chrome, Chromium, Edge, Brave, Firefox)'
        Write-Host '2) Show status'
        Write-Host '3) Unregister safely'
        Write-Host '4) Exit'
        $choice = Read-Host 'Choose 1-4'
        try {
            switch ($choice) {
                '1' { Register-Portable }
                '2' { Get-RecordState }
                '3' {
                    $yes = Read-Host 'Type REMOVE to confirm unregister'
                    if ($yes -ceq 'REMOVE') { Unregister-Portable }
                }
                '4' { return }
                default { Write-Host 'Select 1, 2, 3, or 4.' }
            }
        } catch { Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red }
    }
}
switch ($Action) {
    'Menu' { Show-Menu }
    'Status' { Get-RecordState }
    'Register' { Register-Portable }
    'Repair' { Register-Portable }
    'Unregister' { Unregister-Portable }
}
