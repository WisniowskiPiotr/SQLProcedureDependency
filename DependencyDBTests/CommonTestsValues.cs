using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DBConnectionTests
{
    static class CommonTestsValues
    {
        public static string DefaultDBName = "DependencyDBTests";
        public static string MainServiceName = "DependencyDB";
        public static string LoginName = "L_"+ MainServiceName;
        public static string LoginPass = "testPass";
        public static string AdminConnectionString = "Data Source=(localdb)\\MSSQLLocalDB;Initial Catalog=DependencyDBTests;Integrated Security=True;Connect Timeout=30;Encrypt=False;TrustServerCertificate=True;ApplicationIntent=ReadWrite;MultiSubnetFailover=False";
        public static string ServiceConnectionString = "Data Source=(localdb)\\MSSQLLocalDB;Initial Catalog=DependencyDBTests;UID="+ LoginName + ";PWD="+ LoginPass + ";Connect Timeout=30;Encrypt=False;ApplicationIntent=ReadWrite;MultiSubnetFailover=False";
        
    }
}
