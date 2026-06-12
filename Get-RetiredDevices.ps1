<#
.SYNOPSIS
  Pulls retired devices from the GroundControl (Imprivata MAM) API and saves them to a CSV.

  Fallback for the "Retired Devices" tab in index.html — use this if the browser
  blocks the API call (CORS). The CSV it produces can be opened directly in Excel.

.USAGE
  .\Get-RetiredDevices.ps1
  .\Get-RetiredDevices.ps1 -Endpoint "devices/get/all" -OutFile "Retired Devices.csv"
#>
param(
    [string]$Endpoint = "devices/get/all",
    [string]$OutFile = "Retired Devices.csv"
)

$apiBase = "https://www.groundctl.com/api/v1"
$apiKey = Read-Host -AsSecureString -Prompt "Paste your GroundControl API key"
$apiKeyPlain = [System.Net.NetworkCredential]::new("", $apiKey).Password

$url = "$apiBase/$($Endpoint.TrimStart('/'))"

# The exact auth header scheme isn't published publicly — try the common ones.
$authStyles = @(
    @{ Authorization = "Bearer $apiKeyPlain" },
    @{ "X-API-Key" = $apiKeyPlain },
    @{ Authorization = "Token $apiKeyPlain" }
)

$data = $null
foreach ($auth in $authStyles) {
    try {
        $data = Invoke-RestMethod -Uri $url -Headers ($auth + @{ Accept = "application/json" })
        break
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        if ($status -in 401, 403) { continue }
        throw "API request failed (HTTP $status): $($_.Exception.Message)"
    }
}
if (-not $data) { throw "Authentication failed with every auth header style. Check your API key." }

# Accept a bare array or the usual wrapper property names
$devices = if ($data -is [array]) { $data }
           elseif ($data.devices) { $data.devices }
           elseif ($data.data)    { $data.data }
           elseif ($data.results) { $data.results }
           else { throw "Unexpected API response shape — could not find a device list." }

$retired = $devices | Where-Object {
    $d = $_
    $d.PSObject.Properties | Where-Object {
        $_.Name -like "*status*" -and "$($_.Value)" -like "*retired*"
    }
}

Write-Host "Found $(@($retired).Count) retired of $(@($devices).Count) total devices."
$retired | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
Write-Host "Saved to $OutFile"
