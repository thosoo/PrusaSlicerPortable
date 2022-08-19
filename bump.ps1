try {
  Import-Module PsIni
} catch {
  Install-Module -Scope CurrentUser PsIni
  Import-Module PsIni
}
$repoName = "prusa3d/prusaslicer"
$releasesUri = "https://api.github.com/repos/$repoName/releases/latest"
$tag = (Invoke-WebRequest $releasesUri | ConvertFrom-Json).tag_name
$tag2 = $tag.replace('version_','') -Replace '-.*',''

if ($tag2 -match 'alpha')
{
  Write-Host "Found alpha."
  echo "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
}
else if ($tag2 -match 'beta')
{
  Write-Host "Found beta."
  echo "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
}
else{
    echo "UPSTREAM_TAG=$tag" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    $appinfo = Get-IniContent ".\PrusaSlicerPortable\App\AppInfo\appinfo.ini"
    if ($appinfo["Version"]["DisplayVersion"] -ne $tag2){
        $appinfo["Version"]["PackageVersion"]=-join($tag2,".0")
        $appinfo["Version"]["DisplayVersion"]=$tag2




        $installer = Get-IniContent ".\PrusaSlicerPortable\App\AppInfo\installer.ini"

        $asset1Pattern = "*+win32*"
        $asset1 = (Invoke-WebRequest $releasesUri | ConvertFrom-Json).assets | Where-Object name -like $asset1Pattern
        $asset1Download = $asset1.browser_download_url.replace('%2B','+')
        $installer["DownloadFiles"]["DownloadURL"]=$asset1Download
        $installer["DownloadFiles"]["DownloadName"]=$asset1.name.replace('.zip','')
        $installer["DownloadFiles"]["DownloadFilename"]=$asset1.name

        $asset2Pattern = "*+win64*"
        $asset2 = (Invoke-WebRequest $releasesUri | ConvertFrom-Json).assets | Where-Object name -like $asset2Pattern
        $asset2Download = $asset2.browser_download_url.replace('%2B','+')
        $installer["DownloadFiles"]["Download2URL"]=$asset2Download
        $installer["DownloadFiles"]["Download2Name"]=$asset2.name.replace('.zip','')
        $installer["DownloadFiles"]["Download2Filename"]=$asset2.name
        $installer | Out-IniFile -Force -Encoding ASCII -Pretty -FilePath ".\PrusaSlicerPortable\App\AppInfo\installer.ini"

        $appinfo["Control"]["BaseAppID"]=-join("%BASELAUNCHERPATH%\App\",$asset1.name.replace('.zip',''),"\prusa-slicer.exe")
        $appinfo["Control"]["BaseAppID64"]=-join("%BASELAUNCHERPATH%\App\",$asset2.name.replace('.zip',''),"\prusa-slicer.exe")
        $appinfo | Out-IniFile -Force -Encoding ASCII -FilePath ".\PrusaSlicerPortable\App\AppInfo\appinfo.ini"

        $launcher = Get-IniContent ".\PrusaSlicerPortable\App\AppInfo\Launcher\PrusaSlicerPortable.ini"
        $launcher["Launch"]["ProgramExecutable"]=-join($asset1.name.replace('.zip',''),"\prusa-slicer.exe")
        $launcher["Launch"]["ProgramExecutable64"]=-join($asset2.name.replace('.zip',''),"\prusa-slicer.exe")
        $launcher | Out-IniFile -Force -Encoding ASCII -FilePath ".\PrusaSlicerPortable\App\AppInfo\Launcher\PrusaSlicerPortable.ini"
        Write-Host "Bumped to "+$tag
        echo "SHOULD_COMMIT=yes" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    }
    else{
      Write-Host "No changes."
      echo "SHOULD_COMMIT=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    }
}
