SP=`az ad sp create-for-rbac --skip-assignment`
APPID=`echo $SP | jq .appId`
APPID=`echo "${APPID//\"}"`
SECRET=`echo $SP | jq .password`
SECRET=`echo "${SECRET//\"}"`

az keyvault set-policy -n aks-secret-nf \
    --object-id $APPID --secret-permissions get list
    
az keyvault secret set --vault-name aks-secret-nf \
    --name secret1 --value superSecret1
az keyvault secret set --vault-name aks-secret-nf \
    --name secret2 --value verySuperSecret2
