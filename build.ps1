$directoryPath = (Get-Location).Path
$name = Split-Path -Path $directoryPath -Leaf
Get-ChildItem $directoryPath

Write-Host "Starting Launcher Generator"
$launcherGeneratorPath = "D:\a\$name\$name\PortableApps.comLauncher\PortableApps.comLauncherGenerator.exe"
Start-Process -FilePath $launcherGeneratorPath -ArgumentList "D:\a\$name\$name\$name" -NoNewWindow -Wait

Write-Host "Starting Installer Generator"
$installerGeneratorPath = "D:\a\$name\$name\PortableApps.comInstaller\PortableApps.comInstaller.exe"
Start-Process -FilePath $installerGeneratorPath -ArgumentList "D:\a\$name\$name\$name" -NoNewWindow -Wait

Get-ChildItem $directoryPath
