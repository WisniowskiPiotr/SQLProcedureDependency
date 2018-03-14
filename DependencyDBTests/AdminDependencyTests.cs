using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using DBConnection;

namespace DBConnectionTests
{
    [TestClass]
    public class AdminDependencyTests
    {
        [TestMethod]
        public void AdminInstall()
        {
            AdminDependencyDB adminDependencyDB = new AdminDependencyDB(CommonTestsValues.AdminConnectionString);
            adminDependencyDB.AdminInstall("testpass");
        }
    }
}
