using DBConnection;
using DBConnectionTests.Properties;
using SQLDependency.DBConnection;
using SQLDependency.DBConnection.Admin;
using System.Collections.Generic;
using System.Data.SqlClient;

namespace SQLDependency.DBConnectionTests
{
    static class SetDBState
    {
        private static AccessDB serviceAccessDB = new AccessDB(CommonTestsValues.ServiceConnectionString);
        private static AccessDB serviceAccessDBAdmin = new AccessDB(CommonTestsValues.AdminConnectionString);
        private static AccessDB serviceAccessDBAdminMaster = new AccessDB(CommonTestsValues.AdminMasterConnectionString);

        public enum AccesType {
            StandardUser,
            Admin,
            AdminAtMasterDB
        }

        public static void SetEmptyDB(string DBName)
        {
            RunFile(Resources.SetEmptyDB, AccesType.AdminAtMasterDB, DBName);
        }

        public static void SetAdminInstalledDB(string DBName, string mainServiceName, string password)
        {
            SetEmptyDB(DBName);
            AdminDependencyDB adminDependencyDB = new AdminDependencyDB(serviceAccessDBAdmin);
            adminDependencyDB.AdminInstall(DBName, mainServiceName, password);
        }

        public static void SetSingleSubscriptionInstalledDB(string DBName, string mainServiceName, string password, string subscriber, string procedureName, SqlParameterCollection testProcedureParameters)
        {
            SetAdminInstalledDB(DBName, mainServiceName, password);
            Subscription subscription = new Subscription(
                mainServiceName, 
                subscriber, 
                CommonTestsValues.SubscribedProcedureSchema, 
                procedureName, 
                testProcedureParameters);
            SqlProcedures sqlProcedures = new SqlProcedures(serviceAccessDB);
            sqlProcedures.InstallSubscription(subscription);
        }

        public static void SetTwoSubscriptionInstalledDB(string DBName, string mainServiceName, string password, string firstSubscriber, string firstProcedureName, SqlParameterCollection firstTestProcedureParameters, string secondSubscriber, string secondProcedureName, SqlParameterCollection secondTestProcedureParameters)
        {
            SetSingleSubscriptionInstalledDB( 
                DBName, 
                mainServiceName,  
                password,  
                firstSubscriber,
                firstProcedureName,
                firstTestProcedureParameters);
            Subscription subscription = new Subscription(
                mainServiceName, secondSubscriber, 
                CommonTestsValues.SubscribedProcedureSchema,
                secondProcedureName, 
                secondTestProcedureParameters);
            SqlProcedures sqlProcedures = new SqlProcedures(serviceAccessDB);
            sqlProcedures.InstallSubscription(subscription);
        }

        public static void RunFile(string fileContent, AccesType asAdmin = AccesType.StandardUser, params string[] replacements)
        {
            string slqCommandText = string.Format(fileContent, replacements);
            SqlCommand sqlCommand = new SqlCommand(slqCommandText);
            switch (asAdmin)
            {
                case AccesType.Admin:
                    serviceAccessDBAdmin.SQLRunNonQueryProcedure(sqlCommand);
                    break;
                case AccesType.AdminAtMasterDB:
                    serviceAccessDBAdminMaster.SQLRunNonQueryProcedure(sqlCommand);
                    break;
                default:
                    serviceAccessDB.SQLRunNonQueryProcedure(sqlCommand);
                    break;
            }
        }

        public static List<T> RunFile<T>(string fileContent, AccesType asAdmin = AccesType.StandardUser, params string[] replacements)
        {
            string slqCommandText = string.Format(fileContent, replacements);
            SqlCommand sqlCommand = new SqlCommand(slqCommandText);
            switch (asAdmin)
            {
                case AccesType.Admin:
                    return serviceAccessDBAdmin.SQLRunQueryProcedure<T>(sqlCommand);
                case AccesType.AdminAtMasterDB:
                    return serviceAccessDBAdminMaster.SQLRunQueryProcedure<T>(sqlCommand);
                default:
                    return serviceAccessDB.SQLRunQueryProcedure<T>(sqlCommand);
            }
        }

    }
}
