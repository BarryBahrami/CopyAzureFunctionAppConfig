#Requires -Module Az.Websites
#Requires -Module Az.Accounts
<#
.SYNOPSIS
  Copies configuration (Application Settings & Connection Strings) from a source
  Azure Function App to an existing target Azure Function App.
.DESCRIPTION
  This script retrieves Application Settings and Connection Strings from a specified
  source Function App and applies them to a specified target Function App.
  It assumes the target Function App already exists.
  IMPORTANT:
  - This script DOES NOT create any resources (Function App, Plan, etc.).
  - It DOES NOT deploy function code.
  - Review the settings to exclude/modify, especially `AzureWebJobsStorage`
    and Application Insights keys, as they often need specific values for the target
    environment (like storage accessible via Private Endpoint in ASE).
  - You MUST manually configure permissions for the target Function App's
    Managed Identity after running this script.
.PARAMETER SourceFunctionAppName
  The name of the existing source Function App to copy configuration FROM.
.PARAMETER SourceResourceGroupName
  The resource group name of the source Function App.
.PARAMETER TargetFunctionAppName
  The name of the existing target Function App (in the ASE) to copy configuration TO.
.PARAMETER TargetResourceGroupName
  The resource group name of the target Function App.
.EXAMPLE
  .\Copy-FunctionAppConfig.ps1 `
      -SourceFunctionAppName "func-certs-prod-so4d" `
      -SourceResourceGroupName "rg-certs-prod" `
      -TargetFunctionAppName "func-certs-prod-ase" `
      -TargetResourceGroupName "rg-certs-prod-ase"
.NOTES
  Author: Barry Bahrami / AI Assistant
  Date:   2023-10-27
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$SourceFunctionAppName,
    [Parameter(Mandatory=$true)]
    [string]$SourceResourceGroupName,
    [Parameter(Mandatory=$true)]
    [string]$TargetFunctionAppName,
    [Parameter(Mandatory=$true)]
    [string]$TargetResourceGroupName
)
# --- Script Start ---
# Connect to Azure (uncomment if running locally and not already connected)
# Connect-AzAccount
# Set-AzContext -SubscriptionId "YOUR_SUBSCRIPTION_ID" # Optional: Specify subscription
Write-Host "Starting Function App configuration copy..."
Write-Host "Source App: $SourceFunctionAppName in $SourceResourceGroupName"
Write-Host "Target App: $TargetFunctionAppName in $TargetResourceGroupName"
# --- Validate Inputs ---
Write-Host "Validating resources..."
# Get Source Function App (to ensure it exists)
$sourceApp = Get-AzFunctionApp -Name $SourceFunctionAppName -ResourceGroupName $SourceResourceGroupName -ErrorAction SilentlyContinue
if (-not $sourceApp) {
    Write-Error "Source Function App '$SourceFunctionAppName' not found in resource group '$SourceResourceGroupName'."
    exit 1
}
Write-Host " -> Source Function App found."
# Get Target Function App (to ensure it exists)
$targetApp = Get-AzFunctionApp -Name $TargetFunctionAppName -ResourceGroupName $TargetResourceGroupName -ErrorAction SilentlyContinue
if (-not $targetApp) {
    Write-Error "Target Function App '$TargetFunctionAppName' not found in resource group '$TargetResourceGroupName'. Please ensure it has been created first."
    exit 1
}
Write-Host " -> Target Function App found."
# --- Copy Configuration ---
Write-Host "Retrieving configuration from '$SourceFunctionAppName'..."
try {
    # Get application settings from source
    $sourceAppSettings = Get-AzFunctionAppSetting -Name $SourceFunctionAppName -ResourceGroupName $SourceResourceGroupName -ErrorAction Stop
    
    # Get connection strings from source (we have to use webapp command as function app doesn't have direct connection string cmdlet)
    $sourceWebApp = Get-AzWebApp -Name $SourceFunctionAppName -ResourceGroupName $SourceResourceGroupName -ErrorAction Stop
    $sourceConnStrings = $sourceWebApp.SiteConfig.ConnectionStrings
    
    # --- CRITICAL: Define Settings to Exclude or Modify ---
    # These settings are often environment-specific or managed by the platform
    # REVIEW AND ADJUST THIS LIST CAREFULLY!
    $settingsToExclude = @(
        "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING", # Platform managed
        "WEBSITE_CONTENTSHARE",                 # Platform managed
        "WEBSITE_SITE_NAME",                    # Platform managed (will be the target name anyway)
        "WEBSITE_HOSTNAME",                     # Platform managed (will be the target hostname)
        "WEBSITE_INSTANCE_ID",                  # Changes per instance
        # --- Potentially Exclude/Modify ---
        "AzureWebJobsStorage",                  # VERY LIKELY needs manual update for ASE (Private Endpoint/Managed Identity)
        "APPINSIGHTS_INSTRUMENTATIONKEY",       # Target app might use different App Insights
        "APPLICATIONINSIGHTS_CONNECTION_STRING" # Target app might use different App Insights
        # Add any other source-specific URLs, keys, or settings here
        # "MyApiUrl",
        # "LegacyDatabaseConnectionString"
    )
    $appSettingsToCopy = @{}
    Write-Host "Filtering Application Settings..."
    foreach ($key in $sourceAppSettings.Keys) {
        if ($settingsToExclude -notcontains $key) {
            $appSettingsToCopy[$key] = $sourceAppSettings[$key]
            Write-Verbose " -> Including App Setting: $key"
        } else {
            Write-Host " -> Excluding App Setting: $key (Present in exclusion list)"
        }
    }
    # Prepare Connection Strings for Set-AzWebApp format
    $connStringsToCopy = @{}
    Write-Host "Processing Connection Strings..."
    if ($sourceConnStrings) {
        foreach ($cs in $sourceConnStrings) {
             # Decide if you want to exclude specific connection strings by name
             # if ($cs.Name -ne "MyOldDatabase") {
                  $connStringsToCopy[$cs.Name] = @{ Type = $cs.Type.ToString(); Value = $cs.ConnectionString }
                  Write-Verbose " -> Including Connection String: $($cs.Name)"
             # } else {
             #    Write-Host " -> Excluding Connection String: $($cs.Name)"
             # }
        }
    } else {
        Write-Host " -> No connection strings found on source app."
    }
    Write-Host "Applying configuration to '$TargetFunctionAppName'..."
    # Apply app settings to the target function app
    Update-AzFunctionAppSetting -Name $TargetFunctionAppName -ResourceGroupName $TargetResourceGroupName `
        -AppSetting $appSettingsToCopy -Force -ErrorAction Stop
    
    # If we have connection strings, apply them to the target function app
    if ($connStringsToCopy.Count -gt 0) {
        $targetWebApp = Get-AzWebApp -Name $TargetFunctionAppName -ResourceGroupName $TargetResourceGroupName -ErrorAction Stop
        
        # Set connection strings
        Set-AzWebApp -Name $TargetFunctionAppName -ResourceGroupName $TargetResourceGroupName `
            -ConnectionStrings $connStringsToCopy -ErrorAction Stop
    }
    
    Write-Host " -> Configuration applied successfully."
} catch {
    Write-Error "Failed to copy/apply configuration. Error: $($_.Exception.Message)"
    Write-Warning "Please check the settings on the target Function App '$TargetFunctionAppName' manually."
    exit 1
}
# --- Final Instructions ---
Write-Host "--------------------------------------------------" -ForegroundColor Green
Write-Host "SUCCESS: Configuration copied to '$TargetFunctionAppName'." -ForegroundColor Green
Write-Host "--------------------------------------------------" -ForegroundColor Green
Write-Host ""
Write-Host "NEXT STEPS (CRITICAL):" -ForegroundColor Yellow
Write-Host " 1. VERIFY/UPDATE SETTINGS:" -ForegroundColor Yellow
Write-Host "    - Manually check the Application Settings in the Azure Portal for '$TargetFunctionAppName'."
Write-Host "    - **CRITICAL:** Ensure 'AzureWebJobsStorage' points to a Storage Account accessible from the ASE (e.g., via Private Endpoint) and consider using Managed Identity."
Write-Host "    - Update 'APPLICATIONINSIGHTS_CONNECTION_STRING' if the target app uses a different Application Insights instance."
Write-Host "    - Verify any other environment-specific settings (URLs, keys)."
Write-Host " 2. CONFIGURE MANAGED IDENTITY:" -ForegroundColor Yellow
Write-Host "    - The target app '$TargetFunctionAppName' has its OWN Managed Identity."
Write-Host "    - Grant this identity the required RBAC permissions on resources (Storage, Key Vault, Service Bus, etc.)."
Write-Host "    - Update connection strings/settings (like AzureWebJobsStorage) if they should use Managed Identity."
Write-Host " 3. DEPLOY YOUR CODE:" -ForegroundColor Yellow
Write-Host "    - This script DID NOT deploy code."
Write-Host "    - Deploy your function code to '$TargetFunctionAppName' using CI/CD (with VNet agents) or manually from within the VNet."
Write-Host "    - Remember the SCM endpoint is PRIVATE: $($TargetFunctionAppName).scm.$($targetApp.DefaultHostName.Split('.',2)[1])" # Tries to guess ASE domain part
Write-Host " 4. TEST THOROUGHLY:" -ForegroundColor Yellow
Write-Host "    - Test function triggers and execution from within the VNet."
Write-Host " 5. UPDATE CONSUMERS:" -ForegroundColor Yellow
Write-Host "    - Update any services or clients that trigger/call this function."
Write-Host "--------------------------------------------------"