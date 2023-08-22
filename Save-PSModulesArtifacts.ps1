# Save all modules as pipeline artifacts
$modulesPath = ($env:PSModulePath -split ';')[4] 
# Write-Output -message "modulepaths: ($env:PSModulePath -split ';')" use this to find right path
#New-Item -ItemType Directory -Path $(Build.ArtifactStagingDirectory)/modules
$BuildArtifactsDirectory = $env:Build_ArtifactStagingDirectory
New-Item -ItemType Directory -Path $BuildArtifactsDirectory/modules
Copy-Item -Path $modulesPath -Destination $BuildArtifactsDirectory/modules -Recurse
Publish-PipelineArtifact -Path $BuildArtifactsDirectory/modules -ArtifactName "PowerShellModules"
