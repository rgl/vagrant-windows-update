# see Using the Windows Update Agent API | Searching, Downloading, and Installing Updates
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa387102(v=vs.85).aspx
# see ISystemInformation interface
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386095(v=vs.85).aspx
# see IUpdateSession interface
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386854(v=vs.85).aspx
# see IUpdateSearcher interface
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386515(v=vs.85).aspx
# see IUpdateDownloader interface
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386131(v=vs.85).aspx
# see IUpdateCollection interface
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386107(v=vs.85).aspx
# see IUpdate interface
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386099(v=vs.85).aspx

Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'

trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}

Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class Windows
{
    [DllImport("kernel32", SetLastError=true)]
    public static extern UInt64 GetTickCount64();

    public static TimeSpan GetUptime()
    {
        return TimeSpan.FromMilliseconds(GetTickCount64());
    }
}
'@

function Wait-Condition {
    param(
      [scriptblock]$Condition,
      [int]$DebounceSeconds=15
    )
    process {
        $begin = [Windows]::GetUptime()
        do {
            Start-Sleep -Seconds 1
            try {
              $result = &$Condition
            } catch {
              $result = $false
            }
            if (-not $result) {
                $begin = [Windows]::GetUptime()
                continue
            }
        } while ((([Windows]::GetUptime()) - $begin).TotalSeconds -lt $DebounceSeconds)
    }
}

function ExitWhenRebootRequired([bool]$forceReboot=$false) {
    $rebootRequired = $forceReboot

    # check for pending Windows Updates.
    if (!$rebootRequired) {
        $systemInformation = New-Object -ComObject 'Microsoft.Update.SystemInfo'
        $rebootRequired = $rebootRequired -or $systemInformation.RebootRequired
    }

    # check for pending Windows Features.
    if (!$rebootRequired) {
        $pendingPackagesKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending'
        $pendingPackagesCount = (Get-ChildItem -ErrorAction SilentlyContinue $pendingPackagesKey | Measure-Object).Count
        $rebootRequired = $rebootRequired -or $pendingPackagesCount -gt 0
    }

    if ($rebootRequired) {
        if (!$forceReboot) {
            Write-Output 'Pending Reboot detected. Waiting for the Windows Modules Installer to exit...'
            Wait-Condition {(Get-Process -ErrorAction SilentlyContinue TiWorker,TrustedInstaller | Measure-Object).Count -eq 0}
        }
        Write-Output 'Rebooting...'
        Exit 0
    }
}

ExitWhenRebootRequired

$updateSession = New-Object -ComObject 'Microsoft.Update.Session'
$updateSession.ClientApplicationID = 'vagrant-windows-update'

Write-Output 'Searching for Windows updates...'
$updatesToDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl'
$updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'
$updateSearcher = $updateSession.CreateUpdateSearcher()
$searchResult = $updateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
for ($i = 0; $i -lt $searchResult.Updates.Count; ++$i) {
    $update = $searchResult.Updates.Item($i)

    if ($update.InstallationBehavior.CanRequestUserInput) {
        continue
    }

    if (!$update.AutoSelectOnWebSites) {
        continue
    }

    $updateDate = $update.LastDeploymentChangeTime.ToString('yyyy-MM-dd')
    $updateSize = ($update.MaxDownloadSize/1024/1024).ToString('0.##')
    Write-Output "Found Windows update ($updateDate; $updateSize MB): $($update.Title)"

    $update.AcceptEula() | Out-Null

    if (!$update.IsDownloaded) {
        $updatesToDownload.Add($update) | Out-Null
    }

    $updatesToInstall.Add($update) | Out-Null
}

if ($updatesToDownload.Count) {
    Write-Output 'Downloading Windows updates...'
    $updateDownloader = $updateSession.CreateUpdateDownloader()
    $updateDownloader.Updates = $updatesToDownload
    $updateDownloader.Download() | Out-Null
}

if ($updatesToInstall.Count) {
    Write-Output 'Installing Windows updates...'
    $updateInstaller = $updateSession.CreateUpdateInstaller()
    $updateInstaller.Updates = $updatesToInstall
    $installResult = $updateInstaller.Install()
    ExitWhenRebootRequired $true
    Exit 0
}

Write-Output 'No Windows updates found'
