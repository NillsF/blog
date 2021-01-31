RGNAME=425-aad-csi
AKSNAME=425-aad-csi
LOCATION=westus2
KVNAME=nf425csi #must be globally unique
STACC=425csiaadnf #needs to be unique

az group create -n $RGNAME -l $LOCATION
az aks create -g $RGNAME -n $AKSNAME \
  --enable-managed-identity --enable-pod-identity \
  --network-plugin azure --node-vm-size Standard_DS2_v2 \
  --node-count 2 --generate-ssh-keys

az identity create --name 425-blob-access \
  --resource-group $RGNAME

az storage account create \
  -n $STACC -g $RGNAME -l $LOCATION \
  --sku Standard_LRS

SCOPE=`az storage account show -n $STACC -g $RGNAME --query id -o tsv`
ASSIGNEE=`az identity show --name 425-blob-access \
  --resource-group $RGNAME --query clientId -o tsv`

az role assignment create --role "Storage Blob Data Contributor" \
--assignee $ASSIGNEE --scope $SCOPE

RESOURCEID=`az identity show --name 425-blob-access \
  --resource-group $RGNAME --query id -o tsv`
az aks pod-identity add --resource-group $RGNAME \
  --cluster-name $AKSNAME --namespace default \
  --name access-blob \
  --identity-resource-id $RESOURCEID

az keyvault create --location $LOCATION \
--name $KVNAME --resource-group $RGNAME

az keyvault secret set --name secret-425 \
  --vault-name $KVNAME --value "super secret for 425 show"

az keyvault set-policy -n $KVNAME \
--secret-permissions get list --spn $ASSIGNEE