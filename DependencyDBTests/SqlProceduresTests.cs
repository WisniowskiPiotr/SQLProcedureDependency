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
        SqlProcedures SqlProceduresInstance = new SqlProcedures( CommonTestsValues.ServiceConnectionString);
        AccessDB serviceAccessDB = new AccessDB(CommonTestsValues.ServiceConnectionString);
        AccessDB serviceAccessDBAdmin = new AccessDB(CommonTestsValues.AdminConnectionString);

        public static SqlParameterCollection GetSqlParameterCollectionForTestProcedure(int param1=0, int param2=0, bool insert1=false, bool insert2 = false, bool delete1 = false, bool delete2 = false)
        {
            SqlCommand sqlCommand = new SqlCommand();
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, param1));
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, param2));
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert1", SqlDbType.Bit, insert1));
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert2", SqlDbType.Bit, insert2));
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete1", SqlDbType.Bit, delete1));
            sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete2", SqlDbType.Bit, delete2));
            return sqlCommand.Parameters;
        }

        [TestMethod]
        public void SetSubscription()
        {
            SetDBState.SetAdminInstalledDB(CommonTestsValues.DefaultTestDBName, CommonTestsValues.MainServiceName, CommonTestsValues.LoginPass);

            SqlParameterCollection sqlParameters = GetSqlParameterCollectionForTestProcedure(10, 20);
            Subscription subscription = new Subscription(CommonTestsValues.MainServiceName, CommonTestsValues.FirstSunscriberName, CommonTestsValues.SubscribedProcedureSchema, CommonTestsValues.SubscribedProcedureName, sqlParameters);
            SqlProceduresInstance.InstallSubscription(subscription);

            List<Tuple<string>> testResult = SetDBState.RunFile<Tuple<string>>(
                Resources.SetSubscription_Test,
                SetDBState.AccesType.StandardUser,
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginName,
                CommonTestsValues.SchemaName,
                CommonTestsValues.Username,
                CommonTestsValues.QueryName,
                CommonTestsValues.ServiceName,
                CommonTestsValues.SubscribersTableName,
                CommonTestsValues.FirstSunscriberName);
            if (testResult.Count != 1 && !string.IsNullOrWhiteSpace(testResult[0].Item1))
            {
                Assert.Fail(testResult[0].Item1);
            }
        }

        [TestMethod]
        public void ReceiveSubscription()
        {
            SqlParameterCollection sqlParameters = GetSqlParameterCollectionForTestProcedure(10, 20);
            SetDBState.SetSingleSubscriptionInstalledDB(
                CommonTestsValues.DefaultTestDBName, 
                CommonTestsValues.MainServiceName, 
                CommonTestsValues.LoginPass, 
                CommonTestsValues.FirstSunscriberName,
                sqlParameters);

            SqlCommand dataChangeCommand = new SqlCommand("dbo.P_TestProcedure");
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, DateTime.Now.Hour ));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, DateTime.Now.Minute));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert1", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert2", SqlDbType.Bit, false));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete1", SqlDbType.Bit, false));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete2", SqlDbType.Bit, false));
            serviceAccessDBAdmin.SQLRunNonQueryProcedure(dataChangeCommand, 30);


            SqlCommand dataReceiveCommand = new SqlCommand(CommonTestsValues.MainServiceName + ".[P_ReceiveSubscription]");
            List<Tuple<string>> testResult = serviceAccessDB.SQLRunQueryProcedure<Tuple<string>>(dataReceiveCommand, 20);
            if (testResult.Count < 1 || string.IsNullOrWhiteSpace(testResult[0].Item1))
            {
                Assert.Fail(testResult[0].Item1);
            }
        }
    }
}
