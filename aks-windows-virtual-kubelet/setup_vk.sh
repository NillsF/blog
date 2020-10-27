export RELEASE_NAME=virtual-kubelet-windows
export NODE_NAME=virtual-kubelet-windows

export CHART_URL=https://github.com/virtual-kubelet/azure-aci/raw/master/charts/virtual-kubelet-latest.tgz

helm install "$RELEASE_NAME" "$CHART_URL" \
  --set provider=azure \
  --set providers.azure.targetAKS=true \
  --set providers.azure.vnet.enabled=false \
  --set providers.azure.vnet.clusterCidr="$CLUSTER_SUBNET_RANGE" \
  --set providers.azure.masterUri="$MASTER_URI" \
  --set nodeName="$NODE_NAME" \
  --set nodeOsType="Windows"