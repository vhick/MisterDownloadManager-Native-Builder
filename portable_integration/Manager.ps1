# Mister Download Manager NATIVE unified manager b1r3.
# Optional console: MDM itself always starts directly with its own EXE.
# Builder console license: MIT; MDM upstream is GPL-3.0-or-later.
# Browser/legacy actions are opt-in, never performed automatically.
# Legacy cleanup logic retained from user-confirmed working standalone b1r2.
[CmdletBinding()]
param(
    [ValidateSet('Menu','Start','Stop','Status','BrowserStatus','BrowserRegister',
                 'BrowserUnregister','LegacyScan','LegacyCleanUser','LegacyCleanMachine',
                 'AutostartOn','AutostartOff','RepairAutostart','SelfTest')]
    [string]$Action = 'Menu',
    [string]$AppRoot = ''
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
$utf8 = New-Object System.Text.UTF8Encoding($false)

# Resolve the actual PowerShell file, not CWD and not a cmd parameter ending in '\'.
# This preserves the b1r2 fixes verified by the user on Windows PowerShell 5.1.
if ([string]::IsNullOrWhiteSpace($AppRoot)) {
    $scriptFile = $PSCommandPath
    if ([string]::IsNullOrWhiteSpace($scriptFile)) { $scriptFile = $MyInvocation.MyCommand.Path }
    if ([string]::IsNullOrWhiteSpace($scriptFile)) { throw 'Cannot determine manager script location.' }
    $AppRoot = [IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($scriptFile))
}
if ([string]::IsNullOrWhiteSpace($AppRoot)) { throw 'Application folder is empty.' }
$root = [IO.Path]::GetFullPath($AppRoot)
$exe = Join-Path $root 'misterdownloadmanager.exe'
$data = Join-Path $root 'data'
$integration = Join-Path $data 'Integration'
$record = Join-Path $integration 'autostart-ownership.json'
$key = 'Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run'
$name = 'MisterDownloadManager_NativePortable_Builder'

# Portable browser host identity, manifest paths and upstream-reviewed IDs.
$hostName = 'com.misterdownloadmanager.host'
$hostExe = Join-Path $root 'misterdownloadmanager-nmhost.exe'
$appExe = $exe
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
$ids = @('oogbclbbninliongijffeeggalppliok','ejoleppdfgjdndddcjoehopknmlglojp')
$firefoxId = 'integration@misterdownloadmanager.com'

# Exact five registry families used by the user-confirmed b1r2 legacy cleaner.
$Folders = @(
    'Software\Google\Chrome\NativeMessagingHosts',
    'Software\Chromium\NativeMessagingHosts',
    'Software\Microsoft\Edge\NativeMessagingHosts',
    'Software\BraveSoftware\Brave-Browser\NativeMessagingHosts',
    'Software\Mozilla\NativeMessagingHosts'
)
$PortableRoot = $root.TrimEnd('\')
# All NEW backups are stored within native portable Data (pre-existing standalone
# backups outside Data are NEVER moved or removed).
$BackupRoot = Join-Path $integration 'Legacy-Registry-Backups'

# ---------------------------------------------------------------------------
# Application start, status, autostart ownership. From working b1r2 manager.
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Opt-in portable native messaging registration; retained from b1r2.
# ---------------------------------------------------------------------------
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

# ---------------------------------------------------------------------------
# Read-only legacy scan / opt-in verified removal; working b1r2 code.
# ---------------------------------------------------------------------------
function Is-Under([string]$path, [string]$folder) {
    if ([string]::IsNullOrWhiteSpace($path) -or [string]::IsNullOrWhiteSpace($folder)) { return $false }
    try {
        $p = [IO.Path]::GetFullPath($path)
        $f = [IO.Path]::GetFullPath($folder).TrimEnd('\') + '\'
        return $p.StartsWith($f,[StringComparison]::OrdinalIgnoreCase)
    } catch { return $false }
}
function Get-KeyDetails([string]$hiveName, [Microsoft.Win32.RegistryView]$view, [string]$relative) {
    $hive = if ($hiveName -eq 'HKCU') { [Microsoft.Win32.RegistryHive]::CurrentUser } else { [Microsoft.Win32.RegistryHive]::LocalMachine }
    $base = $null
    $sub = $null
    try {
        $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
        $sub = $base.OpenSubKey($relative, $false)
        if ($null -eq $sub) { return $null }
        $names = @($sub.GetValueNames())
        $children = @($sub.GetSubKeyNames())
        $value = $sub.GetValue('', $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $kind = if ($names -contains '') { $sub.GetValueKind('').ToString() } else { 'None' }
        return [pscustomobject]@{
            Hive=$hiveName; View=$view.ToString(); Relative=$relative
            Key="$hiveName\$relative"; Manifest=[string]$value; Kind=$kind
            OtherValues=@($names | Where-Object { $_ -ne '' }); Children=@($children)
        }
    } finally {
        if ($null -ne $sub) { $sub.Dispose() }
        if ($null -ne $base) { $base.Dispose() }
    }
}
function Classify($entry) {
    $p = $entry.Manifest
    if ($entry.OtherValues.Count -gt 0 -or $entry.Children.Count -gt 0) {
        return 'SKIP: Extra registry values or subkeys; manual review required.'
    }
    if ($entry.Kind -notin @('String','ExpandString')) {
        return 'SKIP: Unexpected default registry value type.'
    }
    if ([string]::IsNullOrWhiteSpace($p) -or -not [IO.Path]::IsPathRooted($p) -or $p.StartsWith('\\')) {
        return 'SKIP: Missing, relative, or network manifest path.'
    }
    try { $p = [IO.Path]::GetFullPath($p) } catch { return 'SKIP: Invalid manifest path.' }
    $expectedLeaf = if ($entry.Relative -match '\\Mozilla\\') { "$HostName.firefox.json" } else { "$HostName.json" }
    if (-not [string]::Equals([IO.Path]::GetFileName($p), $expectedLeaf, [StringComparison]::OrdinalIgnoreCase)) {
        return 'SKIP: The manifest filename is not the official MDM filename.'
    }
    if ((Is-Under $p $PortableRoot) -or $p -match '(?i)[\\/]data[\\/]Integration[\\/]') {
        return 'SKIP: Looks like an existing portable registration; preserve it.'
    }
    if (-not [IO.File]::Exists($p)) { return 'STALE: Manifest missing; exact MDM host key and filename matched.' }
    try {
        $json = [IO.File]::ReadAllText($p) | ConvertFrom-Json
        if ([string]$json.name -cne $HostName -or [string]$json.type -cne 'stdio') {
            return 'SKIP: Manifest is not a recognized MDM native host.'
        }
        $exe = [string]$json.path
        if ([string]::IsNullOrWhiteSpace($exe) -or -not [string]::Equals([IO.Path]::GetFileName($exe), 'misterdownloadmanager-nmhost.exe',[StringComparison]::OrdinalIgnoreCase)) {
            return 'SKIP: Manifest does not point to an MDM native host executable.'
        }
        if (Is-Under $exe $PortableRoot) { return 'SKIP: Host executable is inside protected portable folder.' }
        if ([string]$json.name -cne $HostName) { return 'SKIP: Manifest host name mismatch.' }
        return 'LEGACY: Recognized MDM native host manifest and executable.'
    } catch { return 'SKIP: Manifest cannot be parsed or verified.' }
}
function Inventory {
    $results = New-Object System.Collections.ArrayList
    foreach ($h in @('HKCU','HKLM')) {
        foreach ($v in @([Microsoft.Win32.RegistryView]::Registry64,[Microsoft.Win32.RegistryView]::Registry32)) {
            foreach ($folder in $Folders) {
                $relative = "$folder\$HostName"
                try {
                    $detail = Get-KeyDetails $h $v $relative
                    if ($null -eq $detail) { continue }
                    $status = Classify $detail
                    $item = [pscustomobject]@{Hive=$h;View=$v.ToString();Key=$detail.Key;Relative=$relative;Manifest=$detail.Manifest;Status=$status}
                    [void]$results.Add($item)
                } catch {
                    [void]$results.Add([pscustomobject]@{Hive=$h;View=$v.ToString();Key="$h\$relative";Relative=$relative;Manifest='';Status=("SKIP: Cannot inspect key: " + $_.Exception.Message)})
                }
            }
        }
    }
    return $results.ToArray()
}
function Print-Inventory($entries) {
    Write-Host ''
    Write-Host ('Current registry user: ' + [Security.Principal.WindowsIdentity]::GetCurrent().Name)
    Write-Host ('Protected portable folder: ' + $PortableRoot)
    Write-Host ''
    if (@($entries).Count -eq 0) { Write-Host 'No MDM native messaging host keys found.'; return }
    $i=0
    foreach ($e in @($entries)) {
        $i++
        Write-Host ("[$i] $($e.Hive) $($e.View): $($e.Key)")
        Write-Host ("    Manifest: $($e.Manifest)")
        Write-Host ("    $($e.Status)")
    }
    Write-Host ''
    Write-Host 'This scan does not inspect or remove downloads, settings, browser extensions, startup, torrent, or magnet associations.'
}
function Remove-VerifiedLegacy([string]$scope) {
    $entries = @(Inventory)
    Print-Inventory $entries
    $candidates = @($entries | Where-Object { $_.Hive -eq $scope -and ($_.Status.StartsWith('LEGACY:') -or $_.Status.StartsWith('STALE:')) })
    if ($candidates.Count -eq 0) { Write-Host "No verified old-installation $scope registrations eligible for removal."; return }
    $running = @(Get-Process -Name 'misterdownloadmanager' -ErrorAction SilentlyContinue)
    if ($running.Count -gt 0) { throw 'MDM is running. Exit all MDM processes (including tray) before changing registrations.' }
    Write-Host ''
    Write-Host "$($candidates.Count) verified old-installation $scope registry entries are eligible."
    Write-Host 'They will each be backed up to a separate .reg file before removal.'
    Write-Host 'Other keys, application files, download data and manifests remain unchanged.'
    $phrase = if ($scope -eq 'HKCU') { 'REMOVE LEGACY' } else { 'REMOVE SYSTEM LEGACY' }
    $confirm = Read-Host "Type $phrase to continue"
    if ($confirm -cne $phrase) { Write-Host 'Cancelled; nothing changed.'; return }
    if ($scope -eq 'HKLM') {
        $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'HKLM cleanup requires Run as administrator. No changes made.'
        }
    }
    $session = Join-Path $BackupRoot ((Get-Date -Format 'yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8))
    [void][IO.Directory]::CreateDirectory($session)
    $utf8 = New-Object Text.UTF8Encoding($false)
    $records = New-Object System.Collections.ArrayList
    $reg = Join-Path $env:WINDIR 'System32\reg.exe'
    $n=0
    foreach ($entry in $candidates) {
        $n++
        # Reinspect immediately before each change. If changed, do not remove.
        $view = if ($entry.View -eq 'Registry32') { [Microsoft.Win32.RegistryView]::Registry32 } else { [Microsoft.Win32.RegistryView]::Registry64 }
        $now = Get-KeyDetails $scope $view $entry.Relative
        if ($null -eq $now -or $now.Manifest -cne $entry.Manifest -or (Classify $now) -cne $entry.Status) {
            Write-Warning "Entry changed since scan, preserving: $($entry.Key) [$($entry.View)]"; continue
        }
        $backup = Join-Path $session ("MDM-host-$n-$scope-$($entry.View).reg")
        $viewFlag = if ($entry.View -eq 'Registry32') { '/reg:32' } else { '/reg:64' }
        & $reg export $entry.Key $backup /y $viewFlag | Out-Null
        $rc = $LASTEXITCODE
        if ($rc -ne 0 -or -not [IO.File]::Exists($backup) -or (Get-Item -LiteralPath $backup).Length -lt 20) {
            Write-Warning "Backup failed, entry preserved: $($entry.Key) [$($entry.View)]"; continue
        }
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $backup).Hash
        $rec = [pscustomobject]@{Registry=$entry.Key;View=$entry.View;OriginalManifest=$entry.Manifest;Reason=$entry.Status;BackupFile=[IO.Path]::GetFileName($backup);SHA256=$hash;Deleted=$false}
        [void]$records.Add($rec)
        # Persist the verified backup manifest BEFORE deleting each key.
        [IO.File]::WriteAllText((Join-Path $session 'BACKUP-INDEX.json'),(ConvertTo-Json -InputObject @($records.ToArray()) -Depth 6),$utf8)
        $base = $null; $parent = $null
        try {
            $hive = if ($scope -eq 'HKCU') { [Microsoft.Win32.RegistryHive]::CurrentUser } else { [Microsoft.Win32.RegistryHive]::LocalMachine }
            $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, $view)
            $parentPath = $entry.Relative.Substring(0,$entry.Relative.LastIndexOf('\'))
            $parent = $base.OpenSubKey($parentPath,$true)
            if ($null -eq $parent) { throw 'Parent key disappeared.' }
            $last = Get-KeyDetails $scope $view $entry.Relative
            if ($null -eq $last -or $last.Manifest -cne $entry.Manifest -or (Classify $last) -cne $entry.Status) {
                throw 'Registry entry changed since backup; refusing deletion.'
            }
            # Nonrecursive removal: never touch a key if it gained subkeys.
            $parent.DeleteSubKey($HostName,$false)
            if ($null -ne (Get-KeyDetails $scope $view $entry.Relative)) { throw 'Key still exists after deletion.' }
            $rec.Deleted = $true
            [IO.File]::WriteAllText((Join-Path $session 'BACKUP-INDEX.json'),(ConvertTo-Json -InputObject @($records.ToArray()) -Depth 6),$utf8)
            Write-Host "REMOVED: $($entry.Key) [$($entry.View)]" -ForegroundColor Green
        } catch {
            Write-Warning "Could not remove $($entry.Key) [$($entry.View)]: $($_.Exception.Message)"
        } finally {
            if ($null -ne $parent) { $parent.Dispose() }
            if ($null -ne $base) { $base.Dispose() }
        }
    }
    Write-Host ''
    Write-Host "Backup directory: $session"
    Write-Host 'Restore is possible from the individual .reg backups, but examine each file first.'
    Write-Host 'Rerun Scan before starting the portable registration console.'
}

# ---------------------------------------------------------------------------
# One entry point, with small submenus. No nested CMD shells or second script.
# ---------------------------------------------------------------------------
function Invoke-Safely([scriptblock]$operation) {
    try { & $operation }
    catch { Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red }
}
function Confirm-Run([string]$expected,[string]$prompt,[scriptblock]$operation) {
    $answer = Read-Host $prompt
    if ($answer -cne $expected) { Write-Host 'Cancelled; nothing changed.'; return }
    Invoke-Safely $operation
}
function Browser-Menu {
    while ($true) {
        Write-Host ''
        Write-Host 'BROWSER INTEGRATION'
        Write-Host '1  Show portable registration + old host registrations (read-only)'
        Write-Host '2  Register / repair portable browser extension connection'
        Write-Host '3  Unregister ONLY this console-owned portable connection'
        Write-Host '4  Clean verified OLD per-user MDM registrations (backed up)'
        Write-Host '5  Clean verified OLD system-wide MDM registrations (admin)'
        Write-Host '0  Back to main menu'
        $choice = Read-Host 'Choose 0-5'
        switch ($choice) {
            '1' { Invoke-Safely { Get-RecordState; Print-Inventory @(Inventory) } }
            '2' { Invoke-Safely { Register-Portable } }
            '3' { Confirm-Run 'REMOVE' 'Type REMOVE to unregister console-owned portable keys' { Unregister-Portable } }
            '4' { Invoke-Safely { Remove-VerifiedLegacy 'HKCU' } }
            '5' { Invoke-Safely { Remove-VerifiedLegacy 'HKLM' } }
            '0' { return }
            default { Write-Host 'Choose 0, 1, 2, 3, 4 or 5.' }
        }
    }
}
function Startup-Menu {
    while ($true) {
        Write-Host ''
        Write-Host 'START WITH WINDOWS (optional, per-user only)'
        Write-Host '1  Show application and login-startup status'
        Write-Host '2  Enable login autostart'
        Write-Host '3  Disable owned login autostart'
        Write-Host '4  Repair owned autostart after folder relocation'
        Write-Host '0  Back to main menu'
        $choice = Read-Host 'Choose 0-4'
        switch ($choice) {
            '1' { Invoke-Safely { Status } }
            '2' { Confirm-Run 'ENABLE' 'Type ENABLE to create one HKCU Run entry' { Set-Autostart } }
            '3' { Confirm-Run 'DISABLE' 'Type DISABLE to remove only the owned HKCU Run entry' { Remove-Autostart } }
            '4' { Confirm-Run 'REPAIR' 'Type REPAIR to update only the owned stale target' { Set-Autostart } }
            '0' { return }
            default { Write-Host 'Choose 0, 1, 2, 3 or 4.' }
        }
    }
}
function Main-Menu {
    while ($true) {
        Write-Host ''
        Write-Host '============================================='
        Write-Host ' MISTER DOWNLOAD MANAGER - NATIVE CONTROL'
        Write-Host '============================================='
        Write-Host '1  Start MDM'
        Write-Host '2  Gracefully stop portable MDM'
        Write-Host '3  Application status'
        Write-Host '4  Browser integration and old-installation cleanup'
        Write-Host '5  Start with Windows (optional)'
        Write-Host '6  Open portable Data folder'
        Write-Host '0  Exit'
        $choice = Read-Host 'Choose 0-6'
        switch ($choice) {
            '1' { Invoke-Safely { Start-App } }
            '2' { Invoke-Safely { Stop-App } }
            '3' { Invoke-Safely { Status } }
            '4' { Browser-Menu }
            '5' { Startup-Menu }
            '6' { Invoke-Safely { if (Test-Path -LiteralPath $data) { Invoke-Item -LiteralPath $data } else { Write-Host 'Data directory not found.' } } }
            '0' { return }
            default { Write-Host 'Choose 0 through 6.' }
        }
    }
}
function Self-Test {
    # Only checks path resolution and function availability, never writes the
    # registry, opens the GUI, creates folders, or accesses user documents.
    if (-not [IO.Path]::IsPathRooted($root)) { throw 'Manager root not absolute.' }
    if ([string]::IsNullOrWhiteSpace($PSCommandPath)) { throw 'Manager PSCommandPath missing.' }
    if (-not [string]::Equals([IO.Path]::GetFileName($PSCommandPath), 'Manager.ps1', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Unexpected manager filename.'
    }
    foreach ($functionName in @('Start-App','Stop-App','Status','Get-RecordState',
                                'Register-Portable','Unregister-Portable','Inventory',
                                'Remove-VerifiedLegacy','Browser-Menu','Startup-Menu')) {
        if (-not (Get-Command $functionName -CommandType Function -ErrorAction SilentlyContinue)) {
            throw "Missing manager function: $functionName"
        }
    }
    Write-Host "SELF-TEST PASSED: integrated PowerShell 5.1 manager loaded from $root"
    Write-Host 'No registry, app, autostart or browser changes were made.'
}
switch ($Action) {
    'Menu' { Main-Menu }
    'Start' { Start-App }
    'Stop' { Stop-App }
    'Status' { Status }
    'BrowserStatus' { Get-RecordState; Print-Inventory @(Inventory) }
    'BrowserRegister' { Register-Portable }
    'BrowserUnregister' { Unregister-Portable }
    'LegacyScan' { Print-Inventory @(Inventory) }
    'LegacyCleanUser' { Remove-VerifiedLegacy 'HKCU' }
    'LegacyCleanMachine' { Remove-VerifiedLegacy 'HKLM' }
    'AutostartOn' { Set-Autostart }
    'AutostartOff' { Remove-Autostart }
    'RepairAutostart' { Set-Autostart }
    'SelfTest' { Self-Test }
}
