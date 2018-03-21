using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using DBConnection;
using DBConnectionTests.Properties;
using System.Data.SqlClient;
using System.Collections.Generic;
using Microsoft.SqlServer.Server;
using System.Data;

namespace DBConnectionTests
{
    [TestClass]
    public class SqlProceduresTests
    {
        const string MainServiceName = "DependencyDB";
        SqlProcedures SqlProceduresInstance = new SqlProcedures(MainServiceName, CommonTestsValues.ServiceConnectionString);
        AccessDB serviceAccessDB = new AccessDB(CommonTestsValues.ServiceConnectionString);
        AccessDB serviceAccessDBAdmin = new AccessDB(CommonTestsValues.AdminConnectionString);

        [TestMethod]
        public void GetSubscription()
        {
            // instal subs
            string slqCommandText;
            SqlCommand sqlCommand = new SqlCommand();
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("param1", SqlDbType.Int, 1));
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("param2", SqlDbType.Int, 1));
            Subscription subscription = new Subscription("TestApp", "subscriberString", "dbo", "P_TestProcedure", sqlCommand.Parameters);
            SqlProceduresInstance.InstallSubscription(subscription);

            slqCommandText = string.Format(
                Resources.SqlProcedures_InstallSubscription,
                CommonTestsValues.MainServiceName,
                subscription.SubscriberString,
                subscription.GetHashCode().ToString(),
                "dbo",
                "TBL_TestTable"
                );
            sqlCommand = new SqlCommand(slqCommandText);
            List<Tuple<int>> testResult = serviceAccessDB.SQLRunQueryProcedure<Tuple<int>>(sqlCommand);
            if (testResult.Count != 1 && testResult[0].Item1 != 1)
            {
                Assert.Fail("Not all objects created during install.");
            }

            // change data and receive notification
            slqCommandText = string.Format(
                Resources.SqlProcedures_ChangeData,
                CommonTestsValues.MainServiceName,
                "dbo",
                "TBL_TestTable"
                );
            sqlCommand = new SqlCommand(slqCommandText);
            serviceAccessDBAdmin.SQLRunNonQueryProcedure(sqlCommand);
            List<EventMessage> notifications = SqlProceduresInstance.ReceiveSubscription(30);
            if (notifications == null || notifications.Count == 0)
                Assert.Fail("Coudnt receive notification");

            //// uninstall notification
            //SqlProceduresInstance.UninstallSubscription(subscription);

            //slqCommandText = string.Format(
            //    Resources.SqlProcedures_InstallSubscription,
            //    CommonTestsValues.MainServiceName,
            //    subscription.SubscriberString,
            //    subscription.GetHashCode().ToString(),
            //    "dbo",
            //    "TBL_TestTable"
            //    );
            //sqlCommand = new SqlCommand(slqCommandText);
            //List<Tuple<int>> testResult2 = serviceAccessDB.SQLRunQueryProcedure<Tuple<int>>(sqlCommand);
            //if (testResult2.Count != 1 && testResult2[0].Item1 != 0)
            //{
            //    Assert.Fail("Not all objects created during install.");
            //}
        }
    }
}
