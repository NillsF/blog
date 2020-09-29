import azure.mgmt.resourcegraph as arg
import json
import os
import logging
# Import specific methods and models from other libraries
from azure.common.credentials import get_azure_cli_credentials
from azure.common.credentials import ServicePrincipalCredentials
from azure.common.client_factory import get_client_from_cli_profile
from azure.mgmt.resource import SubscriptionClient
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.compute.models import DiskSku

# def get_credentials():
#     credentials = ServicePrincipalCredentials(
#         client_id=os.environ['AZURE_CLIENT_ID'],
#         secret=os.environ['AZURE_CLIENT_SECRET'],
#         tenant=os.environ['AZURE_TENANT_ID']
#     )
#     return credentials
subscriptionIds = ["d19dddf3-9520-4226-a313-ae8ee08675e5"]
vmToIgnore = [
    "test-ssh"
    ]


def getVmIdToIgnore(vmNames):
    # input: array of strings
    # return: dict of IDs of VM resource on Azure.

    # Transforming array to fit ARG query format.
    vmInString = '('
    for name in vmNames:
        vmInString += '"{}",'.format(name)
    vmInString = vmInString[0:-1] + ')'

    # Query: output is a list of IDs of VMs to ignore. 
    # Ignore is based on static list of VM names or where machine is not turned off.
    query = '''resources |         
                where type == "microsoft.compute/virtualmachines" |         
                where name in {} or  parse_json(properties.extended.instanceView.powerState.code) != "PowerState/deallocated" |        
                project id'''.format(vmInString)

    argClient = get_client_from_cli_profile(arg.ResourceGraphClient)
    argQueryOptions = arg.models.QueryRequestOptions(result_format="objectArray")

    # Create query
    argQuery = arg.models.QueryRequest(subscriptions=subscriptionIds, query=query, options=argQueryOptions)

    # Run query, serialize to dict
    logging.warning('Executing Resource explorer query for VM IDs')
    res = (argClient.resources(argQuery)).serialize()['data']

    return res

def getDisks(vmIdsToIgnore):
    vmsToIgnoreAsString = str(vmIdsToIgnore).replace('[','(').replace(']',')')

    query = '''resources |
             where type == "microsoft.compute/disks" |
             where sku.tier == "Premium" |
             where managedBy !in {} |
             project id'''.format(vmsToIgnoreAsString)

    argClient = get_client_from_cli_profile(arg.ResourceGraphClient)
    argQueryOptions = arg.models.QueryRequestOptions(result_format="objectArray")

    # Create query
    logging.warning('Executing Resource explorer query for disks')

    argQuery = arg.models.QueryRequest(subscriptions=subscriptionIds, query=query, options=argQueryOptions)
    # Run query, serialize to dict
    res = argClient.resources(argQuery).serialize()['data']
    logging.info('Got a total of {} disks.'.format(str(len(res))))
    return res

def resizeDisksToStandardSSD(diskIDs):
    #credentials = get_credentials()
    cred = get_azure_cli_credentials()
    newSKU = DiskSku(name="StandardSSD_LRS")
    for sub in subscriptionIds:
        compute_client = ComputeManagementClient(cred[0],sub)
        logging.warning("Changing level in subscription {}".format(sub))
        logging.warning("Resource group \t diskname")
        for disk in diskIDs:
            rgName = disk['id'].split('/')[4]
            diskName = disk['id'].split('/')[8]
            logging.warning("{}\t{}".format(rgName,diskName))
            disk = compute_client.disks.get(rgName,diskName)
            disk.sku = newSKU
            async_disk_update = compute_client.disks.begin_create_or_update(rgName,diskName,disk)
            async_disk_update.wait()
    return True

def main():
    ids = [vm['id'] for vm in getVmIdToIgnore(vmToIgnore)]
    disks = getDisks(ids)
    resizeDisksToStandardSSD(disks)

if __name__ == "__main__":
    main()