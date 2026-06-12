<#
.SYNOPSIS
  Pulls retired devices from the GroundControl (Imprivata MAM) API and saves them to a CSV.

  The public API reference is gated behind the MAM login, so this script probes the
  likely host/path/auth-header combinations with your key until one works, tells you
  which combination succeeded, then filters for Retired devices and exports a CSV.

.USAGE
  .\Get-RetiredDevices.ps1
  .\Get-RetiredDevices.ps1 -Url "https://api.groundctl.com/v1/devices/get/all"   # skip probing
#>
param(
    [string]$Url,
    [string]$OutFile = "Retired Devices.csv"
)

$apiKey = Read-Host -AsSecureString -Prompt "Paste your GroundControl API key"
$apiKeyPlain = [System.Net.NetworkCredential]::new("", $apiKey).Password

$candidateUrls = if ($Url) { @($Url) } else {
    @(
        "https://api.groundctl.com/v1/devices/get/all",
        "https://api.groundctl.com/devices/get/all",
        "https://api.groundctl.com/v1/devices",
        "https://api.groundctl.com/v1/devices/find",
        "https://www.groundctl.com/api/v1/devices/get/all",
        "https://www.groundctl.com/api/v1/devices"
    )
}

# x-api-key first: api.groundctl.com is AWS API Gateway, which uses it
$authStyles = @(
    @{ "x-api-key" = $apiKeyPlain },
    @{ Authorization = "Bearer $apiKeyPlain" },
    @{ Authorization = "Token $apiKeyPlain" }
)

$data = $null
$attempts = @()
foreach ($u in $candidateUrls) {
    foreach ($auth in $authStyles) {
        $authName = ($auth.Keys | Select-Object -First 1)
        $authDesc = if ($authName -eq "Authorization") { ($auth[$authName] -split ' ')[0] } else { $authName }
        try {
            $resp = Invoke-WebRequest -Uri $u -Headers ($auth + @{ Accept = "application/json" }) -SkipHttpErrorCheck -ErrorAction Stop
            $attempts += "  $u [$authDesc] => HTTP $($resp.StatusCode)"
            if ($resp.StatusCode -eq 200 -and $resp.Headers['Content-Type'] -like "*json*") {
                Write-Host "SUCCESS: $u with auth header '$authDesc'" -ForegroundColor Green
                $data = $resp.Content | ConvertFrom-Json
                break
            }
        } catch {
            $attempts += "  $u [$authDesc] => $($_.Exception.Message)"
        }
    }
    if ($data) { break }
}

if (-not $data) {
    Write-Host "No combination worked. Attempts:" -ForegroundColor Red
    $attempts | ForEach-Object { Write-Host $_ }
    Write-Host "`nNext step: grab the endpoint URL + auth header from the API docs inside your MAM admin console." -ForegroundColor Yellow
    exit 1
}

# Accept a bare array or the usual wrapper property names
$devices = if ($data -is [array]) { $data }
           elseif ($data.devices) { $data.devices }
           elseif ($data.data)    { $data.data }
           elseif ($data.results) { $data.results }
           elseif ($data.items)   { $data.items }
           else { throw "Got a response, but couldn't find a device list in it. First 500 chars: $(($data | ConvertTo-Json -Depth 2).Substring(0, 500))" }

$retired = $devices | Where-Object {
    $d = $_
    $d.PSObject.Properties | Where-Object {
        $_.Name -like "*status*" -and "$($_.Value)" -like "*retired*"
    }
}

Write-Host "Found $(@($retired).Count) retired of $(@($devices).Count) total devices."
$retired | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
Write-Host "Saved to $OutFile"
