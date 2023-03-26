# Set the repository name and API URL
$repoName = "prusa3d/prusaslicer"
$releasesUri = "https://api.github.com/repos/$repoName/releases/latest"

# Retrieve the latest release tag name
$tag = (Invoke-RestMethod $releasesUri).tag_name
Write-Host $tag

# Check if the tag contains "alpha", "beta", or "RC"
if ($tag -match "alpha|beta|RC") {
    # If tag contains one of these strings, set SHOULD_BUILD to "no"
    Write-Host "Found alpha, beta, or RC."
    echo "SHOULD_BUILD=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
} else{
    # If tag does not contain any of these strings, set UPSTREAM_TAG to the tag name
    echo "UPSTREAM_TAG=$tag" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    
    # Check the latest release tag for the portable version of PrusaSlicer
    $repoName2 = "thosoo/PrusaSlicerPortable"
    $releasesUri2 = "https://api.github.com/repos/$repoName2/releases/latest"
    $local_tag = (Invoke-RestMethod $releasesUri2).tag_name
    
    # If the local tag is not the same as the upstream tag, set SHOULD_BUILD to "yes"
    if ($local_tag -ne $tag){
        echo "SHOULD_BUILD=yes" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    }
    else{
        # If the local tag is the same as the upstream tag, set SHOULD_BUILD to "no"
        Write-Host "No changes."
        echo "SHOULD_BUILD=no" | Out-File -FilePath $Env:GITHUB_ENV -Encoding utf8 -Append
    }
}
