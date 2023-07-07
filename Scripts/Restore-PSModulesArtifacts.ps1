# Restore modules for Artifacts to first path in PSModulesPath
$ModulePath = $Env:PSModulePath.Split(';')[4]
$ArtifactModules = "$env:BUILD_ARTIFACTSTAGINGDIRECTORY\PSModules"
write-output "Restoring modules from $ArtifactModules to $ModulePath"
try {
    New-Item -ItemType Directory -Path $ModulePath -Force -ErrorAction Stop
    Get-ChildItem -Path $ArtifactModules | Copy-Item -Destination $modulepath -Force -Container -Recurse -ErrorAction Stop
    #Get-Module -ListAvailable | Select-Object Name,Path | Sort-Object Path,Name
}
Catch {
    Write-output $_.Exception.Message
}