using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DBConnectionTests
{
    static class CommonTestsValues
    {
        public static string DefaultTestDBName = "DependencyDBTestDB";
        public static string MainServiceName = "DependencyDB";
        public static string LoginName = MainServiceName;
        public static string LoginPass = "testPass";
        public static string SchemaName = MainServiceName;
        public static string Username = MainServiceName;
        public static string SubscribedProcedureSchema = "dbo";
        public static string SubscribersTableName = "TBL_SubscribersTable";
        public static string QueryName = "Q_"+ MainServiceName;
        public static string ServiceName = "S_" + MainServiceName;
        public static string AdminMasterConnectionString = "Data Source=(localdb)\\MSSQLLocalDB;Initial Catalog=MASTER;Integrated Security=True;Connect Timeout=30;Encrypt=False;TrustServerCertificate=True;ApplicationIntent=ReadWrite;MultiSubnetFailover=False";
        public static string AdminConnectionString = "Data Source=(localdb)\\MSSQLLocalDB;Initial Catalog=" + DefaultTestDBName + ";Integrated Security=True;Connect Timeout=30;Encrypt=False;TrustServerCertificate=True;ApplicationIntent=ReadWrite;MultiSubnetFailover=False";
        public static string ServiceConnectionString = "Data Source=(localdb)\\MSSQLLocalDB;Initial Catalog=" + DefaultTestDBName + ";UID="+ LoginName + ";PWD="+ LoginPass + ";Connect Timeout=30;Encrypt=False;ApplicationIntent=ReadWrite;MultiSubnetFailover=False";
        public static string FirstSunscriberName = "subscriber1";
        public static string SecondSunscriberName = "subscriber2";
        public static string AnySunscriberName = "subscriber%";
    }
}
