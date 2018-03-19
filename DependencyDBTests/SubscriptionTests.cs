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
    public class SubscriptionTests
    {
        [TestMethod]
        public void TestSubscriptionHash()
        {
            SqlCommand sqlCommand = new SqlCommand();
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("param1", SqlDbType.Int, 1));
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("param2", SqlDbType.Int, 1));
            Subscription subscription1 = new Subscription("TestApp","subscriberString", "dbo", "P_TestProcedure", sqlCommand.Parameters);

            sqlCommand = new SqlCommand();
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("param1", SqlDbType.Int, 1));
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("param2", SqlDbType.Int, 1));
            Subscription subscription2 = new Subscription("TestApp","subscriberString2", "dbo", "P_TestProcedure", sqlCommand.Parameters,15000);

            if (subscription1.GetHashCode() != subscription2.GetHashCode())
                Assert.Fail("Get hask code function returns diffrent values for similar object.");
            
            sqlCommand = new SqlCommand();
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("param1", SqlDbType.Int, 1));
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("param2", SqlDbType.Int, 2));
            Subscription subscription3 = new Subscription("TestApp","subscriberString3", "dbo", "P_TestProcedure", sqlCommand.Parameters, 15000);

            if (subscription3.GetHashCode() == subscription2.GetHashCode())
                Assert.Fail("Get hask code function returns same values for diffrent object.");
        }
    }
}
