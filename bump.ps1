# Import PsIni module, install it if not found
$module = Get-Module -Name PsIni -ErrorAction SilentlyContinue
if (!$module) {
    Install-Module -Scope CurrentUser PsIni
    Import-Module PsIni
} else {
    Import-Module PsIni
}

# Define repository name and API endpoint
$repoName = "prusa3d/prusaslicer"
$releasesUri = "https://api.github.com/repos/$repoName/releases/latest"

# Retrieve latest tag from API endpoint
try {
    $tag = (Invoke-RestMethod -Uri $releasesUri).tag_name
} catch {
    Write-Host "Error while pulling API."
    echo "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    break
}
$tag2 = $tag.replace('version_','') #-Replace '-.*',''
Write-Host $tag2
if ($tag2 -match "alpha|beta|RC") {
    # If tag contains one of these strings, set SHOULD_COMMIT to "no"
    Write-Host "Found alpha, beta, or RC."
    echo "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
} else{
    # Set the UPSTREAM_TAG variable in the GitHub environment file
    echo "UPSTREAM_TAG=$tag2" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append

    # Get the contents of the appinfo.ini file and check if the DisplayVersion matches the tag
    $appinfo = Get-IniContent ".\PrusaSlicerPortable\App\AppInfo\appinfo.ini"
    if ($appinfo["Version"]["DisplayVersion"] -ne $tag2){

        # Update the PackageVersion and DisplayVersion in appinfo.ini
        $appinfo["Version"]["PackageVersion"]=-join($tag2,".0")
        $appinfo["Version"]["DisplayVersion"]=$tag2

        # Get the contents of the installer.ini file
        $installer = Get-IniContent ".\PrusaSlicerPortable\App\AppInfo\installer.ini"

        # Find the asset matching the win64 pattern and update the DownloadURL, DownloadName, and DownloadFilename in installer.ini
        $asset1Pattern = "*+win64*"
        $asset1 = (Invoke-WebRequest $releasesUri | ConvertFrom-Json).assets | Where-Object name -like $asset1Pattern
        $asset1Download = $asset1.browser_download_url.replace('%2B','+')
        $installer["DownloadFiles"]["DownloadURL"]=$asset1Download
        $installer["DownloadFiles"]["DownloadName"]=$asset1.name.replace('.zip','')
        $installer["DownloadFiles"]["DownloadFilename"]=$asset1.name

        # Write the updated installer.ini file
        $installer | Out-IniFile -Force -Encoding ASCII -Pretty -FilePath ".\PrusaSlicerPortable\App\AppInfo\installer.ini"

        # Update the BaseAppID64 in appinfo.ini
        $appinfo["Control"]["BaseAppID64"]=-join("%BASELAUNCHERPATH%\App\",$asset1.name.replace('.zip',''),"\prusa-slicer.exe")

        # Write the updated appinfo.ini file
        $appinfo | Out-IniFile -Force -Encoding ASCII -FilePath ".\PrusaSlicerPortable\App\AppInfo\appinfo.ini"

        # Get the contents of the PrusaSlicerPortable.ini file and update the ProgramExecutable64 field
        $launcher = Get-IniContent ".\PrusaSlicerPortable\App\AppInfo\Launcher\PrusaSlicerPortable.ini"
        $launcher["Launch"]["ProgramExecutable64"]=-join($asset1.name.replace('_signed.zip',''),"\prusa-slicer.exe")

        # Write the updated PrusaSlicerPortable.ini file
        $launcher | Out-IniFile -Force -Encoding ASCII -FilePath ".\PrusaSlicerPortable\App\AppInfo\Launcher\PrusaSlicerPortable.ini"

        # Print a message indicating the version has been bumped and set SHOULD_COMMIT to yes in the GitHub environment file
        Write-Host "Bumped to "+$tag2
        echo "SHOULD_COMMIT=yes" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    }
    else{
      Write-Host "No changes."
      echo "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    } 
}
