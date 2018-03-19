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

        [TestMethod]
        public void InstallSubscription()
        {
            SqlCommand sqlCommand = new SqlCommand();
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("param1", SqlDbType.Int, 1));
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("param2", SqlDbType.Int, 1));
            Subscription subscription = new Subscription("subscriberString", "dbo", "TestProcedure", sqlCommand.Parameters);
            SqlProceduresInstance.InstallSubscription(subscription);
            Assert.Fail();
        }

        [TestMethod]
        public void ReceiveSubscription()
        {
            Assert.Fail();
        }

        [TestMethod]
        public void SqlUnInstal()
        {
            Assert.Fail();
            
        }
    }
}
