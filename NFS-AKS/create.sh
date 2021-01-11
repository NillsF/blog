RGNAME=nfsaks
VNETNAME=nfsaks
STACC=nfnfsaks
DNSZONENAME="privatelink.file.core.windows.net"

az group create -n $RGNAME -l westus2
az network vnet create -g $RGNAME -n $VNETNAME \
  --address-prefixes 10.0.0.0/16 --subnet-name aks \
  --subnet-prefixes 10.0.0.0/24
az network vnet subnet create -g $RGNAME --vnet-name $VNETNAME \
  -n NFS --address-prefixes 10.0.1.0/24 
az storage account create \
  --name $STACC \
  --resource-group $RGNAME \
  --location westus2 \
  --sku Premium_LRS \
  --kind FileStorage
az storage account update --https-only false \
  --name $STACC --resource-group $RGNAME
az storage share-rm create \
  --storage-account $STACC \
  --enabled-protocol NFS \
  --root-squash RootSquash \
  --name "akstest" \
  --quota 100
  SUBNETID=`az network vnet subnet show \
  --resource-group $RGNAME \
  --vnet-name $VNETNAME \
  --name NFS \
  --query "id" -o tsv `
STACCID=`az storage account show \
  --resource-group $RGNAME \
  --name $STACC \
  --query "id" -o tsv `
az network vnet subnet update \
  --ids $SUBNETID\
  --disable-private-endpoint-network-policies 
ENDPOINT=`az network private-endpoint create \
  --resource-group $RGNAME \
  --name "$STACC-PrivateEndpoint" \
  --location westus2 \
  --subnet $SUBNETID \
  --private-connection-resource-id $STACCID\
  --group-id "file" \
  --connection-name "$STACC-Connection" \
  --query "id" -o tsv `
VNETID=`az network vnet show \
  --resource-group $RGNAME \
  --name $VNETNAME \
  --query "id" -o tsv`
dnsZone=`az network private-dns zone create \
  --resource-group $RGNAME \
  --name $DNSZONENAME \
  --query "id" -o tsv`
az network private-dns link vnet create \
  --resource-group $RGNAME \
  --zone-name $DNSZONENAME \
  --name "$VNETNAME-DnsLink" \
  --virtual-network $VNETID \
  --registration-enabled false 

ENDPOINTNIC=`az network private-endpoint show \
  --ids $ENDPOINT \
  --query "networkInterfaces[0].id" -o tsv `

ENDPOINTIP=`az network nic show \
  --ids $ENDPOINTNIC \
  --query "ipConfigurations[0].privateIpAddress" -o tsv `

az network private-dns record-set a create \
        --resource-group $RGNAME \
        --zone-name $DNSZONENAME \
        --name $STACC 

az network private-dns record-set a add-record \
        --resource-group $RGNAME \
        --zone-name $DNSZONENAME  \
        --record-set-name $STACC \
        --ipv4-address $ENDPOINTIP 
