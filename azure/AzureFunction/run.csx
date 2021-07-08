#r "Microsoft.Azure.EventGrid"
#r "Microsoft.WindowsAzure.Storage"
#r "Newtonsoft.Json"

using System.Net;
using System.Linq;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using Microsoft.WindowsAzure.Storage;
using Microsoft.Azure.EventGrid.Models;
using Microsoft.WindowsAzure.Storage.Blob;

const string SUBSCRIPTION_KEY = "";
const string UDID = "";
const string STORAGE_ACCESS_KEY = "";
const string STORAGE_ACCOUNT_NAME = "";
const string STORAGE_CONTAINER_NAME = "";

public static string Base64Encode(string AStr)
{
    return Convert.ToBase64String(Encoding.UTF8.GetBytes(AStr));
}

public static string Base64Decode(string ABase64)
{
    return Encoding.UTF8.GetString(Convert.FromBase64String(ABase64));
}

public static async Task Run(EventGridEvent eventGridEvent, ILogger log){
    // Parse event data
    string eventData = eventGridEvent.Data.ToString();
    //log.LogInformation("eventData: {eventData}", eventData);

    JObject json = JObject.Parse(eventData);
    string body = (string)json["body"];
    //log.LogInformation("body: {body}", body);

    string d = Base64Decode(body);
    //log.LogInformation("body: {0}", d);

    JToken jToken = json.SelectToken("body");
    jToken.Replace(d);
    string eventData2 = json.ToString();
    //log.LogInformation("eventData2: {0}", eventData2);

    var client = new HttpClient();
    await GetGeoAsync(eventData2, client, SUBSCRIPTION_KEY, log);
}

public static async Task GetGeoAsync(string eventData, HttpClient client, string subscriptionKey, ILogger log){
    string name = Guid.NewGuid().ToString("n")+".json";
    await CreateBlobAsync(name, eventData);
}

// Creates and writes to a blob in data storage
public static async Task CreateBlobAsync(string name, string violationData){
    string connectionString = "DefaultEndpointsProtocol=https;AccountName=" + STORAGE_ACCOUNT_NAME + ";AccountKey=" + STORAGE_ACCESS_KEY + ";EndpointSuffix=core.windows.net";
    CloudStorageAccount storageAccount;
    storageAccount = CloudStorageAccount.Parse(connectionString);
    CloudBlobClient BlobClient;
    CloudBlobContainer container;
    BlobClient = storageAccount.CreateCloudBlobClient();
    container = BlobClient.GetContainerReference(STORAGE_CONTAINER_NAME);
    await container.CreateIfNotExistsAsync();
    CloudBlockBlob blob;
    blob = container.GetBlockBlobReference(name);
    await blob.UploadTextAsync(violationData);
    blob.Properties.ContentType = "application/json";
}
