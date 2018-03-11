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
        private AccessDB AccessDBInstance;

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
        public void AdminInstall( string password, string observedShema="dbo")
        {
            string slqCommandText = string.Format(
                File.ReadAllText(Path.Combine("DependencyDB", "AdminInstall.sql")),
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
        public void AdminInstallObservedShema(string observedShema, bool allow = true)
        {
            string filename;
            if (allow)
                filename = "AdminAddObservedShema.sql";
            else
                filename = "AdminRemoveObservedShema.sql";
            string slqCommandText = string.Format(
                File.ReadAllText(Path.Combine("DependencyDB", filename))
                , observedShema);
            SqlCommand sqlCommand = new SqlCommand(slqCommandText);
            AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);
        }

        /// <summary>
        /// Removes all objects created by AdminInstall method with exception of AutoCreatedLocal route and disabling brooker setting as other things may depend on it.
        /// </summary>
        public void AdminUnInstall()
        {
            string slqCommandText = File.ReadAllText(Path.Combine("DependencyDB", "AdminUnInstall.sql"));
            SqlCommand sqlCommand = new SqlCommand(slqCommandText);
            AccessDBInstance.SQLRunNonQueryProcedure(sqlCommand);
        }
    }
}