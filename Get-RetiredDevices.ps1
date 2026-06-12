<#
.SYNOPSIS
  Pulls retired devices from the Imprivata Mobile Access Management (GroundControl)
  REST API and saves them to a CSV.

  Per the MAM OpenAPI spec: GET /api/v1/devices/find/all with the API key passed
  as an api_key query parameter. Create a key under Admin > API in the MAM console.

.USAGE
  .\Get-RetiredDevices.ps1
  .\Get-RetiredDevices.ps1 -Status Active            # report a different status
  .\Get-RetiredDevices.ps1 -OutFile "Retired.csv"
#>
param(
    [string]$Url = "https://www.groundctl.com/api/v1/devices/find/all",
    [string]$Status = "Retired",
    [string]$OutFile = "Retired Devices.csv"
)

$apiKey = Read-Host -AsSecureString -Prompt "Paste your MAM API key (Admin > API)"
$apiKeyPlain = [System.Net.NetworkCredential]::new("", $apiKey).Password

$sep = if ($Url.Contains('?')) { '&' } else { '?' }
$devices = Invoke-RestMethod -Uri "$Url$($sep)api_key=$([uri]::EscapeDataString($apiKeyPlain))" -Headers @{ Accept = "application/json" }

$matched = @($devices | Where-Object { "$($_.status)" -ieq $Status })
Write-Host "Found $($matched.Count) $Status of $(@($devices).Count) total devices."

if (-not $matched.Count) { Write-Host "Nothing to export."; exit 0 }

# Flatten: keep scalar fields, lift customFieldValues [{name, value}] into columns
$rows = foreach ($d in $matched) {
    $o = [ordered]@{}
    foreach ($p in $d.PSObject.Properties) {
        if ($p.Value -is [array] -or $p.Value -is [System.Management.Automation.PSCustomObject]) { continue }
        $o[$p.Name] = $p.Value
    }
    foreach ($f in @($d.customFieldValues)) {
        if ($f.name) { $o[$f.name] = $f.value }
    }
    [pscustomobject]$o
}

# Devices can differ in which custom fields they carry — give every row the
# full column set so Export-Csv doesn't drop columns missing from the first row
$allCols = [System.Collections.Generic.List[string]]::new()
foreach ($r in $rows) {
    foreach ($p in $r.PSObject.Properties.Name) {
        if (-not $allCols.Contains($p)) { $allCols.Add($p) }
    }
}

# Column order matching the "Retired Devices" report; any fields not listed
# here are appended after, in the order they came back from the API
$preferredOrder = @(
    'serial', 'name', 'modelName', 'lastLaunchpadName', 'Imprivata Display Name',
    'status', 'retireReason', 'lastSeen', 'Device Home', 'os', 'firstSeen',
    'activeSince', 'Phone Notes', 'Imprivata Email', 'Launchpad', 'Device User',
    'Out of Service'
)
$ordered = @($preferredOrder | Where-Object { $allCols -contains $_ }) +
           @($allCols | Where-Object { $preferredOrder -notcontains $_ })

$rows | Select-Object $ordered | Export-Csv -Path $OutFile -NoTypeInformation -Encoding UTF8
Write-Host "Saved to $OutFile"
