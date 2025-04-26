# Copy Function App Config

This PowerShell script copies configuration settings (Application Settings and Connection Strings) from one Azure Function App in one subscription to another Azure Function App in a different subscription. It's designed for scenarios where you need to replicate settings across environments or subscriptions without deploying code.

## Usage

To use this script:

1. **Ensure Prerequisites:**
   - Install [PowerShell 5.1](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.2) or later.
   - Have access to both the source and target Azure subscriptions with appropriate permissions.

2. **Download or Clone the Repository:**
   ```sh
   git clone https://github.com/your-github-username/your-repo-name.git
   cd your-repo-name
   ```

3. **Open PowerShell with Administrative Privileges:**
   - Right-click on PowerShell and select "Run as administrator".

4. **Run the Script:**
   ```powershell
   .\Copy-FunctionAppConfig.ps1 `
       -SourceFunctionAppName "func-source-app" `
       -SourceResourceGroupName "source-rg" `
       -SourceSubscriptionId "source-subscription-id" `
       -TargetFunctionAppName "func-target-app" `
       -TargetResourceGroupName "target-rg" `
       -TargetSubscriptionId "target-subscription-id"
   ```

   Replace the parameters with your actual Function App names, Resource Group names, and Subscription IDs.

## Parameters

- **SourceFunctionAppName**: The name of the source Azure Function App from which to copy settings.
- **SourceResourceGroupName**: The resource group name where the source Function App resides.
- **SourceSubscriptionId**: The Azure Subscription ID of the source Function App.
- **TargetFunctionAppName**: The name of the target Azure Function App where settings will be applied.
- **TargetResourceGroupName**: The resource group name where the target Function App resides.
- **TargetSubscriptionId**: The Azure Subscription ID of the target Function App.

## Important Notes

- This script does not create any Azure resources or deploy code. You must manually create the target Function App beforehand.
- Review and update settings carefully: Some settings like AzureWebJobsStorage or Application Insights keys might need environment-specific values.
- Managed Identity: The script does not configure Managed Identity permissions. You need to set these manually after running the script.
- Testing: Ensure to test thoroughly in the target environment.

## License

This project is licensed under the GNU General Public License v3.0. By using this software, you agree to the terms and conditions of the license.

## Contribution

Contributions are welcome! Please fork the repository and submit pull requests for any changes or enhancements.

## Contact

If you have any questions or suggestions, feel free to open an issue or contact me.
