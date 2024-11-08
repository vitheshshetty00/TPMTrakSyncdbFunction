using System;
using System.Threading.Tasks;
using Microsoft.Data.SqlClient;
using Azure.Messaging.ServiceBus;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace Company.Function
{
    public class ServiceBusQueueTrigger
    {
        private readonly ILogger<ServiceBusQueueTrigger> _logger;

        public ServiceBusQueueTrigger(ILogger<ServiceBusQueueTrigger> logger)
        {
            _logger = logger;
        }

        [Function(nameof(ServiceBusQueueTrigger))]
        public async Task Run(
            [ServiceBusTrigger("tpmtrak-queue", Connection = "sbnmtmptrak_SERVICEBUS")]
Azure.Messaging.ServiceBus.ServiceBusReceivedMessage message,
            ServiceBusMessageActions messageActions)
        {
            _logger.LogInformation("Message ID: {id}", message.MessageId);
            _logger.LogInformation("Message Body: {body}", message.Body);
            _logger.LogInformation("Message Content-Type: {contentType}", message.ContentType);
            InsertToDb(message);

            await messageActions.CompleteMessageAsync(message);
        }
        private void InsertToDb(ServiceBusReceivedMessage message)
        {
            string sqlConnectionString = Environment.GetEnvironmentVariable("AzureSQLConnectionString");
            if (string.IsNullOrEmpty(sqlConnectionString))
            {
                _logger.LogError("AzureSQLConnectionString is not set");
                return;
            }

            string messageBody = message.Body.ToString();
            messageBody = messageBody.Replace("START-", "").Replace("-END", "");
            
            string[] messageParts = messageBody.Split('-');
            if (messageParts.Length != 10)
            {
                _logger.LogError("Message format is incorrect");
                return;
            }

            try 
            {
                int id = int.Parse(messageParts[0]);
                string status = messageParts[1];
                string field1Str = messageParts[2].Trim('[', ']');
                int field1 = int.Parse(field1Str);
                int field2 = int.Parse(messageParts[3]);
                string description = messageParts[4];
                int instanceId = int.Parse(messageParts[5]);
                string startDateTimeStr = messageParts[6] + "-" + messageParts[7];
                string endDateTimeStr = messageParts[8] + "-" + messageParts[9];
                DateTime startDateTime = DateTime.ParseExact(startDateTimeStr, "yyyyMMdd-HHmmss", null);
                DateTime endDateTime = DateTime.ParseExact(endDateTimeStr, "yyyyMMdd-HHmmss", null);

                using (var connection = new SqlConnection(sqlConnectionString))
                {
                    connection.Open();
                    
                    string query = @"INSERT INTO TPMTrakTable 
                                (Id, Status, Field1, Field2, Description, InstanceId, StartDateTime, EndDateTime) 
                                VALUES 
                                (@Id, @Status, @Field1, @Field2, @Description, @InstanceId, @StartDateTime, @EndDateTime)";

                    using (var command = new SqlCommand(query, connection))
                    {
                        command.Parameters.AddWithValue("@Id", id);
                        command.Parameters.AddWithValue("@Status", status);
                        command.Parameters.AddWithValue("@Field1", field1);
                        command.Parameters.AddWithValue("@Field2", field2);
                        command.Parameters.AddWithValue("@Description", description);
                        command.Parameters.AddWithValue("@InstanceId", instanceId);
                        command.Parameters.AddWithValue("@StartDateTime", startDateTime);
                        command.Parameters.AddWithValue("@EndDateTime", endDateTime);

                        command.ExecuteNonQuery();
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogError($"Error processing message: {ex.Message}");
            }
        }
    }
}
