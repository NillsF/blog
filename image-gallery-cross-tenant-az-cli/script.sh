RGNAME="sig-cross-tenant"
LOC="WESTUS2"
GALLERY="nfGallery"

##### 
# All of this executed in primary tenant
#####

# Create RG
az rg create -n $RGNAME -l $LOC

# Create image gallery 
az sig create --resource-group $RGNAME --gallery-name $GALLERY
sigid=$(az sig show \
   --resource-group $RGNAME \
   --gallery-name $GALLERY \
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

# Now login to the other tenant
az login

# Now create an SP in this tenant, using the same app
az ad sp create --id $appid
