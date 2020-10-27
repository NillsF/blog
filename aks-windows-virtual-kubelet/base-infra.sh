# Set env-variables
export VNET_RANGE=10.0.0.0/8
export CLUSTER_SUBNET_RANGE=10.240.0.0/16
export ACI_SUBNET_RANGE=10.241.0.0/16
export VNET_NAME=AKS-win-ACI
export CLUSTER_SUBNET_NAME=AKS
export ACI_SUBNET_NAME=ACI
export AKS_CLUSTER_RG=AKS-win-ACI
export KUBE_DNS_IP=10.0.0.10
export AKS_CLUSTER_NAME=AKS-win-ACI
export LOCATION=westus2

# create RG
echo "### Creating RG ### "

az group create -o table \
--name $AKS_CLUSTER_RG \
--location $LOCATION

# create network
echo "### Creating network ### "

az network vnet create -o table \
    --resource-group $AKS_CLUSTER_RG \
    --name $VNET_NAME \
    --address-prefixes $VNET_RANGE \
    --subnet-name $CLUSTER_SUBNET_NAME \
    --subnet-prefix $CLUSTER_SUBNET_RANGE

export VNET_ID=`az network vnet show --resource-group $AKS_CLUSTER_RG --name $VNET_NAME --query id -o tsv`

az network vnet subnet create -o table \
    --resource-group $AKS_CLUSTER_RG \
    --vnet-name $VNET_NAME \
    --name $ACI_SUBNET_NAME \
    --address-prefix $ACI_SUBNET_RANGE
export VNET_SUBNET_ID=`az network vnet subnet show --resource-group $AKS_CLUSTER_RG --vnet-name $VNET_NAME --name $CLUSTER_SUBNET_NAME --query id -o tsv
`

# create sp
echo "### Creating service principal ### "

export SP=`az ad sp create-for-rbac -n "vk-aci-win" `
export AZURE_TENANT_ID=`echo $SP | jq .tenant | tr -d '"'`
export AZURE_CLIENT_ID=`echo $SP | jq .appId | tr -d '"'`
export AZURE_CLIENT_SECRET=`echo $SP | jq .password | tr -d '"'`
echo "Staring 30 seconds sleep to make sure SP propagates in all databases"
sleep 30
echo "Done sleeping."

# create AKS cluster
echo "### Creating AKS cluster ### "

az aks create -o table \
    --resource-group $AKS_CLUSTER_RG \
    --name $AKS_CLUSTER_NAME \
    --node-count 1 \
    --network-plugin azure \
    --service-cidr 10.0.0.0/16 \
    --dns-service-ip $KUBE_DNS_IP \
    --docker-bridge-address 172.17.0.1/16 \
    --vnet-subnet-id $VNET_SUBNET_ID \
    --client-secret $AZURE_CLIENT_SECRET \
    --service-principal $AZURE_CLIENT_ID

# get AKS credentials
echo "### Get AKS credentials and master URI ### "

az aks get-credentials \
    --resource-group $AKS_CLUSTER_RG \
    --name $AKS_CLUSTER_NAME

# Sed command is to remove the color special characters. source: https://stackoverflow.com/a/18000433
export MASTER_URI=`kubectl cluster-info | grep "Kubernetes master" | awk '{print $6}'  | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g"`