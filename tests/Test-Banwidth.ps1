param (
        $vpnFqdn = 'vpn.guba.net.pl',
        $clients = @(
                'vmTest',
                'vmTest-0',
                'vmTest-1',
                'vmTest-2'
        ),
        $server = '172.20.0.1'
)

$Host.UI.RawUI.WindowTitle = 'test'

#region StartServer
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://iperf.fr/download/windows/iperf-3.1.3-win64.zip" -OutFile "iperf-3.1.3-win64.zip"
Expand-Archive "iperf-3.1.3-win64.zip" -DestinationPath "iperf3" -ErrorAction SilentlyContinue

$vmCount = $clients.Count
foreach($port in (5201..(5201+$vmCount-1))) {
        Start-Process ".\iperf3\iperf-3.1.3-win64\iperf3.exe" -ArgumentList "-s -p $port" -PassThru | Out-Null #-NoNewWindow -Wait
}
#endregion StartServer

$jobs = @()
$iterator = 0
foreach ($client in $clients) {
        
        $jobs += Invoke-Command -ComputerName $client -JobName $client -AsJob -ScriptBlock {
                rasdial $using:vpnFqdn | Out-Null
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri "https://iperf.fr/download/windows/iperf-3.1.3-win64.zip" -OutFile "iperf-3.1.3-win64.zip" -ErrorAction SilentlyContinue
                Expand-Archive "iperf-3.1.3-win64.zip" -DestinationPath "iperf3" -Force
                $clientOutput = & ".\iperf3\iperf-3.1.3-win64\iperf3.exe" --client $using:server -p $(5201 + $using:iterator) -t 60 <#--reverse#> --json
                rasdial $using:vpnFqdn /disconnect | Out-Null
                $clientOutput
        }
        $iterator++
}
$jobs | Wait-Job | Out-Null

$clientOutputs = $jobs | ForEach-Object {
        [PSCustomObject]@{
                Name = $_.Name
                Output = $_ | Receive-Job
        }
} 

$clientOutputs | ForEach-Object {
        $json = $_.Output | Convertfrom-Json
        [PSCustomObject]@{
                vmName = $_.Name
                # $($json.end.streams.sender.bits_per_second)
                'Tx Mbps' = ($($json.end.streams.sender.bits_per_second)/1MB).ToString("#.##")
        }
}