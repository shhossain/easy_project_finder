# Check for administrator privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $scriptPath = $PSCommandPath
    Start-Process -FilePath "powershell.exe" -ArgumentList "-File `"$scriptPath`"" -Verb RunAs
    exit
}

try {
    # Define the GitHub release URL
    $latestReleaseUrl = "https://github.com/shhossain/easy_project_finder/releases/latest/download/easy_project_finder.exe"
    $exeName = "easy_project_finder.exe"
    $targetDir = "C:\Program Files\easy_project_finder"
    $exePath = Join-Path -Path $targetDir -ChildPath $exeName

    # Check if the URL exists
    try {
        $urlResponse = Invoke-WebRequest -Uri $latestReleaseUrl -Method Head -ErrorAction Stop
    } catch {
        throw "The URL $latestReleaseUrl does not exist or is unreachable."
    }
    # Create the target directory if it doesn't exist
    if (-not (Test-Path -Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir
    }


    # Download the executable
    Invoke-WebRequest -Uri $latestReleaseUrl -OutFile $exePath

    # PATH environment variable handling
    try {
        # Update System PATH
        $currentSystemPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
        if ($currentSystemPath -notlike "*$targetDir*") {
            $newSystemPath = $currentSystemPath + $(if ($currentSystemPath.EndsWith(';')) { '' } else { ';' }) + $targetDir
            [Environment]::SetEnvironmentVariable("Path", $newSystemPath, [EnvironmentVariableTarget]::Machine)
        }

        # Update User PATH
        $currentUserPath = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
        if ($currentUserPath -notlike "*$targetDir*") {
            $newUserPath = $currentUserPath + $(if ($currentUserPath.EndsWith(';')) { '' } else { ';' }) + $targetDir
            [Environment]::SetEnvironmentVariable("Path", $newUserPath, [EnvironmentVariableTarget]::User)
        }
        
        # Refresh current session's PATH
        $env:Path = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine) + ";" + 
                    [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User)
        
        Write-Host "PATH environment variables updated successfully"
    } catch {
        Write-Host "Error updating PATH: $_"
        throw
    }

    # Define the PowerShell function to be added to the profile
    $functionCode = @"
    function p {
        `\$out = easy_project_finder.exe `\$args
        `\$out
        if (`\$out) {
            if ((`\$out -is [string]) -and (Test-Path -Path `\$out)) {
                cd `\$out
            }
        }
    }
"@

    # Get the path to the user's PowerShell profile
    $profilePath = $PROFILE

    # Create the profile directory if it doesn't exist
    $profileDir = Split-Path -Parent $PROFILE
    if (-not (Test-Path -Path $profileDir)) {
        New-Item -ItemType Directory -Path $profileDir -Force
    }

    # Create the profile file if it doesn't exist
    if (-not (Test-Path -Path $profilePath)) {
        New-Item -ItemType File -Path $profilePath -Force
    }

    # Check if function already exists in profile
    $profileContent = Get-Content -Path $profilePath -Raw
    if (-not $profileContent) {
        $profileContent = ""
    }

    # Remove existing p function if found
    if ($profileContent -match '(?s)function p\s*{.*?}') {
        $profileContent = $profileContent -replace '(?s)function p\s*{.*?}', ''
        Set-Content -Path $profilePath -Value $profileContent.Trim()
    }

    # Add the new function
    Add-Content -Path $profilePath -Value $functionCode
    Write-Host "Function 'p' updated in PowerShell profile"

    Write-Host "Installation completed successfully."

} catch {
    Write-Host "An error occurred: $_"
    # Removed 'exit 1' to prevent automatic exit after error
}