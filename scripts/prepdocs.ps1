param(
    [Switch]$cloudshell
)

Write-Host ""
Write-Host "Loading azd .env file from current environment"
Write-Host ""

$output = azd env get-values

foreach ($line in $output) {
  $name, $value = $line.Split("=")
  $value = $value -replace '^\"|\"$'
  [Environment]::SetEnvironmentVariable($name, $value)
}

Write-Host "Environment variables set."

Write-Host "Create and assign Cosmos DB data actions roles"
$roleId = az cosmosdb sql role definition create --account-name $env:AZURE_COSMOSDB_ACCOUNT --resource-group $env:AZURE_COSMOSDB_RESOURCE_GROUP --body ./scripts/cosmosreadwriterole.json --output tsv --query id
az cosmosdb sql role assignment create --account-name $env:AZURE_COSMOSDB_ACCOUNT --resource-group $env:AZURE_COSMOSDB_RESOURCE_GROUP --scope / --principal-id $env:BACKEND_IDENTITY_PRINCIPAL_ID --role-definition-id $roleId
az cosmosdb sql role assignment create --account-name $env:AZURE_COSMOSDB_ACCOUNT --resource-group $env:AZURE_COSMOSDB_RESOURCE_GROUP --scope / --principal-id $env:AZURE_PRINCIPAL_ID --role-definition-id $roleId

$pythonCmd = Get-Command python -ErrorAction SilentlyContinue
if (-not $pythonCmd) {
  # fallback to python3 if python not found
  $pythonCmd = Get-Command python3 -ErrorAction SilentlyContinue
}

Write-Host 'Creating python virtual environment "scripts/.venv"'
Start-Process -FilePath ($pythonCmd).Source -ArgumentList "-m venv ./scripts/.venv" -Wait -NoNewWindow

$venvPythonPath = "./scripts/.venv/scripts/python.exe"
if (Test-Path -Path "/usr") {
  # fallback to Linux venv path
  $venvPythonPath = "./scripts/.venv/bin/python"
}

Write-Host 'Installing dependencies from "requirements.txt" into virtual environment'
Start-Process -FilePath $venvPythonPath -ArgumentList "-m pip install -r ./scripts/requirements.txt" -Wait -NoNewWindow
