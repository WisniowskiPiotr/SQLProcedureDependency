using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Data.SqlClient;
using System.Collections.Generic;
using System.Data;
using SQLDependency.DBConnection;
using SQLDependency.DBConnectionTests.Properties;
using SQLProcedureDependency.DBConnection;
using SQLProcedureDependency;
using SQLProcedureDependency.Message;

namespace SQLDependency.DBConnectionTests
{
    [TestClass]
    public class SqlProceduresTests
    {
        SqlProcedures SqlProceduresInstance = new SqlProcedures( CommonTestsValues.ServiceConnectionString);
        AccessDB serviceAccessDB = new AccessDB(CommonTestsValues.ServiceConnectionString);
        AccessDB serviceAccessDBAdmin = new AccessDB(CommonTestsValues.AdminConnectionString);

        public static SqlParameterCollection GetSqlParameterCollectionForTestProcedure(int? param1=null, int? param2=null, bool insert1=false, bool insert2 = false, bool delete1 = false, bool delete2 = false)
        {
            SqlCommand sqlCommand = new SqlCommand();
            if(param1.HasValue)
                sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, param1));
            else
                sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, DBNull.Value));
            if (param2.HasValue)
                sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, param2));
            else
                sqlCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, DBNull.Value));
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

            SqlParameterCollection sqlParameters = GetSqlParameterCollectionForTestProcedure(10);
            Subscription subscription = new Subscription(
                CommonTestsValues.MainServiceName, 
                CommonTestsValues.FirstSunscriberName, 
                CommonTestsValues.SubscribedProcedureSchema,
                "P_TestGetProcedure", 
                sqlParameters);
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
            if (testResult.Count != 1 || string.IsNullOrWhiteSpace(testResult[0].Item1) || testResult[0].Item1.Substring(0, 1) != "1")
            {
                Assert.Fail(testResult[0].Item1);
            }
        }

        [TestMethod]
        public void SetDoubleSubscription()
        {
            SqlParameterCollection sqlParameters = GetSqlParameterCollectionForTestProcedure(10);
            SetDBState.SetTwoSubscriptionInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass,
                CommonTestsValues.FirstSunscriberName,
                "P_TestGetProcedure",
                sqlParameters,
                CommonTestsValues.SecondSunscriberName,
                "P_TestGetProcedure",
                sqlParameters
                );

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
                CommonTestsValues.AnySunscriberName);
            if (testResult.Count != 1 || string.IsNullOrWhiteSpace(testResult[0].Item1) || testResult[0].Item1.Substring(0, 1) != "2")
            {
                Assert.Fail(testResult[0].Item1);
            }
        }

        [TestMethod]
        public void ReceiveErrorSubscription()
        {
            SqlParameterCollection sqlParameters = GetSqlParameterCollectionForTestProcedure(10);
            SetDBState.SetSingleSubscriptionInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass,
                CommonTestsValues.FirstSunscriberName,
                "P_TestSetProcedure",
                sqlParameters);

            SqlCommand dataChangeCommand = new SqlCommand("dbo.P_TestSetProcedure");
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, 10 ));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert1", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert2", SqlDbType.Bit, false));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete1", SqlDbType.Bit, false));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete2", SqlDbType.Bit, false));
            serviceAccessDBAdmin.SQLRunNonQueryProcedure(dataChangeCommand, 30);

            List<NotificationMessage> testResult= SqlProceduresInstance.ReceiveSubscription(CommonTestsValues.MainServiceName);
            if (testResult.Count < 1 || string.IsNullOrWhiteSpace(testResult[0].MessageString) || testResult[0].MessageType != NotificationMessageType.Error || testResult[0].Error.ErrorNumber != "10700")
            {
                Assert.Fail(testResult[0].MessageString);
            }
        }

        [TestMethod]
        public void ReceiveSubscription()
        {
            SqlParameterCollection sqlParameters = GetSqlParameterCollectionForTestProcedure(10);
            SetDBState.SetSingleSubscriptionInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass,
                CommonTestsValues.FirstSunscriberName,
                "P_TestGetProcedure",
                sqlParameters);

            SqlCommand dataChangeCommand = new SqlCommand("dbo.P_TestSetProcedure");
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert1", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert2", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete1", SqlDbType.Bit, false));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete2", SqlDbType.Bit, false));
            serviceAccessDBAdmin.SQLRunNonQueryProcedure(dataChangeCommand, 30);

            List<NotificationMessage> testResult = SqlProceduresInstance.ReceiveSubscription(CommonTestsValues.MainServiceName,15);
            if (testResult.Count < 1 || string.IsNullOrWhiteSpace(testResult[0].MessageString) || testResult[0].MessageType != NotificationMessageType.InsertedData || testResult[0].Inserted == null)
            {
                Assert.Fail(testResult[0].MessageString);
            }
        }

        [TestMethod]
        public void ReceiveTwoSubscriptions()
        {
            SqlParameterCollection sqlParameters = GetSqlParameterCollectionForTestProcedure(10);
            SetDBState.SetTwoSubscriptionInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass,
                CommonTestsValues.FirstSunscriberName,
                "P_TestGetProcedure",
                sqlParameters,
                CommonTestsValues.SecondSunscriberName,
                "P_TestGetProcedure",
                sqlParameters);

            SqlCommand dataChangeCommand = new SqlCommand("dbo.P_TestSetProcedure");
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param1", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Param2", SqlDbType.Int, 10));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert1", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Insert2", SqlDbType.Bit, true));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete1", SqlDbType.Bit, false));
            dataChangeCommand.Parameters.Add(AccessDB.CreateSqlParameter("@V_Delete2", SqlDbType.Bit, false));
            serviceAccessDBAdmin.SQLRunNonQueryProcedure(dataChangeCommand, 30);

            for (int i = 0; i < 2; i++)
            {
                List<NotificationMessage> testResult = SqlProceduresInstance.ReceiveSubscription(CommonTestsValues.MainServiceName, 15);
                if (testResult.Count < 1 || string.IsNullOrWhiteSpace(testResult[0].MessageString) || testResult[0].MessageType != NotificationMessageType.InsertedData || testResult[0].Inserted == null)
                {
                    Assert.Fail(testResult[0].MessageString);
                }
            }
        }

        [TestMethod]
        public void UninstallSingleSubscription()
        {
            SqlParameterCollection sqlParameters = GetSqlParameterCollectionForTestProcedure(10);
            SetDBState.SetTwoSubscriptionInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass,
                CommonTestsValues.FirstSunscriberName,
                "P_TestGetProcedure",
                sqlParameters,
                CommonTestsValues.SecondSunscriberName,
                "P_TestGetProcedure",
                sqlParameters);

            Subscription subscription = new Subscription(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.FirstSunscriberName,
                CommonTestsValues.SubscribedProcedureSchema,
                "P_TestGetProcedure",
                sqlParameters);
            SqlProceduresInstance.UninstallSubscription(subscription);

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
                CommonTestsValues.AnySunscriberName);
            if (testResult.Count != 1 || string.IsNullOrWhiteSpace(testResult[0].Item1) || testResult[0].Item1.Substring(0, 1) != "1")
            {
                Assert.Fail(testResult[0].Item1);
            }
            List<NotificationMessage> testMessage = SqlProceduresInstance.ReceiveSubscription(CommonTestsValues.MainServiceName, 15);
            if (testMessage.Count < 1 || string.IsNullOrWhiteSpace(testMessage[0].MessageString) || testMessage[0].MessageType != NotificationMessageType.Unsubscribed )
            {
                Assert.Fail(testMessage[0].MessageString);
            }
        }

        [TestMethod]
        public void UninstallDoubleSubscription()
        {
            SqlParameterCollection sqlParameters = GetSqlParameterCollectionForTestProcedure(10);
            SetDBState.SetTwoSubscriptionInstalledDB(
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginPass,
                CommonTestsValues.FirstSunscriberName,
                "P_TestGetProcedure",
                sqlParameters,
                CommonTestsValues.SecondSunscriberName,
                "P_TestGetProcedure",
                sqlParameters);

            Subscription subscription1 = new Subscription(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.FirstSunscriberName,
                CommonTestsValues.SubscribedProcedureSchema,
                "P_TestGetProcedure",
                sqlParameters);
            SqlProceduresInstance.UninstallSubscription(subscription1);

            Subscription subscription2 = new Subscription(
                CommonTestsValues.MainServiceName,
                CommonTestsValues.SecondSunscriberName,
                CommonTestsValues.SubscribedProcedureSchema,
                "P_TestGetProcedure",
                sqlParameters);
            SqlProceduresInstance.UninstallSubscription(subscription2);

            List<Tuple<string>> testResult = SetDBState.RunFile<Tuple<string>>(
                Resources.UninstallSubscription_Test,
                SetDBState.AccesType.StandardUser,
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginName,
                CommonTestsValues.SchemaName,
                CommonTestsValues.Username,
                CommonTestsValues.QueryName,
                CommonTestsValues.ServiceName,
                CommonTestsValues.SubscribersTableName,
                CommonTestsValues.AnySunscriberName);
            if (testResult.Count != 1 || !string.IsNullOrWhiteSpace(testResult[0].Item1))
            {
                Assert.Fail(testResult[0].Item1);
            }

            for (int i = 0; i < 2; i++)
            {
                List<NotificationMessage> testMessage = SqlProceduresInstance.ReceiveSubscription(CommonTestsValues.MainServiceName, 15);
                if (testMessage.Count < 1 || string.IsNullOrWhiteSpace(testMessage[0].MessageString) || testMessage[0].MessageType != NotificationMessageType.Unsubscribed)
                {
                    Assert.Fail(testMessage[0].MessageString);
                }
            }
        }
    }
}
