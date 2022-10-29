# azRras

## Desired State Configuration
Powershell since version 7.2 no longer comes bundled with PSDesiredStateConfiguration module, so one need to install it:
```Powershell
Install-Module -Name PSDesiredStateConfiguration -Repository PSGallery
```

## ARM template deployment
To deploy Azure Resource Manager template run:
```Powershell
New-AzResourceGroupDeployment -ResourceGroupName <resource-group-name> -TemplateFile <path-to-template>
```