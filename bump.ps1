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
$appinfo = Get-IniContent ".\PrusaSlicerPortable\App\AppInfo\appinfo.ini"
$appinfo["Version"]["PackageVersion"]=-join($tag2,".0")
$appinfo["Version"]["DisplayVersion"]=$tag2




$installer = Get-IniContent ".\PrusaSlicerPortable\App\AppInfo\installer.ini"

$asset1Pattern = "*+win32*"
$asset1 = (Invoke-WebRequest $releasesUri | ConvertFrom-Json).assets | Where-Object name -like $asset1Pattern
$asset1Download = $asset1.browser_download_url
$installer["DownloadFiles"]["DownloadURL"]=$asset1Download
$installer["DownloadFiles"]["DownloadFilename"]=$asset1.name

$asset2Pattern = "*+win64*"
$asset2 = (Invoke-WebRequest $releasesUri | ConvertFrom-Json).assets | Where-Object name -like $asset2Pattern
$asset2Download = $asset2.browser_download_url
$installer["DownloadFiles"]["Download2URL"]=$asset2Download
$installer["DownloadFiles"]["Download2Filename"]=$asset2.name
$installer | Out-IniFile -Force -FilePath ".\PrusaSlicerPortable\App\AppInfo\installer.ini"

$appinfo["Control"]["BaseAppID"]=-join("%BASELAUNCHERPATH%\App\",$asset1.name.replace('.zip',''),"\prusa-slicer.exe")
$appinfo["Control"]["BaseAppID64"]=-join("%BASELAUNCHERPATH%\App\",$asset2.name.replace('.zip',''),"\prusa-slicer.exe")
$appinfo | Out-IniFile -Force -FilePath ".\PrusaSlicerPortable\App\AppInfo\appinfo.ini"

$launcher = Get-IniContent ".\PrusaSlicerPortable\App\AppInfo\Launcher\PrusaSlicerPortable.ini"
$launcher["Launch"]["ProgramExecutable"]=-join($asset1.name.replace('.zip',''),"\prusa-slicer.exe")
$launcher["Launch"]["ProgramExecutable64"]=-join($asset2.name.replace('.zip',''),"\prusa-slicer.exe")
$launcher | Out-IniFile -Force -FilePath ".\PrusaSlicerPortable\App\AppInfo\Launcher\PrusaSlicerPortable.ini"
