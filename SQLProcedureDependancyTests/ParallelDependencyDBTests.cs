using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Data.SqlClient;
using System.Collections.Generic;
using System.Data;
using System.Threading;
using System.Threading.Tasks;
using SQLDependency.DBConnectionTests.Properties;
using SQLProcedureDependency;
using SQLProcedureDependency.DBConnection;
using SQLProcedureDependency.Message;

namespace SQLDependency.DBConnectionTests
{
    [TestClass]
    public class ParallelDependencyDBTests
    {
        AccessDB accesDB = new AccessDB(CommonTestsValues.AdminConnectionString);
        int CountParallelInstances = 1000;
        List<string> SingleChangeWithMultipleSubscribers_Subscribers = new List<string>();
        private void SingleChangeWithMultipleSubscribers_HandleMsg( NotificationMessage message)
        {
            SingleChangeWithMultipleSubscribers_Subscribers.RemoveAll(x => x == message.SubscriberString);
        }
        [TestMethod]
        public void SingleChangeWithMultipleSubscribers()
        {
            SingleChangeWithMultipleSubscribers_Subscribers = new List<string>();
            SetDBState.SetAdminInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass);

            DependencyDB.AddReceiver(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.ServiceConnectionString
                );
            Receiver receiver = DependencyDB.GetReceiver(CommonTestsValues.MainServiceName);
            receiver.MessageHandler += SingleChangeWithMultipleSubscribers_HandleMsg;
            receiver.ErrorMessageHandler += SingleChangeWithMultipleSubscribers_HandleMsg;
            receiver.UnsubscribedMessageHandler += SingleChangeWithMultipleSubscribers_HandleMsg;
            Task receiverTask = new Task(receiver.Listen);
            receiverTask.Start();

            SqlParameterCollection sqlParameters = SqlProceduresTests.GetSqlParameterCollectionForTestProcedure(10);
            DateTime validTill = (DateTime.Now).AddDays(5.0);
            for (int i = 0; i < CountParallelInstances; i++)
            {
                string subscriberName = "subscriber" + i;
                SingleChangeWithMultipleSubscribers_Subscribers.Add(subscriberName);
                receiver.Subscribe(
                    subscriberName,
                    CommonTestsValues.SubscribedProcedureSchema,
                    "P_TestGetProcedure",
                    sqlParameters,
                    validTill
                    );
            }

            AccessDB accessDB = new AccessDB(CommonTestsValues.AdminConnectionString);
            SqlCommand dataChangeCommand = new SqlCommand("dbo.P_TestSetProcedure");
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert1", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert2", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete1", SqlDbType.Bit, false));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete2", SqlDbType.Bit, false));
            accessDB.SQLRunNonQueryProcedure(dataChangeCommand, 30);


            Task waitForResults = new Task(() =>
            {
                while (SingleChangeWithMultipleSubscribers_Subscribers.Count > 0)
                {
                    Thread.Sleep(100);
                }
            });
            waitForResults.Start();
            waitForResults.Wait(20000);
            receiverTask.Wait(1);

            DependencyDB.StopReceiver(CommonTestsValues.MainServiceName);

            if (SingleChangeWithMultipleSubscribers_Subscribers.Count > 0)
            {
                Assert.Fail(SingleChangeWithMultipleSubscribers_Subscribers.Count + " subscribers not recived notification.");
            }
        }

        List<string> ParallelSubscribeTest_Subscribers = new List<string>();
        private void ParallelSubscribeTest_HandleMsg( NotificationMessage message)
        {
            ParallelSubscribeTest_Subscribers.RemoveAll(x => x == message.SubscriberString);
        }
        [TestMethod]
        public void ParallelSubscribeTest()
        {
            ParallelSubscribeTest_Subscribers = new List<string>();
            SetDBState.SetAdminInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass);

            DependencyDB.AddReceiver(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.ServiceConnectionString
                );
            Receiver receiver = DependencyDB.GetReceiver(CommonTestsValues.MainServiceName);
            receiver.MessageHandler += ParallelSubscribeTest_HandleMsg;
            receiver.ErrorMessageHandler += ParallelSubscribeTest_HandleMsg;
            receiver.UnsubscribedMessageHandler += ParallelSubscribeTest_HandleMsg;
            Task receiverTask = new Task(receiver.Listen);
            receiverTask.Start();

            SqlParameterCollection sqlParameters = SqlProceduresTests.GetSqlParameterCollectionForTestProcedure(10);
            DateTime validTill = (DateTime.Now).AddDays(5.0);
            for (int i = 0; i < CountParallelInstances; i++)
            {
                string subscriberName = "subscriber" + i;
                ParallelSubscribeTest_Subscribers.Add(subscriberName);
            }
            Parallel.ForEach(
                ParallelSubscribeTest_Subscribers,
                (subscriberName) =>
                {
                    switch (subscriberName.GetHashCode() % 2)
                    {
                        case 1:
                            accesDB.SQLRunNonQueryProcedure(new SqlCommand(Resources.SelectFromTable));
                            break;
                        default:
                            break;
                    }
                    receiver.Subscribe(
                        subscriberName,
                        CommonTestsValues.SubscribedProcedureSchema,
                        "P_TestGetProcedure",
                        sqlParameters,
                        validTill
                        );
                });
            

            AccessDB accessDB = new AccessDB(CommonTestsValues.AdminConnectionString);
            SqlCommand dataChangeCommand = new SqlCommand("dbo.P_TestSetProcedure");
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert1", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert2", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete1", SqlDbType.Bit, false));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete2", SqlDbType.Bit, false));
            accessDB.SQLRunNonQueryProcedure(dataChangeCommand, 30);


            Task waitForResults = new Task(() =>
            {
                while (ParallelSubscribeTest_Subscribers.Count > 0)
                {
                    Thread.Sleep(100);
                }
            });
            waitForResults.Start();
            waitForResults.Wait(20000);
            receiverTask.Wait(1);

            DependencyDB.StopReceiver(CommonTestsValues.MainServiceName);

            if (ParallelSubscribeTest_Subscribers.Count > 0)
            {
                Assert.Fail(ParallelSubscribeTest_Subscribers.Count + " subscribers not reciver notification.");
            }
        }

        List<string> ParallelUnSubscribeTest_Subscribers = new List<string>();
        private void ParallelUnSubscribeTest_HandleMsg( NotificationMessage message)
        {
            //ParallelUnSubscribeTest_Subscribers.RemoveAll(x => x == subscriber);
        }
        [TestMethod]
        public void ParallelUnSubscribeTest()
        {
            ParallelUnSubscribeTest_Subscribers = new List<string>();
            SetDBState.SetAdminInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass);

            DependencyDB.AddReceiver(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.ServiceConnectionString
                );
            Receiver receiver = DependencyDB.GetReceiver(CommonTestsValues.MainServiceName);
            receiver.MessageHandler += ParallelUnSubscribeTest_HandleMsg;
            receiver.ErrorMessageHandler += ParallelUnSubscribeTest_HandleMsg;
            receiver.UnsubscribedMessageHandler += ParallelUnSubscribeTest_HandleMsg;
            Task receiverTask = new Task(receiver.Listen);
            receiverTask.Start();


            SqlParameterCollection sqlParameters = SqlProceduresTests.GetSqlParameterCollectionForTestProcedure(10);
            DateTime validTill = (DateTime.Now).AddDays(5.0);
            for (int i = 0; i < CountParallelInstances; i++)
            {
                string subscriberName = "subscriber" + i;
                ParallelUnSubscribeTest_Subscribers.Add(subscriberName);
            }
            Parallel.ForEach(ParallelUnSubscribeTest_Subscribers,
                (subscriberName) =>
                {
                    switch (subscriberName.GetHashCode() % 2)
                    {
                        case 1:
                            accesDB.SQLRunNonQueryProcedure(new SqlCommand(Resources.SelectFromTable));
                            break;
                        default:
                            receiver.Subscribe(
                                subscriberName,
                                CommonTestsValues.SubscribedProcedureSchema,
                                "P_TestGetProcedure",
                                sqlParameters,
                                validTill
                                );
                            break;
                    }
                });

            Parallel.ForEach(ParallelUnSubscribeTest_Subscribers,
                (subscriberName) =>
                {
                    switch (subscriberName.GetHashCode() % 2)
                    {
                        case 1:
                            accesDB.SQLRunNonQueryProcedure(new SqlCommand(Resources.SelectFromTable));
                            break;
                        default:
                            break;
                    }
                    receiver.UnSubscribe(
                        subscriberName,
                        CommonTestsValues.SubscribedProcedureSchema,
                        "P_TestGetProcedure",
                        sqlParameters
                        );
                });
            receiverTask.Wait(1);

            DependencyDB.StopReceiver(CommonTestsValues.MainServiceName);
            
        }

        List<string> ParallelUnSubscribeSubscribeTest_Subscribers = new List<string>();
        private void ParallelUnSubscribeSubscribeTest_HandleMsg( NotificationMessage message)
        {
            //ParallelUnSubscribeSubscribeTest_Subscribers.RemoveAll(x => x == subscriber);
        }
        [TestMethod]
        public void ParallelUnSubscribeSubscribeTest()
        {
            ParallelUnSubscribeTest_Subscribers = new List<string>();
            SetDBState.SetAdminInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass);

            DependencyDB.AddReceiver(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.ServiceConnectionString
                );
            Receiver receiver = DependencyDB.GetReceiver(CommonTestsValues.MainServiceName);
            receiver.MessageHandler += ParallelUnSubscribeSubscribeTest_HandleMsg;
            receiver.ErrorMessageHandler += ParallelUnSubscribeSubscribeTest_HandleMsg;
            receiver.UnsubscribedMessageHandler += ParallelUnSubscribeSubscribeTest_HandleMsg;
            Task receiverTask = new Task(receiver.Listen);
            receiverTask.Start();


            SqlParameterCollection sqlParameters = SqlProceduresTests.GetSqlParameterCollectionForTestProcedure(10);
            DateTime validTill = (DateTime.Now).AddDays(5.0);
            for (int i = 0; i < CountParallelInstances; i++)
            {
                string subscriberName = "subscriber" + i;
                ParallelUnSubscribeTest_Subscribers.Add(subscriberName);
            }
            Parallel.ForEach(ParallelUnSubscribeTest_Subscribers,
                (subscriberName) =>
                {
                    switch (subscriberName.GetHashCode() % 2)
                    {
                        case 1:
                            accesDB.SQLRunNonQueryProcedure(new SqlCommand(Resources.SelectFromTable));
                            break;
                        default:
                            receiver.Subscribe(
                                subscriberName,
                                CommonTestsValues.SubscribedProcedureSchema,
                                "P_TestGetProcedure",
                                sqlParameters,
                                validTill
                                );
                            break;
                    }
                });

            Parallel.ForEach(ParallelUnSubscribeTest_Subscribers,
                (subscriberName) =>
                {
                    switch (subscriberName.GetHashCode() % 3)
                    {
                        case 1:
                            accesDB.SQLRunNonQueryProcedure(new SqlCommand(Resources.SelectFromTable));
                            break;
                        case 2:
                            receiver.UnSubscribe(
                                subscriberName,
                                CommonTestsValues.SubscribedProcedureSchema,
                                "P_TestGetProcedure",
                                sqlParameters
                                );
                            break;
                        default:
                            receiver.Subscribe(
                                subscriberName,
                                CommonTestsValues.SubscribedProcedureSchema,
                                "P_TestGetProcedure",
                                sqlParameters,
                                validTill
                                );
                            break;
                    }
                });
            receiverTask.Wait(1);

            DependencyDB.StopReceiver(CommonTestsValues.MainServiceName);

        }
    }
}
