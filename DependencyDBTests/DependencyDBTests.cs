using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using DBConnection;
using DBConnectionTests.Properties;
using System.Data.SqlClient;
using System.Collections.Generic;
using Microsoft.SqlServer.Server;
using System.Data;
using System.Threading;
using System.Threading.Tasks;

namespace DBConnectionTests
{
    [TestClass]
    public class DependencyDBTests
    {
        static string Subscriber;
        static NotificationMessage Message;
        private static void HandleMsg(string subscriber, NotificationMessage message)
        {
            Subscriber = subscriber;
            Message = message;
        }

        [TestMethod]
        public void SetSubscription()
        {
            SetDBState.SetAdminInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass);

            Subscriber = null;
            Message = null;
            DependencyDB.StartListener(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.ServiceConnectionString,
                HandleMsg
                );
            
            SqlParameterCollection sqlParameters = SqlProceduresTests.GetSqlParameterCollectionForTestProcedure(10);
            DateTime validTill = DateTime.Now;
            validTill.AddDays(5.0);
            DependencyDB.Subscribe(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.ServiceConnectionString,
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

            Thread.Sleep(10000);

            if (Message == null)
            {
                Assert.Fail();
            }
        }
    }
}
