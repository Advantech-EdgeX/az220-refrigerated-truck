#!/bin/sh

###########################
# Version: 1.0.3
###########################

Enable=true
YourResourceGroup=
YourIoTHubName=
YourConsumerGroup=
YourDeviceID=
YourLocation=
DeviceNames=
# YourResourceGroup="EdgeX"
# YourIoTHubName="Advantech-EdgeX"
# YourConsumerGroup="edgex"
# YourDeviceID="EdgeXDevice"
# YourLocation="eastus"
# DeviceNames=\"MQTTAnalyticservice\"
# DeviceNames=\"Random-Integer-Generator01\"
# DeviceNames=\"usb\",\"monitor\"

###########################
# Install AzureCli
# curl -L https://aka.ms/InstallAzureCli | bash
###########################
echo -n "Check curl..."
curl --help > /dev/null
RES=$?
if [ ${RES} != 0 ]; then
    echo "Install curl"
    sudo apt-get -y install curl
else
    echo "OK"
fi

echo -n "Check azureCli..."
az > /dev/null
RES=$?
if [ ${RES} != 0 ]; then
    echo "Install azureCli"
    sudo apt-get -y install python3-distutils
    curl -s -L https://aka.ms/InstallAzureCli | bash
    export PATH=/home/$USER/bin/:$PATH
else
    echo "OK"
fi

###########################
# Login
###########################
echo "--------------------------------------------------"
echo "Login Azure.."
echo "--------------------------------------------------"
az account show
RES=$?
if [ ${RES} != 0 ]; then
    az login --use-device-code
else
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "You are Already Logged in."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
fi

# To sign in, use a web browser to open the page https://microsoft.com/devicelogin
# and enter the code xxxxxxxxx to authenticate.

###########################
# Create a resource group
###########################
echo "--------------------------------------------------"
echo "Create Resource Group.. ${YourResourceGroup}"
echo "--------------------------------------------------"
az resource list --resource-group ${YourResourceGroup} 2> /dev/null
RES=$?
if [ ${RES} != 0 ]; then
    az group create --name ${YourResourceGroup} --location ${YourLocation}
else
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Resource Group(${YourResourceGroup}) already exists."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
fi

###########################
# Create an IoT hub
###########################
echo "--------------------------------------------------"
echo "Create IoT Hub.. ${YourIoTHubName}"
echo "--------------------------------------------------"
az iot hub show --name ${YourIoTHubName} 2> /dev/null
RES=$?
if [ ${RES} != 0 ]; then
    az iot hub create --name ${YourIoTHubName} --resource-group ${YourResourceGroup} --location ${YourLocation}
else
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "IoT Hub(${YourIoTHubName}) already exists."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
fi

###########################
# Get the connection string for the IoT hub
###########################
hubConnectionString=$(az iot hub connection-string show -n ${YourIoTHubName} --output table | tail -n1)
if [ -z ${hubConnectionString} ]; then
    hubConnectionString=$(az iot hub show-connection-string --name ${YourIoTHubName} --key primary --query connectionString -o tsv)
fi

###########################
# Add a consumer group to the IoT hub for the 'events' endpoint
###########################
echo "--------------------------------------------------"
echo "Create Consumer Group.. ${YourConsumerGroup}"
echo "--------------------------------------------------"
az iot hub consumer-group show --hub-name ${YourIoTHubName} --name ${YourConsumerGroup} 2> /dev/null
RES=$?
if [ ${RES} != 0 ]; then
    az iot hub consumer-group create --hub-name ${YourIoTHubName} --name ${YourConsumerGroup}
else
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Consumer Group(${YourConsumerGroup}) already exists."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
fi

###########################
# Generate an X509 self-signed certificate
###########################
echo "--------------------------------------------------"
echo "Create Keys .."
echo "--------------------------------------------------"
az iot hub certificate show --name azure_cert --hub-name ${YourIoTHubName} 2> /dev/null
RES=$?
if [ ${RES} != 0 ]; then
    openssl req -x509 -sha1 -nodes -newkey rsa:2048 -keyout azure_private.pem -days 365 -out azure_cert.pem

    az iot hub certificate create --hub-name ${YourIoTHubName} --name azure_cert --path azure_cert.pem
else
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Key(azure_cert) already exists."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
fi

thumbprint=$(az iot hub certificate show --name azure_cert --hub-name ${YourIoTHubName} --query 'properties.thumbprint' -o tsv)

###########################
# Create an IoT device with self-signed certificate authorization
###########################
echo "--------------------------------------------------"
echo "Create IoT device .."
echo "--------------------------------------------------"
az iot hub device-identity show --hub-name ${YourIoTHubName} --device-id ${YourDeviceID} 2> /dev/null
RES=$?
if [ ${RES} != 0 ]; then
    az iot hub device-identity create --hub-name ${YourIoTHubName} --device-id ${YourDeviceID} --primary-thumbprint ${thumbprint} --am x509_thumbprint
else
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "IoT device(${YourDeviceID}) already exists."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
fi

echo "--------------------------------------------------"
echo "Enable          : ${Enable}"
echo "ResourceGroup   : ${YourResourceGroup}"
echo "Location        : ${YourLocation}"
echo "IoTHubName      : ${YourIoTHubName}"
echo "DeviceID        : ${YourDeviceID}"
echo "Thumbprint      : ${thumbprint}"
echo "ConsumerGroup   : ${YourConsumerGroup}"
echo "ConnectionString: ${hubConnectionString}"
echo "DeviceNames     : ${DeviceNames}"
echo "--------------------------------------------------"
###########################
# EdgeX export data
###########################
echo "=================================================="
echo " For EdgeX Fuji "
echo "=================================================="
CONSUL_SETTING_URL=http://172.17.0.1:8500/v1/kv/edgex/appservices/1.0/AzureExport/ApplicationSettings
docker images | grep -q advantech1234/docker-app-functions-azure
RES=$?
if [ ${RES} = 0 ]; then
    echo "Create azure_export_register.sh & configuration.toml..."
########### configuration.toml ###########
echo "[Writable]
LogLevel = 'INFO'

[Service]
BootTimeout = '30s'
ClientMonitor = '15s'
CheckInterval = '10s'
Host = 'azure-export-service'
Port = 48095
Protocol = 'http'
ReadMaxLimit = 100
StartupMsg = 'Azure IoT Export Service'
Timeout = '50s'

[Registry]
Host = 'edgex-core-consul'
Port = 8500
Type = 'consul'

[Clients]
  [Clients.CoreData]
  Protocol = 'http'
  Host = 'edgex-core-data'
  Port = 48080

[Logging]
EnableRemote = false
File = './logs/azure-export.log'

[Binding]
Type=\"messagebus\"
SubscribeTopic=\"events\"
PublishTopic=\"\"

[MessageBus]
Type = 'zero'
    [MessageBus.PublishHost]
        Host = '*'
        Port = 5564
        Protocol = 'tcp'
    [MessageBus.SubscribeHost]
        Host = 'edgex-core-data'
        Port = 5563
        Protocol = 'tcp'

[ApplicationSettings]
IoTHub         = \"${YourIoTHubName}\"
IoTDevice      = \"${YourDeviceID}\"
Password       = \"\"
MQTTCert       = \"export-keys/azure_cert.pem\"
MQTTKey        = \"export-keys/azure_private.pem\"
TokenPath      = \"/vault/config/assets/resp-init.json\"
VaultHost      = \"edgex-vault\"
VaultPort      = \"8200\"
CertPath       = \"v1/secret/edgex/pki/tls/azure\"
DeviceNames    = \"${DeviceNames}\"
Qos            = \"0\"
AutoReconnect  = \"false\"
Retain         = \"false\"
SkipCertVerify = \"false\"
PersistOnError = \"false\"
Enable         = \"${Enable}\"" > configuration.toml
########### configuration.toml end ###########

echo "#!/bin/sh
echo \"Copy keys & configuration.toml to azure-export-service.\"
sudo docker cp configuration.toml azure-export-service:/res/
sudo docker cp azure_cert.pem azure-export-service:/export-keys/
sudo docker cp azure_private.pem azure-export-service:/export-keys/
echo \"Register azure certificate to EdgeX...\"
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"${Enable}\" $CONSUL_SETTING_URL/Enable?raw
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"${DeviceNames}\" $CONSUL_SETTING_URL/DeviceNames?raw
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"${YourIoTHubName}\" $CONSUL_SETTING_URL/IoTHub?raw
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"${YourDeviceID}\" $CONSUL_SETTING_URL/IoTDevice?raw
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"export-keys/azure_cert.pem\" $CONSUL_SETTING_URL/MQTTCert?raw
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"export-keys/azure_private.pem\" $CONSUL_SETTING_URL/MQTTKey?raw
echo \"Restart azure-export-service...\"
sudo docker restart azure-export-service" > export_to_azure_fuji.sh
chmod +x export_to_azure_fuji.sh
./export_to_azure_fuji.sh
else
    echo "azure-export-service not found."
fi
