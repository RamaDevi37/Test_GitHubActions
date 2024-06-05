# Parameters
param (
    [string]$projectPath,
    [string]$outputPath,
    [string]$orchestratorUrl,
    [string]$tenantName,
    [string]$usernameOrEmailAddress,
    [string]$password,
    [string]$modernFolderName
)
 
# Validate parameters
if (-not (Test-Path $projectPath)) {
    Write-Error "Project path does not exist: $projectPath"
    exit 1
}
 
# Pack the UiPath project
$nugetFileName = "package.nupkg"
$nugetPackagePath = Join-Path -Path $outputPath -ChildPath $nugetFileName
 
Write-Host "Packing the UiPath project..."
& "C:\Program Files (x86)\UiPath\Studio\UiRobot.exe" pack "$projectPath/project.json" -o $outputPath
 
# Authenticate with Orchestrator
$authUrl = "$orchestratorUrl/api/account/authenticate"
$authBody = @{
    tenancyName = $tenantName
    usernameOrEmailAddress = $usernameOrEmailAddress
    password = $password
} | ConvertTo-Json
 
$authResponse = Invoke-RestMethod -Uri $authUrl -Method Post -Body $authBody -ContentType "application/json"
$authToken = $authResponse.result
 
# Get the process name from the project.json file
$projectJson = Get-Content "$projectPath/project.json" | ConvertFrom-Json
$processName = $projectJson.name
 
# Get existing versions from Orchestrator
$packageUrl = "$orchestratorUrl/odata/Processes?\$filter=Name eq '$processName'"
$headers = @{
    Authorization = "Bearer $authToken"
}
$existingPackages = Invoke-RestMethod -Uri $packageUrl -Method Get -Headers $headers
 
# Determine the next version
if ($existingPackages.value.Count -gt 0) {
    $versions = $existingPackages.value | ForEach-Object { [version]$_.Version }
    $latestVersion = $versions | Sort-Object -Descending | Select-Object -First 1
    $nextVersion = [version]($latestVersion.Major + 1).ToString()
} else {
    $nextVersion = "1.0.0"
}
 
# Update project.json with the new version
$projectJson.projectVersion = $nextVersion
$projectJson | ConvertTo-Json -Depth 10 | Set-Content "$projectPath/project.json"
 
# Pack the UiPath project with the new version
Write-Host "Packing the UiPath project with version $nextVersion..."
& "C:\Program Files (x86)\UiPath\Studio\UiRobot.exe" pack "$projectPath/project.json" -o $outputPath
 
# Upload the package to Orchestrator
$uploadUrl = "$orchestratorUrl/odata/Processes/UiPath.Server.Configuration.OData.UploadPackage"
$packageBytes = [System.IO.File]::ReadAllBytes($nugetPackagePath)
$fileContent = [System.Convert]::ToBase64String($packageBytes)
 
$uploadBody = @{
    folderName = $modernFolderName
    fileName = "$processName.$nextVersion.nupkg"
    fileContent = $fileContent
} | ConvertTo-Json
 
Invoke-RestMethod -Uri $uploadUrl -Method Post -Headers $headers -Body $uploadBody -ContentType "application/json"
 
Write-Host "Package published successfully to Orchestrator with version $nextVersion!"