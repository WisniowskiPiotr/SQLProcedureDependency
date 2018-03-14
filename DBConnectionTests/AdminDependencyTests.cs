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
            AdminDependencyDB obj = new AdminDependencyDB(CommonTestsValues.AdminConnectionString);
            obj.AdminInstall("TestPassword");
        }
    }
}
