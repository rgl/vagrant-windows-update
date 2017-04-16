Set-StrictMode -Version Latest

$ErrorActionPreference = 'Stop'

trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Exit 1
}

Write-Output 'Windows update history:'
$updateSearcher = (New-Object -ComObject 'Microsoft.Update.Session').CreateUpdateSearcher()
$updateSearcher.QueryHistory(0, $updateSearcher.GetTotalHistoryCount()) `
    | Where-Object {$_.ResultCode -ne $null} `
    | ForEach-Object {
        $result = switch ($_.ResultCode) {
            0 { 'NotStarted' }
            1 { 'InProgress' }
            2 { 'Succeeded' }
            3 { 'SucceededWithErrors' }
            4 { 'Failed' }
            5 { 'Aborted' }
            default { $_ }
        }
        New-Object -TypeName PSObject -Property @{
            Date = $_.Date
            By = $_.ClientApplicationID
            Result = $result
            Title = $_.Title
        }
    } `
    | Sort-Object -Descending Date `
    | Format-Table -Property Date,Result,By,Title -AutoSize `
    | Out-String -Stream -Width ([int]::MaxValue) `
    | ForEach-Object {$_.TrimEnd()}
