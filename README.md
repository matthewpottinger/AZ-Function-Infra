Deploy from start using VSCode
- Open the TF folder in VSCode (TF Vision Function via PE)
- Open the main.tf file - The items with 59 is just to provide a unique ID - you can change the names to suit a naming convention etc just make sure all of the numbers have been changed.
- Open the variables file and set the eariables for your env

Sign in to your Azure Sub 
- open a new terminal
- az login
- in the variables.tf set the tennent ID and Sub ID
- Make sure you have saved the files after you have made changes

Open a terminal in VSCode
Run the following commands
terrafrom init
terraform validate
terraform apply (sometimes you need to repeat the apply)

Check that the FAs VNet integration is applied and the env settings have the KV references - if not re-apply the TF

It sometimes fails to create the output table in the storage account - so you may need to add that manually as imagetext

Add my client to the storage accounts allowed network list
Set the inbound network settings for the Storage Account an Function to allow all public for the function deployment



Open an new VSCode window to deploy the function to the function app
open the function folder (VisionCS)
- open a terminal and login to your azure tenant - az login
- Make the storage account and function app are accessible from any public network for the deployment of the function
- in vscode - command pallet - deploy function - select your sub and function app
(if the deployment fails check that the functions vnet integration is in place - you may need to re-apply the TF)
- switch the storage account back to public network access from selected virtual networks and IPs (the Vnet for this deployment and your IP)


Test 
- upload an image containing text to the image container in the storage account
- 


Output table has not created 