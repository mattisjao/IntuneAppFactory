# Define minimum required version
$DisplayName = "<Enter DisplayName value from registry>"
$Version = "###VERSION###"

# Process each key in 64-bit Uninstall registry path and detect if application is installed, or if a newer version exists that should be superseeded
$UninstallKeyPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
$UninstallKeys = Get-ChildItem -Path $UninstallKeyPath
foreach ($UninstallKey in $UninstallKeys) {
    $CurrentUninstallKey = Get-ItemProperty -Path $UninstallKey.PSPath -ErrorAction "SilentlyContinue"
    if ($CurrentUninstallKey.DisplayName -like $DisplayName) {
        # An installed version of the application was detected, ensure the version info is equal to or greater than with what's specified as the minimum required version
        # remove the comment to see the installed application for testing detection on next line.
        #Write-Output "Installed Application:$($CurrentUninstallKey.DisplayName) version:$($CurrentUninstallKey.DisplayVersion)"
        if ([System.Version]$CurrentUninstallKey.DisplayVersion -ge [System.Version]$Version) {
            return 0
        }
    }
}
# Process each key in 32-bit Uninstall registry path and detect if application is installed, or if a newer version exists that should be superseeded
$UninstallKeyPath32Bit = "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
$UninstallKeys32Bit = Get-ChildItem -Path $UninstallKeyPath32Bit
foreach ($UninstallKey32Bit in $UninstallKeys32Bit) {
    $CurrentUninstallKey32Bit = Get-ItemProperty -Path $UninstallKey32Bit.PSPath -ErrorAction "SilentlyContinue"
    if ($CurrentUninstallKey32Bit.DisplayName -like $DisplayName) {
        # An installed version of the application was detected, ensure the version info is equal to or greater than with what's specified as the minimum required version
        # remove the comment to see the installed application for testing detection on next line.
        #Write-Output "Installed Application:$($CurrentUninstallKey32Bit.DisplayName) version:$($CurrentUninstallKey32Bit.DisplayVersion)"
        if ([System.Version]$CurrentUninstallKey32Bit.DisplayVersion -ge [System.Version]$Version) {
            return 0
        }
    }
}
