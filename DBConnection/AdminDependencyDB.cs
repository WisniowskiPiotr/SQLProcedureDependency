using SQLDependency.DBConnection.Properties;
using System;
using System.Data.SqlClient;
using System.IO;
using System.Linq;

namespace SQLDependency.DBConnection.Admin
{
    /// <summary>
    /// Setups all neccesary Sql objects in DB. For details look to the .sql files. 
    /// This needs to be run olny once by admin. 
    /// Using this class in production is highly discouraged.
    /// </summary>
    public class AdminDependencyDB
    {
        public AccessDB AccessDBInstance { get; }

        /// <summary>
        /// Create AdminDependencyDB which allows manipulation on DependencyDB Admin provilages.
        /// </summary>
        /// <param name="connectionString"> Connection string with admin provilages used to connect to DB. </param>
        public AdminDependencyDB(string connectionString, int sqlQueryTimeout = 30)
        {
            AccessDBInstance = new AccessDB(connectionString, sqlQueryTimeout);
        }
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
        /// <param name="password"> Password used for newly created DependencyDB login. </param>
        /// <param name="mainServiceName"> Main name for naming Sql objects. </param>
        /// <param name="observedShema"> Shema name which can be observed by DependencyDB. </param>
        public void AdminInstall( string databaseName, string mainServiceName, string password, string observedShema = "dbo")
        {
            TestName(mainServiceName);

            string instalProcedureText = Resources.P_InstallSubscription.Replace("'","''");
            string receiveProcedureText = Resources.P_ReceiveSubscription.Replace("'", "''");
            string uninstalProcedureText = Resources.P_UninstallSubscription.Replace("'", "''");

            RunFile(Resources.AdminInstall, 
                databaseName,
                mainServiceName, 
                password, 
                instalProcedureText, 
                receiveProcedureText, 
                uninstalProcedureText);

            if(!string.IsNullOrWhiteSpace(observedShema))
                AdminGrantObservedShema(databaseName, mainServiceName, observedShema);
        }

        public static void WriteAdminInstallScript(string path, string databaseName, string mainServiceName, string password, string observedShema = "dbo")
        {
            string cmd = "";
            TestName(mainServiceName);

            string instalProcedureText = Resources.P_InstallSubscription.Replace("'", "''");
            string receiveProcedureText = Resources.P_ReceiveSubscription.Replace("'", "''");
            string uninstalProcedureText = Resources.P_UninstallSubscription.Replace("'", "''");

            cmd=string.Format(Resources.AdminInstall,
                databaseName,
                mainServiceName,
                password,
                instalProcedureText,
                receiveProcedureText,
                uninstalProcedureText) + Environment.NewLine + "GO;";
            if (!string.IsNullOrWhiteSpace(observedShema))
                cmd = cmd + Environment.NewLine + string.Format(Resources.AdminAddObservedShema, databaseName, mainServiceName, observedShema) + Environment.NewLine + "GO;";

            File.WriteAllText(path, cmd);
        }

        /// <summary>
        /// Allows or denies DependencyDB to observe data from diffrent shema. For details look to the AdminAddObservedShema.sql or AdminRemoveObservedShema.sql file.
        /// </summary>
        /// <param name="observedShema"> Name of observed shema. </param>
        /// <param name="mainServiceName"> Main name for naming Sql objects. </param>
        /// <param name="allow"> If true grants provilages. Othervise revoke provilages. </param>
        public void AdminGrantObservedShema(string databaseName, string mainServiceName, string observedShema)
        {
            // TODO: maybe it should be better to add provilages only to observed procedure and required tables?
            TestName(mainServiceName);
            RunFile(Resources.AdminAddObservedShema, databaseName, mainServiceName, observedShema);
        }
        public static void GetAdminGrantObservedShemaScript(string path, string databaseName, string mainServiceName, string observedShema)
        {
            TestName(mainServiceName);
            string cmd = string.Format(Resources.AdminAddObservedShema, databaseName, mainServiceName, observedShema) + Environment.NewLine + "GO;";
            File.WriteAllText(path, cmd);
        }
        public void AdminRevokeObservedShema(string databaseName, string mainServiceName, string observedShema)
        {
            // TODO: maybe it should be better to add provilages only to observed procedure and required tables?
            TestName(mainServiceName);
            RunFile(Resources.AdminRemoveObservedShema, databaseName, mainServiceName, observedShema);
        }
        public static void GetAdminRevokeObservedShemaScript(string path, string databaseName, string mainServiceName, string observedShema)
        {
            TestName(mainServiceName);
            string cmd = string.Format(Resources.AdminRemoveObservedShema, databaseName, mainServiceName, observedShema) + Environment.NewLine + "GO;";
            File.WriteAllText(path, cmd);
        }

        /// <summary>
        /// Removes all objects created by AdminInstall method and DependencyDB with exception of AutoCreatedLocal route and disabling brooker setting as other things may depend on it.
        /// </summary>
        /// <param name="mainServiceName"> Main name for naming Sql objects. </param>
        public void AdminUnInstall(string databaseName, string mainServiceName)
        {
            TestName(mainServiceName);

            RunFile(Resources.AdminUninstall, databaseName, mainServiceName);
        }
        public static void GetAdminUnInstallScript(string path, string databaseName, string mainServiceName)
        {
            TestName(mainServiceName);
            string cmd = string.Format(Resources.AdminUninstall, databaseName, mainServiceName) + Environment.NewLine + "GO;";
            File.WriteAllText(path, cmd);
        }

        /// <summary>
        /// Tests privided mainServiceName if it is capable to create sql objects with it.
        /// </summary>
        /// <param name="mainServiceName"> Main name for naming Sql objects. </param>
        private static void TestName(string mainServiceName)
        {
            const int maxNameLength = 128 - 46;
            const int minNameLength = 4;
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

        private void RunFile(string fileContent, params string[] replacements)
        {
            string slqCommandText = string.Format(fileContent, replacements);
            SqlCommand sqlCommand = new SqlCommand(slqCommandText);
            AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);
        }
    }
}