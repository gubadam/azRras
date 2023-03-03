$Host.UI.RawUI.WindowTitle = 'cpu'

$results = @()
while ($true) {
    $result = [PSCustomObject]@{
        Date = Get-Date -Format 'yyyyMMdd-HHmmss'
    }

    $CpuInfo = Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Processor ` | Select-Object Name, PercentProcessorTime
    $CpuInfo | ForEach-Object {
        Add-Member -InputObject $result -MemberType NoteProperty -Name $_.Name  -Value $_.PercentProcessorTime
    }
    $results += $result
    Start-Sleep -Seconds 1
}
$results | Export-Csv -Path ".\cpu-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"