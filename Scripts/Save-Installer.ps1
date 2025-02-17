<#
.SYNOPSIS
    This script processes the AppsPackageList.json file in the pipeline working folder to create the app package folder and download the installer executable.

.DESCRIPTION
    This script processes the AppsPackageList.json file in the pipeline working folder to create the app package folder and download the installer executable.

.EXAMPLE
    .\Save-Installer.ps1

.NOTES
    FileName:    Save-Installer.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2022-04-04
    Updated:     2023-06-14

    Version history:
    1.0.0 - (2022-04-04) Script created
    1.0.1 - (2023-06-14) Added support for download setup files from storage account
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param (
    [parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$StorageAccountAccessKey
)
Process {
    # Functions
    function Save-InstallerFile {
        param (
            [parameter(Mandatory = $true, HelpMessage = "Specify the download URL.")]
            [ValidateNotNullOrEmpty()]
            [string]$URI,
    
            [parameter(Mandatory = $true, HelpMessage = "Specify the download path.")]
            [ValidateNotNullOrEmpty()]
            [string]$Path,
    
            [parameter(Mandatory = $true, HelpMessage = "Specify the output file name of downloaded file.")]
            [ValidateNotNullOrEmpty()]
            [string]$Name
        )
        Begin {
            # Force usage of TLS 1.2 connection
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
            # Disable the Invoke-WebRequest progress bar for faster downloads
            $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
    
            # Create the WebRequestSession object
            $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    
            # Set the custom user agent
            $session.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36"
    
            # Download installer file with retry
            $retryCount = 0
            $retryLimit = 5
            $downloadSuccess = $false
            
        }
        Process {
            # Create path if it doesn't exist
            if (-not (Test-Path -Path $Path -PathType "Container")) {
                Write-Output -InputObject "Attempting to create provided path: $($Path)"
    
                try {
                    $NewPath = New-Item -Path $Path -ItemType "Container" -ErrorAction "Stop"
                }
                catch [System.Exception] {
                    throw "$($MyInvocation.MyCommand): Failed to create '$($Path)' with error message: $($_.Exception.Message)"
                }
            }
            # Download installer file with retry
    
            while ($retryCount -lt $retryLimit -and -not $downloadSuccess) {
                try {
                    $OutFilePath = Join-Path -Path $Path -ChildPath $Name
            
                    if ($session -and $session.UserAgent) {
                        # Make the request using Invoke-WebRequest with the WebRequestSession and custom headers
                        Invoke-WebRequest -Uri $URI -OutFile $OutFilePath -UseBasicParsing -WebSession $session -ErrorAction "Stop"
                    }
                    else {
                        # Make the request using Invoke-WebRequest without custom headers
                        Invoke-WebRequest -Uri $URI -OutFile $OutFilePath -UseBasicParsing -ErrorAction "Stop"
                    }
            
                    $downloadSuccess = $true
                }
                catch [System.Net.WebException] {
                    $retryCount++
            
                    if ($retryCount -lt $retryLimit) {
                        Write-Output -InputObject "Failed to download file from '$($URI)'. Retrying in 5 seconds (attempt $($retryCount) of $($retryLimit))..."
                        Start-Sleep -Seconds 5
                    }
                    else {
                        throw "$($MyInvocation.MyCommand): Failed to download file from '$($URI)' after $($retryLimit) attempts with error message: $($_.Exception.Message)"
                    }
                }
            }
        }
    }

    function Get-StorageAccountBlobContent {
        param (
            [parameter(Mandatory = $true, HelpMessage = "Specify the storage account name.")]
            [ValidateNotNullOrEmpty()]
            [string]$StorageAccountName,
    
            [parameter(Mandatory = $true, HelpMessage = "Specify the storage account container name.")]
            [ValidateNotNullOrEmpty()]
            [string]$ContainerName,

            [parameter(Mandatory = $true, HelpMessage = "Specify the name of the blob.")]
            [ValidateNotNullOrEmpty()]
            [string]$BlobName,

            [parameter(Mandatory = $true, HelpMessage = "Specify the download path.")]
            [ValidateNotNullOrEmpty()]
            [string]$Path,

            [parameter(Mandatory = $true, HelpMessage = "Specify the output file name of downloaded file.")]
            [ValidateNotNullOrEmpty()]
            [string]$NewName
        )
        process {
            # Create path if it doesn't exist
            if (-not(Test-Path -Path $Path -PathType "Container")) {
                Write-Output -InputObject "Attempting to create provided path: $($Path)"

                try {
                    $NewPath = New-Item -Path $Path -ItemType "Container" -ErrorAction "Stop"
                }
                catch [System.Exception] {
                    throw "$($MyInvocation.MyCommand): Failed to create '$($Path)' with error message: $($_.Exception.Message)"
                }
            }

            # Create storage account context using access key
            $StorageAccountContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountAccessKey
    
            try {
                # Retrieve the setup installer file from storage account
                Write-Output -InputObject "Downloading '$($BlobName)' in container '$($ContainerName)' from storage account: $($StorageAccountName)"
                $SetupFile = Get-AzStorageBlobContent -Context $StorageAccountContext -Container $ContainerName -Blob $BlobName -Destination $Path -Force -ErrorAction "Stop"

                # Rename downloaded file
                $SetupFilePath = Join-Path -Path $Path -ChildPath $BlobName
                if (Test-Path -Path $SetupFilePath) {
                    try {
                        Write-Output -InputObject "Renaming downloaded setup file to: $($NewName)"
                        Rename-Item -Path $SetupFilePath -NewName $NewName -Force -ErrorAction "Stop"
                    }
                    catch [System.Exception] {
                        throw "$($MyInvocation.MyCommand): Failed to rename downloaded setup file with error message: $($_.Exception.Message)"
                    }
                }
                else {
                    throw "$($MyInvocation.MyCommand): Could not find file after attempted download operation from storage account"
                }
            }
            catch [System.Exception] {
                throw "$($MyInvocation.MyCommand): Failed to download file from '$($URI)' with error message: $($_.Exception.Message)"
            }
        }
    }

    # Intitialize variables
    $AppsPrepareListFileName = "AppsPrepareList.json"
    $AppsPrepareListFilePath = Join-Path -Path $env:BUILD_BINARIESDIRECTORY -ChildPath $AppsPrepareListFileName
    $SourceDirectory = $env:BUILD_SOURCESDIRECTORY

    # Read content from AppsDownloadList.json file created in previous stage
    $AppsDownloadListFileName = "AppsDownloadList.json"
    $AppsDownloadListFilePath = Join-Path -Path (Join-Path -Path $env:BUILD_ARTIFACTSTAGINGDIRECTORY -ChildPath "AppsDownloadList") -ChildPath $AppsDownloadListFileName
    if (Test-Path -Path $AppsDownloadListFilePath) {
        # Construct list of applications to be processed in the next stage
        $AppsPrepareList = New-Object -TypeName "System.Collections.ArrayList"
        
        # Read content from AppsDownloadList.json file and convert from JSON format
        Write-Output -InputObject "Reading contents from: $($AppsDownloadListFilePath)"
        $AppsDownloadList = Get-Content -Path $AppsDownloadListFilePath | ConvertFrom-Json
        
        # Process each application in list and download installer
        foreach ($App in $AppsDownloadList) {
            Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Initializing"

            # Construct directory structure for current app item based on pipeline workspace directory path and app package folder name property
            $AppSetupFolderPath = Join-Path -Path $env:PIPELINE_WORKSPACE -ChildPath "Installers\$($App.AppFolderName)"

            try {
                # Save installer
                Write-Output -InputObject "Attempting to download '$($App.AppSetupFileName)' from: $($App.URI)"
                switch ($App.AppSource) {
                    "StorageAccount" {
                        Get-StorageAccountBlobContent -StorageAccountName $App.StorageAccountName -ContainerName $App.StorageAccountContainerName -BlobName $App.BlobName -Path $AppSetupFolderPath -NewName $App.AppSetupFileName -ErrorAction "Stop"
                    }
                    default {
                        Save-InstallerFile -URI $App.URI -Path $AppSetupFolderPath -Name $App.AppSetupFileName -ErrorAction "Stop"
                    }
                }
                Write-Output -InputObject "Successfully downloaded installer"

                # Save additional files
                if ($App.AdditionalFiles -ne $null -and $App.AdditionalFiles.Count -gt 0) {
                    $App.AdditionalFiles | ForEach-Object {
                        if (-not [string]::IsNullOrWhiteSpace($_)) {
                            Write-Output -InputObject "Attempting to download AdditionalFiles '$_' from: $($App.StorageAccountContainerName)"
                            Get-StorageAccountBlobContent -StorageAccountName $App.StorageAccountName -ContainerName $App.StorageAccountContainerName -BlobName $_ -Path $AppSetupFolderPath -NewName $_ -ErrorAction "Stop"
                        }
                    }
                }


                # Validate setup installer was successfully downloaded
                $AppSetupFilePath = Join-Path -Path $AppSetupFolderPath -ChildPath $App.AppSetupFileName
                if (Test-Path -Path $AppSetupFilePath) {

                    # Construct new application custom object with required properties
                    $AppListItem = [PSCustomObject]@{
                        "IntuneAppName"      = $App.IntuneAppName
                        "AppPublisher"       = $App.AppPublisher
                        "AppFolderName"      = $App.AppFolderName
                        "AppSetupFileName"   = $App.AppSetupFileName
                        "AppSetupFolderPath" = $AppSetupFolderPath
                        "AppSetupVersion"    = $App.AppSetupVersion
                    }

                    # Add to list of applications to be prepared for publishing
                    $AppsPrepareList.Add($AppListItem) | Out-Null
                }
                else {
                    Write-Warning -Message "Could not detect downloaded setup installer"
                    Write-Warning -Message "Application will not be added to app prepare list"
                }

                # Handle current application output completed message
                Write-Output -InputObject "[APPLICATION: $($App.IntuneAppName)] - Completed"
            }
            catch [System.Exception] {
                Write-Warning -Message "Failed to prepare download content for application: $($App.IntuneAppName)"
                Write-Warning -Message "Error message: $($_.Exception.Message)"
                Write-Warning -Message "Application will not be added to app prepare list"
            }
        }

        # Construct new json file with new applications to be published
        if ($AppsPrepareList.Count -ge 1) {
            $AppsPrepareListJSON = $AppsPrepareList | ConvertTo-Json -Depth 3
            Write-Output -InputObject "Creating '$($AppsPrepareListFileName)' in: $($AppsPrepareListFilePath)"
            Write-Output -InputObject "App list file contains the following items: $($AppsPrepareList.IntuneAppName -join ", ")"
            Out-File -InputObject $AppsPrepareListJSON -FilePath $AppsPrepareListFilePath -NoClobber -Force
        }

        # Handle next stage execution or not if no new applications are to be published
        if ($AppsPrepareList.Count -eq 0) {
            # Don't allow pipeline to continue
            Write-Output -InputObject "No new applications to be prepared, aborting pipeline"
            Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
        }
        else {
            # Allow pipeline to continue
            Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]true"
        }
    }
    else {
        Write-Output -InputObject "Failed to locate required $($AppsDownloadListFileName) file in build artifacts staging directory, aborting pipeline"
        Write-Output -InputObject "##vso[task.setvariable variable=shouldrun;isOutput=true]false"
    }
}