<# Ensure package provider is installed
if (-not (Get-PackageProvider -Name "NuGet" -ErrorAction SilentlyContinue)) {
    Write-Output -InputObject "NuGet package provider not found. Installing..."
    $PackageProvider = Install-PackageProvider -Name "NuGet" -Force
}
else {
    Write-Output -InputObject "NuGet package provider found."
}
#>
# Already installed module


# Install required modules
$Modules = "Evergreen", "IntuneWin32App", "MSGraphRequest", "Az.Storage", "Az.Resources"
$artifactStagingDirectory = Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "PSmodules"

foreach ($Module in $Modules) {
    try {
        Write-Output -InputObject "Attempting to save module '$Module' to ArtifactStagingDirectory: $artifactStagingDirectory"
        Save-Module -Name $Module -Repository PSGallery -Path $artifactStagingDirectory -Force -ErrorAction Stop
        Write-Output "Module $Module saved to ArtifactStagingDirectory: $artifactStagingDirectory"
    }
    catch {
        Write-Output "Exception: $($_.Exception.Message)"
    }
}