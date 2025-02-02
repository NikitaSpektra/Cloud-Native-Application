Set-ExecutionPolicy -ExecutionPolicy bypass -Force
Start-Transcript -Path C:\WindowsAzure\Logs\extensionlog.txt -Append
Write-Host "Logon-task-started" 

$DeploymentID = $env:DeploymentID

Start-Process C:\Packages\extensions.bat
Write-Host "Bypass-Execution-Policy"



. C:\LabFiles\AzureCreds.ps1

$user = $AzureUserName

$password = $AzurePassword

$deploymentid = $env:DeploymentID


choco install bicep
Install-Module Sqlserver -SkipPublisherCheck -Force
Import-Module Sqlserver
choco install kubernetes-cli
choco install kubernetes-helm
az config set extension.use_dynamic_install=yes_without_prompt

#Download lab files
cd C:\

#create directory and clone bicep templates

mkdir C:\Workspaces
cd C:\Workspaces
mkdir lab
cd lab

git clone  https://github.com/CloudLabsAI-Azure/Cloud-Native-Application

Sleep 5
$path = "C:\Workspaces\lab\Cloud-Native-Application\labfiles\iac"
(Get-Content -Path "$path\createResources.parameters.json") | ForEach-Object {$_ -Replace "802322", "$DeploymentID"} | Set-Content -Path "$path\createResources.parameters.json"


(Get-Content -Path "$path\createResources.parameters.json") | ForEach-Object {$_ -Replace "bicepsqlpass", "$password"} | Set-Content -Path "$path\createResources.parameters.json"

Sleep 5

#Az login

. C:\LabFiles\AzureCreds.ps1

$userName = $AzureUserName
$password = $AzurePassword
$subscriptionId = $AzureSubscriptionID
$TenantID = $AzureTenantID


$securePassword = $password | ConvertTo-SecureString -AsPlainText -Force
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $userName, $SecurePassword

Login-AzAccount -Credential $cred | Out-Null


cd C:\Workspaces\lab\Cloud-Native-Application\labfiles\iac

$RGname = "contosotraders-$deploymentid"

New-AzResourceGroupDeployment -Name "createresources" -TemplateFile "createResources.bicep" -TemplateParameterFile "createResources.parameters.json" -ResourceGroup $RGname

$AKS_CLUSTER_NAME = "contoso-traders-aks$deploymentid"

$AKS_NODES_RESOURCE_GROUP_NAME = "contoso-traders-aks-nodes-rg$deploymentid"

$CDN_PROFILE_NAME = "contoso-traders-cdn$deploymentid"
$SUB_DEPLOYMENT_REGION = "eastus"
$KV_NAME = "contosotraderskv$deploymentid"
$PRODUCTS_DB_NAME = "productsdb"
$PRODUCTS_DB_SERVER_NAME = "contoso-traders-products"
$PRODUCTS_DB_USER_NAME = "localadmin"
$PRODUCT_DETAILS_CONTAINER_NAME = "product-details"
$PRODUCT_IMAGES_STORAGE_ACCOUNT_NAME = "contosotradersimg"
$PRODUCT_LIST_CONTAINER_NAME = "product-list"
$PRODUCTS_CDN_ENDPOINT_NAME = "contoso-traders-images$deploymentid"
$RESOURCE_GROUP_NAME = "contosotraders-$deploymentid"
$STORAGE_ACCOUNT_NAME = "contosotradersimg$deploymentid"
$server = "contoso-traders-products$deploymentid.database.windows.net"

$USER_ASSIGNED_MANAGED_IDENTITY_NAME = "contoso-traders-mi-kv-access$deploymentID"








az login -u $userName -p  $password
cd C:\Workspaces\lab\Cloud-Native-Application\labfiles

az aks get-credentials -g $RESOURCE_GROUP_NAME -n $AKS_CLUSTER_NAME

kubectl create namespace contoso-traders

az identity create -g $RESOURCE_GROUP_NAME --name $USER_ASSIGNED_MANAGED_IDENTITY_NAME

$objectID = "$(az identity show -g $RESOURCE_GROUP_NAME --name $USER_ASSIGNED_MANAGED_IDENTITY_NAME --query "clientId" -o tsv)"
      $obj2 = "$(az identity show -g $RESOURCE_GROUP_NAME --name $USER_ASSIGNED_MANAGED_IDENTITY_NAME --query "principalId" -o tsv)"
      az vmss identity assign --identities $(az identity show -g $RESOURCE_GROUP_NAME  --name $USER_ASSIGNED_MANAGED_IDENTITY_NAME  --query "id" -o tsv) --ids $(az vmss list -g $AKS_NODES_RESOURCE_GROUP_NAME  --query "[0].id" -o tsv) 
      az keyvault set-policy -n $KV_NAME  --secret-permissions get list --object-id $objectID 
            az keyvault set-policy -n $KV_NAME  --secret-permissions get list --object-id $obj2 

kubectl create secret generic contoso-traders-kv-endpoint --from-literal=contoso-traders-kv-endpoint="https://$KV_NAME.vault.azure.net/" -n contoso-traders





kubectl create secret generic contoso-traders-mi-clientid --from-literal=contoso-traders-mi-clientid=$objectID -n contoso-traders




  
Invoke-Sqlcmd -InputFile ./src/ContosoTraders.Api.Products/Migration/productsdb.sql -Database productsdb -Username "localadmin" -Password $password -ServerInstance $server -ErrorAction 'Stop' -Verbose -QueryTimeout 1800 # 30min



az aks update -n $AKS_CLUSTER_NAME -g $RESOURCE_GROUP_NAME --attach-acr /subscriptions/$subscriptionId/resourceGroups/$RESOURCE_GROUP_NAME/providers/Microsoft.ContainerRegistry/registries/contosotradersacr$deploymentid


az keyvault set-policy -n $KV_NAME --key-permissions get list  --object-id $(az ad user show --id $(az account show --query "user.name" -o tsv) --query "id" -o tsv)

az keyvault set-policy -n $KV_NAME  --secret-permissions get list --object-id $(az identity show --name "$AKS_CLUSTER_NAME-agentpool" -g $AKS_NODES_RESOURCE_GROUP_NAME --query "principalId" -o tsv)

az storage blob sync --account-name $STORAGE_ACCOUNT_NAME -c $PRODUCT_DETAILS_CONTAINER_NAME -s 'src/ContosoTraders.Api.Images/product-details'

az storage blob sync --account-name $STORAGE_ACCOUNT_NAME -c $PRODUCT_LIST_CONTAINER_NAME -s 'src/ContosoTraders.Api.Images/product-list'

#az cdn endpoint purge --no-wait --content-paths '/*' -n $PRODUCTS_CDN_ENDPOINT_NAME -g $RESOURCE_GROUP_NAME --profile-name $CDN_PROFILE_NAME




sleep 20

sleep 5
Unregister-ScheduledTask -TaskName "Installdocker" -Confirm:$false 
