# Import PsIni module, install it if not found
$module = Get-Module -Name PsIni -ErrorAction SilentlyContinue
if (!$module) {
    Install-Module -Scope CurrentUser PsIni
    Import-Module PsIni
} else {
    Import-Module PsIni
}

# ------------------------------------------------------------
# 0) BASIC CONSTANTS
# ------------------------------------------------------------
$repoName    = "prusa3d/prusaslicer"
$releasesUri = "https://api.github.com/repos/$repoName/releases/latest"

# Folder that holds the portable app sources
$root = ".\\PrusaSlicerPortable"

# ------------------------------------------------------------
# 1) GET LATEST STABLE TAG
# ------------------------------------------------------------
try {
    $tag = (Invoke-RestMethod -Uri $releasesUri).tag_name  # version_2.9.2
} catch {
    Write-Host "Error while pulling API."
    "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    return
}

$tag2 = $tag -replace 'version_',''          # 2.9.2
Write-Host "Latest tag: $tag2"

if ($tag2 -match 'alpha|beta|RC') {
    Write-Host "Found alpha/beta/RC — skipping."
    "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    return
}

"UPSTREAM_TAG=$tag2" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append

# ------------------------------------------------------------
# 2) STOP IF WE ALREADY HAVE THIS VERSION
# ------------------------------------------------------------
$appInfoPath = "$root\\App\\AppInfo\\appinfo.ini"
$appinfo     = Get-IniContent $appInfoPath
if ($appinfo["Version"]["DisplayVersion"] -eq $tag2) {
    Write-Host "No version change — nothing to do."
    "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    return
}

# ------------------------------------------------------------
# 3) FIND THE 64-BIT ZIP ASSET
# ------------------------------------------------------------
$assetPattern = "*win64*.zip"
$asset        = (Invoke-WebRequest $releasesUri | ConvertFrom-Json).assets |
                Where-Object name -like $assetPattern |
                Select-Object -First 1

if (-not $asset) {
    Write-Host "No win64 asset found."
    "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    return
}

$archiveName  = $asset.name                    # PrusaSlicer-2.9.2-win64.zip
$archiveBase  = $archiveName -replace '\.zip$',''      # PrusaSlicer-2.9.2-win64
$innerDir     = $archiveBase -replace '-win64$',''     # PrusaSlicer-2.9.2
$archiveUrl   = $asset.browser_download_url -replace '%2B','+'

Write-Host "Asset: $archiveName"
Write-Host "  Inner folder: $innerDir"
Write-Host "  Target folder: $archiveBase"

# ------------------------------------------------------------
# 4) UPDATE installer.ini
#      (simple 1-level extract; rename handled in .nsh)
# ------------------------------------------------------------
$installerPath = "$root\\App\\AppInfo\\installer.ini"
$installer     = Get-IniContent $installerPath

$dl            = $installer["DownloadFiles"]
$dl["DownloadURL"]             = $archiveUrl
$dl["DownloadName"]            = $archiveBase
$dl["DownloadFilename"]        = $archiveName

# Ensure we use *AdvancedExtract* (single-level) and remove any DoubleExtract keys
$dl["AdvancedExtract1To"]      = "App"
$dl["AdvancedExtract1Filter"]  = "**"

$dl.Remove("DoubleExtractFilename")  > $null
$dl.Remove("DoubleExtract1To")       > $null
$dl.Remove("DoubleExtract1Filter")   > $null

$dl["CustomCodeUses7zip"]       = "true"

$installer | Out-IniFile -Force -Encoding ASCII -Pretty -FilePath $installerPath

# ------------------------------------------------------------
# 5) WRITE / UPDATE PortableApps.comInstallerCustom.nsh
# ------------------------------------------------------------
$customDir  = "$root\\Other\\Source"
$customFile = "$customDir\\PortableApps.comInstallerCustom.nsh"

if (!(Test-Path $customDir)) { New-Item -ItemType Directory -Path $customDir -Force | Out-Null }

$customNSIS = @"
!macro CustomCodePostInstall
    \${If} \${FileExists} "\$INSTDIR\\App\\$innerDir"
        Rename "\$INSTDIR\\App\\$innerDir" "\$INSTDIR\\App\\$archiveBase"
    \${EndIf}
!macroend
"@
Set-Content -Path $customFile -Value $customNSIS -Encoding ASCII

# ------------------------------------------------------------
# 6) UPDATE appinfo.ini AND LAUNCHER
# ------------------------------------------------------------
$appinfo["Version"]["PackageVersion"] = "$tag2.0"
$appinfo["Version"]["DisplayVersion"] =  $tag2
$appinfo["Control"]["BaseAppID64"]    = "%BASELAUNCHERPATH%\\App\\$archiveBase\\prusa-slicer.exe"
$appinfo | Out-IniFile -Force -Encoding ASCII -FilePath $appInfoPath

$launcherPath = "$root\\App\\AppInfo\\Launcher\\PrusaSlicerPortable.ini"
$launcher     = Get-IniContent $launcherPath
$launcher["Launch"]["ProgramExecutable64"] = "$archiveBase\\prusa-slicer.exe"
$launcher | Out-IniFile -Force -Encoding ASCII -FilePath $launcherPath

# ------------------------------------------------------------
# 7) DONE
# ------------------------------------------------------------
Write-Host "Bumped to $tag2"
"SHOULD_COMMIT=yes" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
