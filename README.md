# TPMTrak Sync DB Function

This project is an Azure Function designed to consume messages from an Azure Service Bus queue and push the data into an Azure SQL Server database.

## Features

- **Service Bus Integration**: Listens to messages from an Azure Service Bus queue.
- **Data Processing**: Processes the incoming messages and extracts relevant data.
- **SQL Server Integration**: Inserts the processed data into an Azure SQL Server database.

## Prerequisites

- Azure Service Bus
- Azure SQL Server Database
- .NET 8 SDK

## Configuration

Update the following configuration values in the `local.settings.json` file:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "<Azure_Storage_Connection_String>",
    "FUNCTIONS_WORKER_RUNTIME": "dotnet",
    "ServiceBusConnectionString": "<Service_Bus_Connection_String>",
    "SqlConnectionString": "<SQL_Server_Connection_String>"
  }
}
```

## Usage

1. Clone the repository:
   ```bash
   git clone https://github.com/vitheshshetty00/TPMTrakSyncdbFunction.git
   cd TPMTrakSyncdbFunction
   ```

2. Build and run the function locally:
   ```bash
   func start
   ```
