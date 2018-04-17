using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Data.SqlClient;
using System.Data;
using System.Threading;
using System.Threading.Tasks;
using SQLDependency.DBConnection;

namespace SQLDependency.DBConnectionTests
{
    [TestClass]
    public class DependencyDBTests
    {
        NotificationMessage Message;
        private void HandleMsg( NotificationMessage message)
        {
            Message = message;
        }

        public DependencyDBTests()
        {
            Message = null;
        }

        [TestMethod]
        public void PublicReceiveSingleSubscription()
        {
            SetDBState.SetAdminInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass);

            DependencyDB.AddReceiver(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.ServiceConnectionString
                );
            Receiver receiver = DependencyDB.GetReceiver(CommonTestsValues.MainServiceName);
            receiver.MessageHandler += HandleMsg;
            receiver.ErrorMessageHandler += HandleMsg;
            receiver.UnsubscribedMessageHandler += HandleMsg;
            Task receiverTask = new Task(receiver.Start);
            receiverTask.Start();

            SqlParameterCollection sqlParameters = SqlProceduresTests.GetSqlParameterCollectionForTestProcedure(10);
            DateTime validTill = (DateTime.Now).AddDays(5.0);
            receiver.Subscribe(
                CommonTestsValues.FirstSunscriberName,
                CommonTestsValues.SubscribedProcedureSchema,
                "P_TestGetProcedure",
                sqlParameters,
                validTill
                );
            
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
                while (Message == null)
                {
                    Thread.Sleep(100);
                }
            });
            waitForResults.Start();
            waitForResults.Wait(10000);
            receiverTask.Wait(1);

            DependencyDB.StopReceiver( CommonTestsValues.MainServiceName);

            if (Message == null)
            {
                Assert.Fail();
            }
        }
    }
}
