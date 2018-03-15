using DBConnection.Properties;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;

namespace DBConnection
{
    /// <summary>
    /// Setups all neccesary Sql objects in DB. For details look to the .sql files. 
    /// This needs to be run olny once by admin. 
    /// Using this in production is highly discouraged.
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
            string slqCommandText = string.Format(
                Resources.AdminInstall,
                mainServiceName,
                password);
            SqlCommand sqlCommand = new SqlCommand(slqCommandText);
            AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);

            AdminInstallObservedShema(observedShema);
        }

        /// <summary>
        /// Allows or denies DependencyDB to observe data from diffrent shema. For details look to the AdminAddObservedShema.sql or AdminRemoveObservedShema.sql file.
        /// </summary>
        /// <param name="observedShema"> Name of observed shema. </param>
        /// <param name="allow"> If true grants provilages. Othervise revoke provilages. </param>
        public void AdminInstallObservedShema(string observedShema, string mainServiceName = "DependencyDB", bool allow = true)
        {
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
        public void AdminUnInstall()
        {
            DependencyDB.StopListener(AccessDBInstance.ConnectionString);
            //DependencyDB.UnSubscribeAll(AccessDBInstance.ConnectionString);
            string slqCommandText = Resources.AdminUnInstall;
            SqlCommand sqlCommand = new SqlCommand(slqCommandText);
            AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);
        }
    }
}