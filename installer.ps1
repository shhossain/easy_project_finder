# Define the GitHub release URL
$latestReleaseUrl = "https://github.com/shhossain/easy_project_finder/releases/latest/download/easy_project_finder.exe"
$exeName = "easy_project_finder.exe"
$targetDir = "C:\Program Files\easy_project_finder"
$exePath = Join-Path -Path $targetDir -ChildPath $exeName

# Create the target directory if it doesn't exist
if (-not (Test-Path -Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir
}

# Download the executable
Invoke-WebRequest -Uri $latestReleaseUrl -OutFile $exePath

# Add the target directory to the system PATH
$env:Path += ";$targetDir"
[Environment]::SetEnvironmentVariable("Path", $env:Path, [EnvironmentVariableTarget]::Machine)

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

# Create the profile file if it doesn't exist
if (-not (Test-Path -Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force
}

# Append the function code to the profile if not already present
if (-not (Select-String -Path $profilePath -Pattern 'function p {')) {
    Add-Content -Path $profilePath -Value $functionCode
}

Write-Host "Installation completed successfully."