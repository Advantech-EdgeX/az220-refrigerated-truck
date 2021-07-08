#!/bin/sh

#########################
# Version: 1.0.0
#########################

Enable=true
Address=edgex-mqtt-broker
Port=1883
Topic=MQTTExport
User=
Password=
DeviceNames=
#DeviceNames="MQTTAnalyticservice"
#DeviceNames="Random-Integer-Generator01"

#########################
# Check curl
#########################
echo -n "Check curl..."
curl --help > /dev/null
RES=$?
if [ ${RES} != 0 ]; then
    echo "Install curl"
    sudo apt-get -y install curl
else
    echo "OK"
fi

echo "--------------------------------------------------"
echo "Enable     : ${Enable}"
echo "Address    : ${Address}"
echo "Port       : ${Port}"
echo "Topic      : ${Topic}"
echo "User       : ${User}"
echo "Password   : ${Password}"
echo "DeviceNames: ${DeviceNames}"
echo "--------------------------------------------------"
#==================================================
#For EdgeX Fuji
#==================================================
CONSUL_SETTING_URL=http://172.17.0.1:8500/v1/kv/edgex/appservices/1.0/MQTTExport/ApplicationSettings
docker images | grep -q advantech1234/docker-app-functions-mqtt
RES=$?
if [ ${RES} = 0 ]; then
    echo "Create mqtt_export_register.sh & configuration.toml..."
########### configuration.toml ###########
echo "[Writable]
LogLevel = 'DEBUG'
[Writable.StoreAndForward]
Enabled = false
RetryInterval = '5m'
MaxRetryCount = 10

[Service]
BootTimeout = '30s'
ClientMonitor = '15s'
CheckInterval = '10s'
Host = 'mqtt-export-service'
Port = 48098
Protocol = 'http'
ReadMaxLimit = 100
StartupMsg = 'EdgeX MQTT Application Service Starting'
Timeout = '30s'

[Registry]
Host = 'edgex-core-consul'
Port = 8500
Type = 'consul'

[Logging]
EnableRemote = false
File = ''

# Database is require when Store and Forward is enabled
[Database]
Type = 'redisdb'
Host = 'localhost'
Port = 6379
Timeout = '30s'
Username = ''
Password = ''

# SecretStore is required when Store and Forward is enabled and running with security
# so Databse credentails can be pulled from Vault.
[SecretStore]
Host = 'localhost'
Port = 8200
Path = '/v1/secret/edgex/application-service/'
Protocol = 'https'

[SecretStore.Authentication]
  AuthType = 'X-Vault-Token'
  AuthToken = 'edgex'

[Clients]
  [Clients.CoreData]
    Protocol = 'http'
    Host = 'edgex-core-data'
    Port = 48080

  [Clients.Logging]
    Protocol = 'http'
    Host = 'edgex-support-logging'
    Port = 48061

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

# Choose either an HTTP trigger or MessageBus trigger (aka Binding)

#[Binding]
#Type="http"

[Binding]
Type='messagebus'
SubscribeTopic='events'
PublishTopic='somewhere'

[ApplicationSettings]
DeviceNames   = \"${DeviceNames}\"
Enable        = \"${Enable}\"
Address       = \"${Address}\"
Port          = \"${Port}\"
User          = \"${User}\"
Password      = \"${Password}\"
Topic         = \"${Topic}\"" > configuration.toml
########### configuration.toml end ###########

echo "#!/bin/sh
echo \"Copy configuration.toml to mqtt-export-service.\"
sudo docker cp configuration.toml mqtt-export-service:/res/
echo \"Register to EdgeX...\"
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"${Enable}\" $CONSUL_SETTING_URL/Enable?raw
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"${DeviceNames}\" $CONSUL_SETTING_URL/DeviceNames?raw
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"${Address}\" $CONSUL_SETTING_URL/Address?raw
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"${Port}\" $CONSUL_SETTING_URL/Port?raw
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"${User}\" $CONSUL_SETTING_URL/User?raw
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"${Password}\" $CONSUL_SETTING_URL/Password?raw
sudo curl -X PUT -H \"Content-Type: text/plain\" --data \"${Topic}\" $CONSUL_SETTING_URL/Topic?raw
echo \"Restart mqtt-export-service...\"
sudo docker restart mqtt-export-service" > mqtt_export_register.sh
chmod +x mqtt_export_register.sh
./mqtt_export_register.sh
else
    echo "mqtt-export-service not found."
fi
