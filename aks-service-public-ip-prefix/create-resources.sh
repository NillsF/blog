# First we'll create the AKS cluster, then we'll create the public IP prefix and a public ip
# Then, we'll need to give the identity of the AKS cluster permissions over the resource group of the public IP

# Creating very basic AKS cluster

az group create -n aks-prefix -l westus2
az aks create -g aks-prefix -n aks-prefix -l westus2 --enable-managed-identity --node-count 1 --generate-ssh-keys
az aks get-credentials -g aks-prefix -n aks-prefix
# giving permissions on the RG
RGID=$(az group show -n aks-prefix -o tsv --query id )
APPID=$(az aks show -n aks-prefix -g aks-prefix --query "identity.principalId" -o tsv)
az role assignment create \
    --assignee $APPID \
    --role "Network Contributor" \
    --scope $RGID

# creating public ip prefix
az network public-ip prefix create \
    --length 30 \
    --name pip-prefix \
    --resource-group aks-prefix \
    --location westus2 \
    --version IPv4

# creating IP from prefix
az network public-ip create \
    --name pip-for-aks \
    --resource-group aks-prefix \
    --allocation-method Static \
    --public-ip-prefix pip-prefix \
    --sku Standard \
    --version IPv4
# getting public ip output
az network public-ip show \
    -n pip-for-aks \
    -g aks-prefix \
    --query "ipAddress" \
    -o tsv