using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using DBConnection;
using DBConnectionTests.Properties;
using System.Data.SqlClient;
using System.Collections.Generic;
using Microsoft.SqlServer.Server;

namespace DBConnectionTests
{
    [TestClass]
    public class AdminDependencyDBTests
    {
        AdminDependencyDB AdminDependencyDBInstance = new AdminDependencyDB(CommonTestsValues.AdminConnectionString);

        [TestMethod]
        public void AdminInstallOnEmptyDB()
        {
            SetDBState.SetEmptyDB(CommonTestsValues.DefaultTestDBName);
            AdminDependencyDBInstance.AdminInstall(CommonTestsValues.DefaultTestDBName, CommonTestsValues.MainServiceName, CommonTestsValues.LoginPass);

            List<Tuple<string>> testResult = SetDBState.RunFile<Tuple<string>>(Resources.AdminInstall_Test, false,
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginName,
                CommonTestsValues.SchemaName,
                CommonTestsValues.Username,
                CommonTestsValues.QueryName,
                CommonTestsValues.ServiceName,
                CommonTestsValues.SubscribersTableName);

            if (testResult.Count != 1 && !string.IsNullOrWhiteSpace(testResult[0].Item1))
            {
                Assert.Fail(testResult[0].Item1);
            }
        }

        [TestMethod]
        public void AdminInstallOnAdminInstalledDB()
        {
            SetDBState.SetAdminInstalledDB(CommonTestsValues.DefaultTestDBName, CommonTestsValues.MainServiceName, CommonTestsValues.LoginPass);
            AdminDependencyDBInstance.AdminInstall(CommonTestsValues.DefaultTestDBName, CommonTestsValues.MainServiceName, CommonTestsValues.LoginPass);

            List<Tuple<string>> testResult = SetDBState.RunFile<Tuple<string>>(Resources.AdminInstall_Test, false,
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginName,
                CommonTestsValues.SchemaName,
                CommonTestsValues.Username,
                CommonTestsValues.QueryName,
                CommonTestsValues.ServiceName,
                CommonTestsValues.SubscribersTableName);

            if (testResult.Count != 1 && !string.IsNullOrWhiteSpace(testResult[0].Item1))
            {
                Assert.Fail(testResult[0].Item1);
            }
        }

        [TestMethod]
        public void AdminUninstallOnEmptyDB()
        {
            SetDBState.SetEmptyDB(CommonTestsValues.DefaultTestDBName);
            AdminDependencyDBInstance.AdminUnInstall(CommonTestsValues.DefaultTestDBName, CommonTestsValues.MainServiceName);

            List<Tuple<string>> testResult = SetDBState.RunFile<Tuple<string>>(Resources.AdminUnInstall_Test, true,
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginName,
                CommonTestsValues.SchemaName,
                CommonTestsValues.Username,
                CommonTestsValues.QueryName,
                CommonTestsValues.ServiceName,
                CommonTestsValues.SubscribersTableName);

            if (testResult.Count != 1 && !string.IsNullOrWhiteSpace(testResult[0].Item1))
            {
                Assert.Fail(testResult[0].Item1);
            }
        }

        [TestMethod]
        public void AdminUninstallOnAdminInstalledDB()
        {
            SetDBState.SetAdminInstalledDB(CommonTestsValues.DefaultTestDBName, CommonTestsValues.MainServiceName, CommonTestsValues.LoginPass);
            AdminDependencyDBInstance.AdminUnInstall(CommonTestsValues.DefaultTestDBName, CommonTestsValues.MainServiceName);

            List<Tuple<string>> testResult = SetDBState.RunFile<Tuple<string>>(Resources.AdminUnInstall_Test, true,
                CommonTestsValues.DefaultTestDBName,
                CommonTestsValues.MainServiceName,
                CommonTestsValues.LoginName,
                CommonTestsValues.SchemaName,
                CommonTestsValues.Username,
                CommonTestsValues.QueryName,
                CommonTestsValues.ServiceName,
                CommonTestsValues.SubscribersTableName);

            if (testResult.Count != 1 && !string.IsNullOrWhiteSpace(testResult[0].Item1))
            {
                Assert.Fail(testResult[0].Item1);
            }
        }
        
    }
}
