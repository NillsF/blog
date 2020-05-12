APPID=$(az ad app create \
    --display-name "aks-secret-sp" \
    --identifier-uris "https://aks-secret-sp" \
    --query appId -o tsv)

SECRET=$(az ad sp credential reset \
    --name $APPID \
    --credential-description "aks-secret-pw" \
    --query password -o tsv)

az keyvault set-policy -n aks-secret-nf \
    --object-id $APPID --secret-permissions get list

