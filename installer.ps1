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
        $Response = Invoke-WebRequest -Uri $latestReleaseUrl -Method Head -ErrorAction Stop
        if ($Response.StatusCode -gt 399) {
            throw "The URL $latestReleaseUrl does not exist or is unreachable."
        }
    }
    catch {
        throw "The URL $latestReleaseUrl does not exist or is unreachable."
    }
    # Create the target directory if it doesn't exist
    if (-not (Test-Path -Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir
    }

    # Download the latest release
    try {
        Invoke-WebRequest -Uri $latestReleaseUrl -OutFile $exePath -ErrorAction Stop
    }
    catch {
        throw "Failed to download the latest release from $latestReleaseUrl. $_"
    }

    # # PATH environment variable handling
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
    }
    catch {
        Write-Host "Error updating PATH: $_"
        throw
    }

    # Define the PowerShell function to be added to the profile
    $functionCode = @"
function p {
    `$out = easy_project_finder.exe `$args
    if (`$out) {
        if ((`$out -is [string]) -and (Test-Path -Path `$out)) {
            Set-Location `$out
        } else {
            `$out 
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

    # Remove existing p function if found using improved regex
    if ($profileContent -match 'function\s+p\s*\{[\s\S]*?\}') {
        if (-not ($profileContent -match 'function\s+p\s*\{[\s\S]*?easy_project_finder.exe[\s\S]*?\}')) {
            Write-Host "Function 'p' is conflicting with an existing function in the PowerShell profile."
            # for ($i = 2; $i -lt 10; $i++) {
            #     $newFunctionName = "p$i"
            #     $newFunctionNamePat = "function\s+$newFunctionName\s*\{[\s\S]*?EASY PROJECT FINDER FUNCTION[\s\S]*?\}"
            #     if (-not $profileContent -match "function\s+$newFunctionName\s*\{[\s\S]*?\}") {
            #         $functionCode = $functionCode -replace 'function\s+p\s*\{', "function $newFunctionName {"
            #         Write-Host "Renaming 'p' function to '$newFunctionName' to avoid conflict"
            #         break
            #     } else {
            #         if ($profileContent -match $newFunctionNamePat) {

            #         }
            #     }
            # }
        }
        else {
            Write-Host "Function 'p' already exists in the PowerShell profile. Updating the existing 'p' function."
            $profileContent = $profileContent -replace 'function\s+p\s*\{[\s\S]*?\}', ''
    
            # Remove remaining } that might be left after removing the function
            $stack = New-Object System.Collections.Stack
            $indicesToRemove = @()
            for ($i = 0; $i -lt $profileContent.Length; $i++) {
                $char = $profileContent[$i]
                if ($char -eq '{') {
                    $stack.Push($i)
                }
                elseif ($char -eq '}') {
                    if ($stack.Count -eq 0) {
                        $indicesToRemove += $i
                    }
                    else {
                        $stack.Pop()
                    }
                }
            }
    
            # Remove unmatched } in reverse order to maintain correct indexing
            foreach ($index in $indicesToRemove | Sort-Object -Descending) {
                $profileContent = $profileContent.Remove($index, 1)
            }
    
            # Remove any leading or trailing whitespace
            $profileContent = $profileContent.Trim()

            $profileContent += "`n`n$functionCode"
    
            # Write the updated profile content
            Set-Content -Path $profilePath -Value $profileContent
        }
    }
    else {
        # Add the function to the profile
        Add-Content -Path $profilePath -Value $functionCode
        Write-Host "Function 'p' added to PowerShell profile"
    }

    # Reload the profile
    . $profilePath
    Write-Host "PowerShell profile reloaded"

    Write-Host "Installation completed successfully."

}
catch {
    Write-Host "An error occurred: $_"
    # Removed 'exit 1' to prevent automatic exit after error
}