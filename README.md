# azRras

## Desired State Configuration
Powershell since version 7.2 no longer comes bundled with PSDesiredStateConfiguration module, so one need to install it:
```Powershell
Install-Module -Name PSDesiredStateConfiguration -Repository PSGallery
```

## Bicep template deployment
To deploy Bicep template run:
```Powershell
$deploymentParams = @{
  Name = "<deployment-name>"
  ResourceGroupName = "<resource-group-name>"
  TemplateFile = "mainTemplate.bicep"
  TemplateParameterFile = "mainTemplate.parameters.json"
}
New-AzResourceGroupDeployment @deploymentParams
```

## Notes

### DSC extension on AzVM with ARM
https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/dsc-template

### Custom script extension on AzVM with ARM
https://github.com/Azure/azure-quickstart-templates/blob/master/quickstarts/microsoft.compute/vm-custom-script-windows/azuredeploy.json

Ms Reference: https://download.microsoft.com/download/4/3/1/43113F44-548B-4DEA-B471-0C2C8578FBF8/Quick_Reference_DSC_WS12R2.pdf