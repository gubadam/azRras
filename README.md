# azRras

## Desired State Configuration
Powershell since version 7.2 no longer comes bundled with PSDesiredStateConfiguration module, so one need to install it:
```Powershell
Install-Module -Name PSDesiredStateConfiguration -Repository PSGallery
```

## ARM template deployment
To deploy Azure Resource Manager template run:
```Powershell
$deploymentParams = @{
  Name = "<deployment-name>"
  ResourceGroupName = "<resource-group-name>"
  TemplateFile = "./mainTemplate.json"
  TemplateParameterFile = "./mainTemplate.parameters.json"
  }
New-AzResourceGroupDeployment @deploymentParams
```

## Notes

### DSC extension on AzVM with ARM
https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/dsc-template

### Custom script extension on AzVM with ARM
https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.compute/vm-custom-script-windows/azuredeploy.json