# Define parameters from environment variables
$projectPath = $env:UIPATH_PROJECT_PATH
$outputFolder = $env:OUTPUT_FOLDER
$orchestratorUrl = $env:UIPATH_ORCHESTRATOR_URL
$orchestratorApiKey = $env:UIPATH_ORCHESTRATOR_API_KEY
$orchestratorTenant = $env:UIPATH_ORCHESTRATOR_TENANT
$orchestratorFolder = $env:UIPATH_ORCHESTRATOR_FOLDER
$orchestratorPackageName = $env:UIPATH_PACKAGE_NAME
$targetFramework = "net45"
 
# Pack the UiPath project
UiPath.Pack -ProjectPath $projectPath -OutputFolder $outputFolder -TargetFramework $targetFramework
 
# Find the newly created .nupkg file
$packageFile = Get-ChildItem -Path $outputFolder -Filter "*.nupkg" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
 
if ($packageFile -eq $null) {
    Write-Error "No .nupkg file found in the output folder."
    exit 1
}
 
# Display the package file path
Write-Output "Package file: $($packageFile.FullName)"
 
# Deploy the package to Orchestrator
$folderId = (Invoke-RestMethod -Uri "$orchestratorUrl/odata/Folders?filter=DisplayName eq '$orchestratorFolder'" -Headers @{Authorization = "Bearer $orchestratorApiKey"}).value[0].Id
 
Invoke-RestMethod -Uri "$orchestratorUrl/odata/Processes/UiPath.Server.Configuration.OData.UploadPackage" `
    -Method Post `
    -Headers @{
        "X-UIPATH-OrganizationUnitId" = $folderId
        "Authorization" = "Bearer $orchestratorApiKey"
        "X-UIPATH-TenantName" = $orchestratorTenant
    } `
    -ContentType "multipart/form-data" `
    -Form @{file = Get-Item -Path $packageFile.FullName}
 
Write-Output "Package deployed successfully."