# 30 Day Overdue

A web app for filtering and exporting overdue devices from MDM device report CSVs.

Built by [c3dprints.com](https://c3dprints.com)

## Features

- Upload any device report CSV
- Filter devices by Last Seen date threshold (30/60/90+ days)
- Color-coded preview table
- Export formatted Excel file directly to your Downloads
- Works entirely in the browser — no data ever leaves your machine
- Installable as a PWA (works offline after first load)
- **Retired Devices tab** — pulls devices live from the GroundControl API and keeps only `Retired` ones

## Retired Devices (API) Tab

1. In the MAM/GroundControl admin console, create an API key
2. Open the **Retired Devices** tab and paste the key (optionally check **Remember key on this device** — it is stored only in your browser's localStorage, never in this repo)
3. Click **Fetch Retired Devices**, then **Download Excel**

If the fetch fails with a CORS error (the API blocks calls made from a web page),
use the `Get-RetiredDevices.ps1` script in this repo instead — it pulls the same
report from PowerShell and saves it as a CSV you can drop into Excel:

```powershell
.\Get-RetiredDevices.ps1
```

If your API documentation (behind the MAM login) shows a different endpoint than
`devices/get/all`, you can change it in the tab's **Endpoint** field or via the
script's `-Endpoint` parameter.

## How to Use

1. Go to the live site
2. Drop your CSV file onto the upload area
3. Set your day threshold (default: 30)
4. Click **Generate Excel**
5. Your color-coded Excel file downloads automatically

## Hosting on GitHub Pages

1. Fork or clone this repo
2. Go to **Settings → Pages**
3. Set source to **main branch / root**
4. Your app will be live at `https://yourusername.github.io/repo-name`

## Local Use

Just open `index.html` in any modern browser — no server needed.
