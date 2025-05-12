# Import PsIni module, install it if not found
$module = Get-Module -Name PsIni -ErrorAction SilentlyContinue
if (!$module) {
    Install-Module -Scope CurrentUser PsIni
    Import-Module PsIni
} else {
    Import-Module PsIni
}

# Define repository name and API endpoint
$repoName     = "prusa3d/prusaslicer"
$releasesUri  = "https://api.github.com/repos/$repoName/releases/latest"

# Retrieve latest tag from API endpoint
try {
    $tag = (Invoke-RestMethod -Uri $releasesUri).tag_name
} catch {
    Write-Host "Error while pulling API."
    "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    break
}

$tag2 = $tag -replace 'version_',''        # e.g. 2.9.2
Write-Host "Latest tag: $tag2"

if ($tag2 -match 'alpha|beta|RC') {
    Write-Host "Found alpha, beta, or RC — skipping."
    "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    return
}

"UPSTREAM_TAG=$tag2" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append

# -------------------------------------------------------------------
# 1) Read the current appinfo.ini to see if we already have this build
# -------------------------------------------------------------------
$appinfo = Get-IniContent ".\PrusaSlicerPortable\App\AppInfo\appinfo.ini"
if ($appinfo["Version"]["DisplayVersion"] -eq $tag2) {
    Write-Host "No version change — nothing to do."
    "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    return
}

# -------------------------------------------------------------------
# 2) Grab the 64-bit ZIP asset and figure out its naming parts
# -------------------------------------------------------------------
$assetPattern  = "*win64*.zip"
$asset         = (Invoke-WebRequest $releasesUri | ConvertFrom-Json).assets |
                 Where-Object name -like $assetPattern |
                 Select-Object -First 1

if (-not $asset) {
    Write-Host "Could not find a win64 asset in the release assets."
    "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    return
}

$archiveName   = $asset.name                  # PrusaSlicer-2.9.2-win64.zip
$archiveBase   = $archiveName -replace '\.zip$',''          # PrusaSlicer-2.9.2-win64
$innerDirName  = $archiveBase -replace '-win64$',''         # PrusaSlicer-2.9.2
$archiveUrl    = $asset.browser_download_url -replace '%2B','+'

Write-Host "Asset found: $archiveName"
Write-Host "  inner folder  : $innerDirName"
Write-Host "  outer folder  : $archiveBase"

# -------------------------------------------------------------------
# 3) UPDATE installer.ini (new double-extract fields highlighted)
# -------------------------------------------------------------------
$installer = Get-IniContent ".\PrusaSlicerPortable\App\AppInfo\installer.ini"

$installer["DownloadFiles"]["DownloadURL"]          = $archiveUrl
$installer["DownloadFiles"]["DownloadName"]         = $archiveBase
$installer["DownloadFiles"]["DownloadFilename"]     = $archiveName

# *** NEW / UPDATED ***
$installer["DownloadFiles"]["DoubleExtractFilename"]    = $innerDirName
$installer["DownloadFiles"]["DoubleExtract1To"]         = "App\${archiveBase}"
$installer["DownloadFiles"]["DoubleExtract1Filter"]     = "**"
$installer["DownloadFiles"]["CustomCodeUses7zip"]       = "true"
# **********************

$installer | Out-IniFile -Force -Encoding ASCII -Pretty `
           -FilePath ".\PrusaSlicerPortable\App\AppInfo\installer.ini"

# -------------------------------------------------------------------
# 4) UPDATE appinfo.ini
# -------------------------------------------------------------------
$appinfo["Version"]["PackageVersion"] = "$tag2.0"
$appinfo["Version"]["DisplayVersion"] =  $tag2
$appinfo["Control"]["BaseAppID64"]    = "%BASELAUNCHERPATH%\App\${archiveBase}\prusa-slicer.exe"

$appinfo | Out-IniFile -Force -Encoding ASCII `
         -FilePath ".\PrusaSlicerPortable\App\AppInfo\appinfo.ini"

# -------------------------------------------------------------------
# 5) UPDATE PrusaSlicerPortable.ini launcher
# -------------------------------------------------------------------
$launcher = Get-IniContent ".\PrusaSlicerPortable\App\AppInfo\Launcher\PrusaSlicerPortable.ini"
$launcher["Launch"]["ProgramExecutable64"] = "${archiveBase}\prusa-slicer.exe"

$launcher | Out-IniFile -Force -Encoding ASCII `
          -FilePath ".\PrusaSlicerPortable\App\AppInfo\Launcher\PrusaSlicerPortable.ini"

# -------------------------------------------------------------------
# 6) All done – tell CI to commit the changes
# -------------------------------------------------------------------
Write-Host "Bumped to $tag2"
"SHOULD_COMMIT=yes" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
