$results = @()
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$totalMemory = $osInfo.TotalVisibleMemorySize

while($true) {
    $freeMemory = (Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory
    $usedMemory = $totalMemory - $freeMemory
    $usedMemoryPercent = $usedMemory * 100 / $totalMemory
    $results += [PSCustomObject]@{
        Date = Get-Date -Format "yyyyMMdd-HHmmss"
        UsedMemoryPercent = $usedMemoryPercent
    }
    Start-Sleep -Seconds 1
}
$results | Export-Csv -Path ".\ram-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"