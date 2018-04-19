using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Data.SqlClient;
using System.Collections.Generic;
using System.Data;
using SQLDependency.DBConnection;
using SQLDependency.DBConnectionTests.Properties;
using System.Threading.Tasks;
using System.Threading;

namespace SQLDependency.DBConnectionTests
{
    [TestClass]
    public class ListenerTests
    {
        AccessDB serviceAccessDBAdmin = new AccessDB(CommonTestsValues.AdminConnectionString);
        NotificationMessage Message = null;

        [TestMethod]
        public void TestTimeout()
        {
            SqlParameterCollection sqlParameters = SqlProceduresTests.GetSqlParameterCollectionForTestProcedure(10);
            SetDBState.SetSingleSubscriptionInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass,
                CommonTestsValues.FirstSunscriberName,
                "P_TestGetProcedure",
                sqlParameters);

            DependencyDB.AddReceiver(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.ServiceConnectionString
                );
            Receiver receiver = DependencyDB.GetReceiver(CommonTestsValues.MainServiceName);
            receiver.MessageHandler += HandleMsg;
            receiver.ErrorMessageHandler += HandleMsg;
            receiver.UnsubscribedMessageHandler += HandleMsg;
            Task receiverTask = new Task(receiver.Listen);
            receiverTask.Start();

            Task waitForResults = new Task(() =>
            {
                while (Message == null)
                {
                    Thread.Sleep(100);
                }
            });
            waitForResults.Start();
            waitForResults.Wait(10000);
        }

        private void HandleMsg( NotificationMessage message)
        {
            Message = message;
        }

        [TestMethod]
        public void TestStopListening()
        {
            SqlParameterCollection sqlParameters = SqlProceduresTests.GetSqlParameterCollectionForTestProcedure(10);
            SetDBState.SetSingleSubscriptionInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass,
                CommonTestsValues.FirstSunscriberName,
                "P_TestGetProcedure",
                sqlParameters);

            Receiver receiver = DependencyDB.AddReceiver(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.ServiceConnectionString
                );
            receiver.MessageHandler += HandleMsg;
            receiver.ErrorMessageHandler += HandleMsg;
            receiver.UnsubscribedMessageHandler += HandleMsg;
            Task receiverTask = new Task(receiver.Listen);
            receiverTask.Start();

            SqlCommand dataChangeCommand = new SqlCommand("dbo.P_TestSetProcedure");
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert1", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert2", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete1", SqlDbType.Bit, false));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete2", SqlDbType.Bit, false));
            serviceAccessDBAdmin.SQLRunNonQueryProcedure(dataChangeCommand, 30);

            Task waitForResults = new Task(() =>
            {
                while (Message == null)
                {
                    Thread.Sleep(100);
                }
            });
            waitForResults.Start();
            waitForResults.Wait(10000);
            if (Message == null)
            {
                Assert.Fail("No mesage received after DependencyDB.StartListener().");
            }

            DependencyDB.StopReceiver(CommonTestsValues.MainServiceName);
            Thread.Sleep(100000);
            Message = null;

            dataChangeCommand = new SqlCommand("dbo.P_TestSetProcedure");
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert1", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert2", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete1", SqlDbType.Bit, false));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete2", SqlDbType.Bit, false));
            serviceAccessDBAdmin.SQLRunNonQueryProcedure(dataChangeCommand, 30);
            
            waitForResults = new Task(() =>
            {
                while (Message == null)
                {
                    Thread.Sleep(100);
                }
            });
            waitForResults.Start();
            waitForResults.Wait(10000);
            receiverTask.Wait(1);
            if (Message != null)
            {
                Assert.Fail("Mesage received after DependencyDB.StopListener().");
            }
        }
        [TestMethod]
        public void TestStopListening2()
        {
            SqlParameterCollection sqlParameters = SqlProceduresTests.GetSqlParameterCollectionForTestProcedure(10);
            SetDBState.SetSingleSubscriptionInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass,
                CommonTestsValues.FirstSunscriberName,
                "P_TestGetProcedure",
                sqlParameters);

            Receiver receiver = DependencyDB.AddReceiver(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.ServiceConnectionString
                );
            receiver.MessageHandler += HandleMsg;
            receiver.ErrorMessageHandler += HandleMsg;
            receiver.UnsubscribedMessageHandler += HandleMsg;
            CancellationTokenSource cancelationSuorce = new CancellationTokenSource();
            Task receiverTask = new Task(() =>
                {
                    receiver.Listen(cancelationSuorce.Token);
                }
            );
            receiverTask.Start();

            SqlCommand dataChangeCommand = new SqlCommand("dbo.P_TestSetProcedure");
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert1", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert2", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete1", SqlDbType.Bit, false));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete2", SqlDbType.Bit, false));
            serviceAccessDBAdmin.SQLRunNonQueryProcedure(dataChangeCommand, 30);

            Task waitForResults = new Task(() =>
            {
                while (Message == null)
                {
                    Thread.Sleep(100);
                }
            });
            waitForResults.Start();
            waitForResults.Wait(10000);
            if (Message == null)
            {
                Assert.Fail("No mesage received after DependencyDB.StartListener().");
            }

            //DependencyDB.StopReceiver(CommonTestsValues.MainServiceName);
            cancelationSuorce.Cancel();
            Thread.Sleep(100000);
            Message = null;

            dataChangeCommand = new SqlCommand("dbo.P_TestSetProcedure");
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert1", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert2", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete1", SqlDbType.Bit, false));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete2", SqlDbType.Bit, false));
            serviceAccessDBAdmin.SQLRunNonQueryProcedure(dataChangeCommand, 30);

            waitForResults = new Task(() =>
            {
                while (Message == null)
                {
                    Thread.Sleep(100);
                }
            });
            waitForResults.Start();
            waitForResults.Wait(10000);
            receiverTask.Wait(1);
            if (Message != null)
            {
                Assert.Fail("Mesage received after DependencyDB.StopListener().");
            }
        }
    }
}
