import sys
from time import sleep
from azure.iot.hub import IoTHubRegistryManager
from azure.iot.hub.models import Twin, TwinProperties, QuerySpecification, QueryResult


with open('/var/secrets/server_iot_conn_string', 'r') as f:
    IOTHUB_CONNECTION_STRING = f.readline()

DEVICE_ID = "console_app"

def iothub_service_sample_run():
    try:
        iothub_registry_manager = IoTHubRegistryManager(IOTHUB_CONNECTION_STRING)

        twin = iothub_registry_manager.get_twin(DEVICE_ID)
        twin_patch = Twin(properties= TwinProperties(desired={'value' : 15}))
        twin = iothub_registry_manager.update_twin(DEVICE_ID, twin_patch, twin.etag)

        # Add a delay to account for any latency before executing the query
        sleep(1)

        print("Update sent")

    except Exception as ex:
        print("Unexpected error {0}".format(ex))
        return
    except KeyboardInterrupt:
        print("IoT Hub Device Twin service sample stopped")


if __name__ == '__main__':
    print("Starting the Python IoT Hub Device Twin service sample...")
    print()

    iothub_service_sample_run()