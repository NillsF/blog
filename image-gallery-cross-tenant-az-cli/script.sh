RGNAME="sig-cross-tenant"
LOC="WESTUS2"
GALLERY="nfGallery"
VMNAME="sigsource"
IMAGENAME="sigtestimage"
TENANT1="72f988bf-86f1-41af-91ab-2d7cd011db47" #MSFT
TENANT2="42949aa4-09db-4624-9a32-83e2e02758c5" #VS
TARGETSUBID="ea122fb3-39a8-411c-995c-3724e344095f"
##### 
# All of this executed in primary tenant
#####
echo "Creating RG and VM"
# Create RG
az group create -n $RGNAME -l $LOC

# Create a VM to create an image from
az vm create -n $VMNAME -g $RGNAME --admin-username nilfranadmin \
    --ssh-key-values ~/.ssh/id_rsa.pub --image ubuntults

# Sleep 30 to make sure VM is available to run command
echo "Sleeping 30 seconds to wait for VM to be fully ready"
sleep 30

# Generalize VM
echo "Generalizing VM"

az vm run-command invoke -g $RGNAME -n $VMNAME --command-id RunShellScript --scripts "sudo waagent -deprovision+user -force"
az vm deallocate -g $RGNAME -n $VMNAME
az vm generalize -g $RGNAME -n $VMNAME

# Capture image
echo "Creating image"
az image create -g $RGNAME -n $IMAGENAME --source $VMNAME

# Get image id
imageid=$(az image show -g $RGNAME -n $IMAGENAME -o tsv --query id)

# Create image gallery 
echo "Creating sig"
az sig create --resource-group $RGNAME --gallery-name $GALLERY
sigid=$(az sig show \
   --resource-group $RGNAME \
   --gallery-name $GALLERY \
   --query id -o tsv)
echo "importing image into sig"
az sig image-definition create \
   --resource-group $RGNAME \
   --gallery-name $GALLERY \
   --gallery-image-definition $GALLERY \
   --publisher $GALLERY \
   --offer $GALLERY \
   --sku $GALLERY \
   --os-type Linux \
   --os-state generalized

echo "This next step will take a few minutes."
az sig image-version create \
   --resource-group $RGNAME \
   --gallery-name $GALLERY \
   --gallery-image-definition $GALLERY \
   --gallery-image-version 1.0.0 \
   --target-regions $LOC \
   --replica-count 1 \
   --managed-image $imageid

# Get image ID from sig
sigimageid=$(az sig image-version show --gallery-image-definition $GALLERY \
                          --gallery-image-version 1.0.1 \
                          --gallery-name $GALLERY \
                          --resource-group $RGNAME \
                          --query id -o tsv)


# Create app
appid=$(az ad app create --display-name $GALLERY \
                 --available-to-other-tenants true \
                 --reply-urls  "https://www.microsoft.com" \
                 --query appId -o tsv)

# Create SP
az ad sp create --id $appid
pw=$(az ad sp credential reset \
    --name $appid \
    --credential-description "gallery-PW" \
    --query password -o tsv)
echo "Password below:"
echo pw
# Create role assignment
az role assignment create --assignee $appid --role "Reader" --scope $sigid


####
# Now login to the other tenant
####
az login

# Now create an SP in this tenant, using the same app
az ad sp create --id $appid

# Give this SP permissions to create stuff
az role assignment create --assignee $appid --role "Contributor"
### 
# To create VM, login using the SP to both tenants now.
# this can be found documented here:  https://docs.microsoft.com/en-us/azure/virtual-machines/linux/share-images-across-tenants
###

az account clear
az login --service-principal -u $appid -p $pw --tenant $TENANT1
az account get-access-token 
az login --service-principal -u $appid -p $pw --tenant $TENANT2
az account get-access-token

# Create RG in target
az group create -n $RGNAME -l $LOC --subscription $TARGETSUBID
# Create VM in target tenant
az vm create \
  -g $RGNAME \
  -n $VMNAME \
  --image $sigimageid \
  --admin-username nilfranadmin \
  --ssh-key-values ~/.ssh/id_rsa.pub