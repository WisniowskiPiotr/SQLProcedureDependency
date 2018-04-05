using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using DBConnectionTests.Properties;
using System.Collections.Generic;
using SQLDependency.DBConnection.Admin;

namespace SQLDependency.DBConnectionTests
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

            List<Tuple<string>> testResult = SetDBState.RunFile<Tuple<string>>(
                Resources.AdminInstall_Test,
                SetDBState.AccesType.StandardUser,
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

            List<Tuple<string>> testResult = SetDBState.RunFile<Tuple<string>>(
                Resources.AdminInstall_Test,
                SetDBState.AccesType.StandardUser,
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

            List<Tuple<string>> testResult = SetDBState.RunFile<Tuple<string>>(
                Resources.AdminUnInstall_Test, 
                SetDBState.AccesType.Admin,
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

            List<Tuple<string>> testResult = SetDBState.RunFile<Tuple<string>>(
                Resources.AdminUnInstall_Test, 
                SetDBState.AccesType.Admin,
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
