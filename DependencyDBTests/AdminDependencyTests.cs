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
    public class AdminDependencyTests
    {
        AdminDependencyDB AdminDependencyDBInstance = new AdminDependencyDB(CommonTestsValues.AdminConnectionString);

        [TestMethod]
        public void AdminInstall()
        {
            string mainServiceName = "DependencyDB";
            string slqCommandText;
            SqlCommand sqlCommand;
            // CleanUp DB
            slqCommandText = string.Format(
                Resources.AdminInstall_Cleanup,
                mainServiceName
                );
            sqlCommand = new SqlCommand(slqCommandText);
            AdminDependencyDBInstance.AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);

            // Try install
            AdminDependencyDBInstance.AdminInstall("testPass", mainServiceName);

            // Test install
            slqCommandText = string.Format(
                Resources.AdminInstall_Test,
                mainServiceName
                );
            sqlCommand = new SqlCommand(slqCommandText);
            List<Tuple<int>> testResult = AdminDependencyDBInstance.AccessDBInstance.SQLRunQueryProcedure<Tuple<int>>(sqlCommand);
            if (testResult.Count != 1 && testResult[0].Item1 != 1)
            {
                Assert.Fail();
            }

            // try instal with existing objects
            AdminDependencyDBInstance.AdminInstall("testPass", mainServiceName);

            // Test install2
            slqCommandText = string.Format(
                Resources.AdminInstall_Test,
                mainServiceName
                );
            sqlCommand = new SqlCommand(slqCommandText);
            List<Tuple<int>> testResult2 = AdminDependencyDBInstance.AccessDBInstance.SQLRunQueryProcedure<Tuple<int>>(sqlCommand);
            if (testResult2.Count != 1 && testResult2[0].Item1 != 1)
            {
                Assert.Fail();
            }
        }

        [TestMethod]
        public void AdminInstallObservedShema()
        {
            string mainServiceName = "DependencyDB";
            string slqCommandText;
            SqlCommand sqlCommand;

            // Try
            AdminDependencyDBInstance.AdminInstallObservedShema("dbo", mainServiceName,false);

            // Test
            slqCommandText = string.Format(
                Resources.AdminInstall_Test,
                mainServiceName
                );
            sqlCommand = new SqlCommand(slqCommandText);
            List<Tuple<int>> testResult = AdminDependencyDBInstance.AccessDBInstance.SQLRunQueryProcedure<Tuple<int>>(sqlCommand);
            if (testResult.Count != 1 && testResult[0].Item1 != 1)
            {
                Assert.Fail();
            }

            // try instal with existing objects
            AdminDependencyDBInstance.AdminInstall("testPass", mainServiceName);

            // Test install2
            slqCommandText = string.Format(
                Resources.AdminInstall_Test,
                mainServiceName
                );
            sqlCommand = new SqlCommand(slqCommandText);
            List<Tuple<int>> testResult2 = AdminDependencyDBInstance.AccessDBInstance.SQLRunQueryProcedure<Tuple<int>>(sqlCommand);
            if (testResult2.Count != 1 && testResult2[0].Item1 != 1)
            {
                Assert.Fail();
            }
        }
    }
}
