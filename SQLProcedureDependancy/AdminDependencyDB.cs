using SQLProcedureDependency.DBConnection;
using SQLProcedureDependency.Properties;
using System;
using System.Data.SqlClient;
using System.Linq;

namespace SQLProcedureDependency.Admin
{
    /// <summary>
    /// Setups all neccesary Sql objects in DB. For details look to the .sql files. 
    /// This needs to be run olny once by admin. 
    /// Using this class in production is highly discouraged.
    /// </summary>
    public class AdminDependencyDB
    {
        /// <summary>
        /// AccessDB instance used to connect to DB.
        /// </summary>
        public AccessDB AccessDBInstance { get; }

        /// <summary>
        /// Create AdminDependencyDB which allows manipulation on DependencyDB Admin provilages.
        /// </summary>
        /// <param name="connectionString"> Connection string with all admin provilages used to connect to DB. </param>
        /// <param name="sqlQueryTimeout"> Timeout used during execution of queries in seconds. Default: 30s. </param>
        public AdminDependencyDB(string connectionString, int sqlQueryTimeout = 30)
        {
            AccessDBInstance = new AccessDB(connectionString, sqlQueryTimeout);
        }

        /// <summary>
        /// Create AdminDependencyDB which allows manipulation on DependencyDB Admin provilages.
        /// </summary>
        /// <param name="accessDBInstance"> AccessDB class used to connect to DB. </param>
        public AdminDependencyDB(AccessDB accessDBInstance)
        {
            AccessDBInstance = accessDBInstance;
        }

        /// <summary>
        /// Setups all neccesary Sql objects in DB. For details look to the AdminInstall.sql and AdminAddObservedShema.sql files. 
        /// This needs to be run olny once with admin provilages. 
        /// Using this method in production is highly discouraged.
        /// </summary>
        /// <param name="databaseName"> Name of database for which login will be created. </param>
        /// <param name="mainServiceName"> Name of service for which new schema and other objects will be created. </param>
        /// <param name="password"> Password used for new login. If empty no new login will be created. Default: empty string. </param>
        /// <param name="loginName"> Login name from which user will be created. This login must be used during DependencyDB connection. Default: Login with name of mainServiceName will be used to create user. </param>
        /// <param name="observedShema"> Shema name which can be observed by DependencyDB user. Default: no additional provilages will be granted for DependencyDB user. </param>
        public void AdminInstall( string databaseName, string mainServiceName, string password = "", string loginName = "", string observedShema = "")
        {
            TestName(mainServiceName);
            if (string.IsNullOrWhiteSpace(loginName))
            {
                loginName = mainServiceName;
            }

            string instalProcedureText = Resources.P_InstallSubscription.Replace("'","''");
            string receiveProcedureText = Resources.P_ReceiveSubscription.Replace("'", "''");
            string uninstalProcedureText = Resources.P_UninstallSubscription.Replace("'", "''");

            RunFile(Resources.AdminInstall, 
                databaseName,
                mainServiceName, 
                password, 
                instalProcedureText, 
                receiveProcedureText, 
                uninstalProcedureText,
                loginName);

            if(!string.IsNullOrWhiteSpace(observedShema))
                AdminGrantObservedShema(databaseName, mainServiceName, observedShema, loginName);
        }

        /// <summary>
        /// Allows DependencyDB user to observe data from diffrent shema. For details look to the AdminAddObservedShema.sql or AdminRemoveObservedShema.sql file.
        /// </summary>
        /// <param name="databaseName"> Name of database in which provilages will be granted. </param>
        /// <param name="mainServiceName"> Name of DependencyDB service for which provilages will be granted. </param>
        /// <param name="observedShema"> Name of observed shema. </param>
        /// <param name="loginName"> User name for which provilages will be granted. Default: Provilages will be granted for user with mainServiceName name. </param>
        public void AdminGrantObservedShema(string databaseName, string mainServiceName, string observedShema, string loginName = "")
        {
            if (string.IsNullOrWhiteSpace(loginName))
            {
                loginName = mainServiceName;
            }
            // TODO: maybe it should be better to add provilages only to observed procedure and required tables?
            TestName(mainServiceName);
            RunFile(Resources.AdminAddObservedShema, databaseName, mainServiceName, observedShema, loginName);
        }

        /// <summary>
        /// Disables DependencyDB user to observe data from diffrent shema. For details look to the AdminAddObservedShema.sql or AdminRemoveObservedShema.sql file.
        /// </summary>
        /// <param name="databaseName"> Name of database in which provilages will be revoked. </param>
        /// <param name="mainServiceName"> Name of DependencyDB service for which provilages will be revoked. </param>
        /// <param name="observedShema"> Name of observed shema. </param>
        /// <param name="loginName"> User name for which provilages will be revoked. Default: Provilages will be revoked for user with mainServiceName name. </param>
        public void AdminRevokeObservedShema(string databaseName, string mainServiceName, string observedShema, string loginName = "")
        {
            if (string.IsNullOrWhiteSpace(loginName))
            {
                loginName = mainServiceName;
            }
            // TODO: maybe it should be better to add provilages only to observed procedure and required tables?
            TestName(mainServiceName);
            RunFile(Resources.AdminRemoveObservedShema, databaseName, mainServiceName, observedShema, loginName);
        }

        /// <summary>
        /// Removes all objects created by AdminInstall method with exception of deleting AutoCreatedLocal route and disabling brooker setting as other things may depend on it.
        /// </summary>
        /// <param name="databaseName"> Name of database from which DependencyDB objects will be deleted. </param>
        /// <param name="mainServiceName"> Name of service for which schema and other objects will be deleted. </param>
        /// <param name="loginName"> Login name which will be deleted. Default: No Login will be deleted. </param>
        public void AdminUnInstall(string databaseName, string mainServiceName, string loginName = "")
        {
            TestName(mainServiceName);

            RunFile(Resources.AdminUninstall, databaseName, mainServiceName, loginName);
        }

        /// <summary>
        /// Returns text of sql script to create all neccesary Sql objects in DB. For details look to the AdminInstall.sql and AdminAddObservedShema.sql files. 
        /// This needs to be run olny once with admin provilages. 
        /// Using this method in production is highly discouraged.
        /// </summary>
        /// <param name="databaseName"> Name of database for which login will be created. </param>
        /// <param name="mainServiceName"> Name of service for which new schema and other objects will be created. </param>
        /// <param name="password"> Password used for new login. If empty no new login will be created. Default: empty string. </param>
        /// <param name="loginName"> Login name from which user will be created. This login must be used during DependencyDB connection. Default: Login with name of mainServiceName will be used to create user. </param>
        /// <param name="observedShema"> Shema name which can be observed by DependencyDB user. Default: no additional provilages will be granted for DependencyDB user. </param>
        /// <returns> Returns text of sql script to create all neccesary Sql objects in DB. </returns>
        public static string GetAdminInstallScript( string databaseName, string mainServiceName, string password, string loginName = "", string observedShema = "")
        {
            string cmd = "";
            TestName(mainServiceName);
            if (string.IsNullOrWhiteSpace(loginName))
            {
                loginName = mainServiceName;
            }

            string instalProcedureText = Resources.P_InstallSubscription.Replace("'", "''");
            string receiveProcedureText = Resources.P_ReceiveSubscription.Replace("'", "''");
            string uninstalProcedureText = Resources.P_UninstallSubscription.Replace("'", "''");

            cmd = string.Format(Resources.AdminInstall,
                databaseName,
                mainServiceName,
                password,
                instalProcedureText,
                receiveProcedureText,
                uninstalProcedureText,
                loginName) + Environment.NewLine + "GO";
            if (!string.IsNullOrWhiteSpace(observedShema))
                cmd = cmd + Environment.NewLine + string.Format(Resources.AdminAddObservedShema, databaseName, mainServiceName, observedShema, loginName) + Environment.NewLine + "GO";

            return cmd;
        }

        /// <summary>
        /// Returns text of sql script to allow DependencyDB user to observe data from diffrent shema. For details look to the AdminAddObservedShema.sql or AdminRemoveObservedShema.sql file.
        /// </summary>
        /// <param name="databaseName"> Name of database in which provilages will be granted. </param>
        /// <param name="mainServiceName"> Name of DependencyDB service for which provilages will be granted. </param>
        /// <param name="observedShema"> Name of observed shema. </param>
        /// <param name="loginName"> User name for which provilages will be granted. Default: Provilages will be granted for user with mainServiceName name. </param>
        /// <returns> Returns text of sql script to allow DependencyDB user to observe data from diffrent shema. </returns>
        public static string GetAdminGrantObservedShemaScript( string databaseName, string mainServiceName, string observedShema, string loginName = "")
        {
            if (string.IsNullOrWhiteSpace(loginName))
            {
                loginName = mainServiceName;
            }
            TestName(mainServiceName);
            string cmd = string.Format(Resources.AdminAddObservedShema, databaseName, mainServiceName, observedShema, loginName) + Environment.NewLine + "GO";
            return cmd;
        }

        /// <summary>
        /// Returns text of sql script to disable DependencyDB user to observe data from diffrent shema. For details look to the AdminAddObservedShema.sql or AdminRemoveObservedShema.sql file.
        /// </summary>
        /// <param name="databaseName"> Name of database in which provilages will be revoked. </param>
        /// <param name="mainServiceName"> Name of DependencyDB service for which provilages will be revoked. </param>
        /// <param name="observedShema"> Name of observed shema. </param>
        /// <param name="loginName"> User name for which provilages will be revoked. Default: Provilages will be revoked for user with mainServiceName name. </param>
        /// <returns> Returns text of sql script to disable DependencyDB user to observe data from diffrent shema. </returns>
        public static string GetAdminRevokeObservedShemaScript( string databaseName, string mainServiceName, string observedShema, string loginName = "")
        {
            if (string.IsNullOrWhiteSpace(loginName))
            {
                loginName = mainServiceName;
            }
            TestName(mainServiceName);
            string cmd = string.Format(Resources.AdminRemoveObservedShema, databaseName, mainServiceName, observedShema, loginName) + Environment.NewLine + "GO";
            return cmd;
        }

        /// <summary>
        /// Returns text of sql script to remove all objects created by AdminInstall method with exception of deleting AutoCreatedLocal route and disabling brooker setting as other things may depend on it.
        /// </summary>
        /// <param name="databaseName"> Name of database from which DependencyDB objects will be deleted. </param>
        /// <param name="mainServiceName"> Name of service for which schema and other objects will be deleted. </param>
        /// <param name="loginName"> Login name which will be deleted. Default: No Login will be deleted. </param>
        /// <returns> Returns text of sql script to remove all objects created by AdminInstall method. </returns>
        public static string GetAdminUnInstallScript( string databaseName, string mainServiceName, string loginName = "")
        {
            if (string.IsNullOrWhiteSpace(loginName))
            {
                loginName = mainServiceName;
            }
            TestName(mainServiceName);
            string cmd = string.Format(Resources.AdminUninstall, databaseName, mainServiceName, loginName) + Environment.NewLine + "GO";
            return cmd;
        }

        /// <summary>
        /// Tests provided mainServiceName if it is capable to create sql objects with it.
        /// </summary>
        /// <param name="mainServiceName"> Main name for naming Sql objects. </param>
        private static void TestName(string mainServiceName)
        {
            const int maxNameLength = 128 - 46;
            const int minNameLength = 3;
            if (mainServiceName.Length > maxNameLength || mainServiceName.Length < minNameLength)
                throw new ArgumentException("Provided string for mainServiceName is for sure to long. It should be less than " + maxNameLength + " chars and more than " + minNameLength + " chars.");

            const string allowedChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_#$@1234567890";
            foreach (char c in mainServiceName)
            {
                if (!allowedChars.Contains(c))
                {
                    throw new ArgumentException("Provided string for mainServiceName has characters from outside of allowed range. Please check i the name consists only chars from range: \"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz_#$@1234567890\". This is mainly good practise but unexpected results may occur when disabling this test.");
                }
            }
        }

        /// <summary>
        /// Runs provided sql script with provided replacements.
        /// </summary>
        /// <param name="fileContent"> Content of sql script to be run. </param>
        /// <param name="replacements"> Array of string which will be used in string.Format metchod. </param>
        private void RunFile(string fileContent, params string[] replacements)
        {
            string slqCommandText = string.Format(fileContent, replacements);
            SqlCommand sqlCommand = new SqlCommand(slqCommandText);
            AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);
        }
    }
}