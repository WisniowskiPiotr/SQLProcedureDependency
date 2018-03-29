using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using DBConnection;
using System.Data.SqlClient;
using System.Data;
using System.Threading;
using System.Threading.Tasks;

namespace DBConnectionTests
{
    [TestClass]
    public class DependencyDBTests
    {
        string Subscriber;
        NotificationMessage Message;
        private void HandleMsg(string subscriber, NotificationMessage message)
        {
            Subscriber = subscriber;
            Message = message;
        }

        public DependencyDBTests()
        {
            Subscriber = null;
            Message = null;
        }

        [TestMethod]
        public void PublicReceiveSingleSubscription()
        {
            SetDBState.SetAdminInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass);

            DependencyDB.StartListener(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.ServiceConnectionString,
                HandleMsg
                );

            SqlParameterCollection sqlParameters = SqlProceduresTests.GetSqlParameterCollectionForTestProcedure(10);
            DateTime validTill = (DateTime.Now).AddDays(5.0);
            DependencyDB.Subscribe(
                CommonTestsValues.MainServiceName,
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

            DependencyDB.StopListener( CommonTestsValues.MainServiceName);

            if (Message == null)
            {
                Assert.Fail();
            }
        }

        public bool ReceiveSingleSubscription()
        {
            SqlParameterCollection sqlParameters = SqlProceduresTests.GetSqlParameterCollectionForTestProcedure(10);
            DateTime validTill = (DateTime.Now).AddDays(5.0);
            DependencyDB.Subscribe(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.FirstSunscriberName,
                CommonTestsValues.SubscribedProcedureSchema,
                "P_TestGetProcedure",
                sqlParameters,
                validTill
                );

            Task waitForResults = new Task(() =>
            {
                while (Message == null)
                {
                    Thread.Sleep(100);
                }
            });
            waitForResults.Start();
            waitForResults.Wait(10000);

            DependencyDB.StopListener(CommonTestsValues.MainServiceName);

            if (Message == null)
            {
                return false;
            }
            else
            {
                return true;
            }
        }
    }
}
