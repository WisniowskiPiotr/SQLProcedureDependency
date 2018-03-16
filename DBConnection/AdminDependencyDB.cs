using DBConnection.Properties;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Linq;

namespace DBConnection
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
        public AdminDependencyDB(string connectionString)
        {
            AccessDBInstance = new AccessDB(connectionString);
        }
        
        /// <summary>
        /// Setups all neccesary Sql objects in DB. For details look to the AdminInstall.sql and AdminAddObservedShema.sql files. 
        /// This needs to be run olny once with admin provilages. 
        /// Using this method in production is highly discouraged.
        /// </summary>
        /// <param name="password"> Password used for newly created DependencyDB login. </param>
        /// <param name="observedShema"> Shema name which can be observed by DependencyDB. </param>
        public void AdminInstall( string password, string mainServiceName = "DependencyDB", string observedShema="dbo")
        {
            TestName(mainServiceName);
            string slqCommandText;
            SqlCommand sqlCommand;

            slqCommandText = string.Format(
                Resources.AdminInstall,
                mainServiceName,
                password);
            sqlCommand = new SqlCommand(slqCommandText);
            AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);

            AdminInstallObservedShema(observedShema);

            slqCommandText = string.Format(
                Resources.DependencyDB_InstallSubscription,
                mainServiceName,
                "Service" + mainServiceName);
            sqlCommand = new SqlCommand(slqCommandText);
            AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);

            slqCommandText = string.Format(
                Resources.DependencyDB_ReceiveSubscription,
                mainServiceName,
                "Service" + mainServiceName);
            sqlCommand = new SqlCommand(slqCommandText);
            AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);

            slqCommandText = string.Format(
                Resources.DependencyDB_UninstallSubscription,
                mainServiceName,
                "Service" + mainServiceName);
            sqlCommand = new SqlCommand(slqCommandText);
            AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);
        }

        /// <summary>
        /// Allows or denies DependencyDB to observe data from diffrent shema. For details look to the AdminAddObservedShema.sql or AdminRemoveObservedShema.sql file.
        /// </summary>
        /// <param name="observedShema"> Name of observed shema. </param>
        /// <param name="allow"> If true grants provilages. Othervise revoke provilages. </param>
        public void AdminInstallObservedShema(string observedShema, string mainServiceName = "DependencyDB", bool allow = true)
        {
            // TODO: maybe it should be better to add provilages only to observed procedure and required tables?
            TestName(mainServiceName);
            string sqlCommandText;
            if (allow)
                sqlCommandText = Resources.AdminAddObservedShema;
            else
                sqlCommandText = Resources.AdminRemoveObservedShema;
            string slqCommandText = string.Format(
                sqlCommandText,
                mainServiceName,
                observedShema);
            SqlCommand sqlCommand = new SqlCommand(slqCommandText);
            AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);
        }

        /// <summary>
        /// Removes all objects created by AdminInstall method and DependencyDB with exception of AutoCreatedLocal route and disabling brooker setting as other things may depend on it.
        /// </summary>
        public void AdminUnInstall(string mainServiceName)
        {
            TestName(mainServiceName);
            string slqCommandText = string.Format(
                Resources.AdminUnInstall,
                mainServiceName
                );
            SqlCommand sqlCommand = new SqlCommand(slqCommandText);
            AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);
        }

        private void TestName(string mainServiceName)
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
    }
}