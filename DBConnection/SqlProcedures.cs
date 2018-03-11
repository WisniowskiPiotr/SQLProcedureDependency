﻿using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;

namespace DBConnection
{
    public class SqlProcedures
    {
        private AccessDB AccessDBInstance;
        public SqlProcedures(string connectionString, int queryTimeout=30)
        {
            AccessDBInstance = new AccessDB(connectionString, queryTimeout);
        }
        public SqlProcedures(AccessDB accessDB)
        {
            AccessDBInstance = accessDB;
        }

        /// <summary>
        /// Name for read notification procedure.
        /// </summary>
        private static readonly string _ListenerReceiveNotification = "ListenerReceiveNotification";
        public List<EventMessage> GetEvent()
        {
            SqlCommand command = new SqlCommand(_ListenerReceiveNotification);
            command.Parameters.Add(AccessDB.SqlParameter("AppName", SqlDbType.NVarChar, AppName));
            command.Parameters.Add(AccessDB.SqlParameter("Lifetime", SqlDbType.Int, GetSqlNotificationTimeout()));
            List<EventMessage> result = AccessDBInstance.SQLRunQueryProcedure<EventMessage>(command);

            return result;
        }














        /// <summary>
        /// Name for casual uninstal sql procedure.
        /// </summary>
        private static readonly string _ListenerUninstall = "ListenerUninstall";
        
        /// <summary>
        /// Name for instal sql procedure.
        /// </summary>
        private static readonly string _ListenerInstall = "ListenerInstall";
        /// <summary>
        /// Name for rude uninstal sql procedure. Procedure should be used only when running new instance of application to delete existing data.
        /// </summary>
        private static readonly string _ListenerRudeUninstall = "ListenerRudeUninstall";
        /// <summary>
        /// App name used as prefix for all created sql objects.
        /// </summary>
        public static readonly string AppName = ConfigurationManager.AppSettings["DependencyDB_AppName"];
        /// <summary>
        /// Connection string used for Listener. Additional provilages are required. For details see: DBConnection/SqlRunOnce/NotificationBroker.sql
        /// </summary>
        public static string ConnectionString = ConfigurationManager.ConnectionStrings["ListenerConnectionString"].ConnectionString;
        

        #region helper methods
        /// <summary>
        /// Returns currently set notification timeout from DependencySql in seconds.
        /// </summary>
        /// <returns> Returns currently set notification timeout from DependencySql in seconds. </returns>
        public static int GetSqlNotificationTimeout()
        {
            int defaultnotificationTimeout = 60 * 60 * 24;
            return Helpers.ReadConfInt(defaultnotificationTimeout, "DependencyDB_NotificationTimeout");
        }
        /// <summary>
        /// Converts SqlParameterCollection to DataTable to be passed to db as SpParametersType.
        /// </summary>
        /// <param name="comandParameters"> SqlParameterCollection to be converted. </param>
        /// <returns> DataTable containing all neccesary comandParameters informations. </returns>
        private static DataTable SqlParameterCollectionToDataTable(SqlParameterCollection comandParameters)
        {
            DataTable procedureParameters = new DataTable();
            procedureParameters.Columns.Add("PName", Type.GetType("System.String"));
            procedureParameters.Columns.Add("PType", Type.GetType("System.String"));
            procedureParameters.Columns.Add("PValue", Type.GetType("System.String"));

            foreach (SqlParameter sqlParam in comandParameters)
            {
                string paramName = sqlParam.ParameterName;
                string paramType = sqlParam.SqlDbType.GetName();
                string paramValue = sqlParam.Value.ToString();
                procedureParameters.Rows.Add(paramName, paramType, paramValue);
            }

            return procedureParameters;
        }
        #endregion

        #region sql
        /// <summary>
        /// Runs _ListenerInstall procedure for creating all neccesary sql objects.
        /// </summary>
        /// <param name="procedureName"> Notification procedure name. </param>
        /// <param name="procedureParameters"> SqlParameterCollection containing all necesary SqlParameters for Notification procedure. </param>
        public static void SqlInstal(string procedureName, SqlParameterCollection procedureparameters)
        {
            SqlCommand command = new SqlCommand(_ListenerInstall);
            command.Parameters.Add(AccessDB.SqlParameter("ListenerAppName", SqlDbType.NVarChar, AppName));
            command.Parameters.Add(AccessDB.SqlParameter("ListenerProcedureName", SqlDbType.NVarChar, procedureName));
            command.Parameters.Add(AccessDB.SqlParameter("ListenerSParameters", SqlDbType.Structured, SqlParameterCollectionToDataTable(procedureparameters)));
            command.Parameters.Add(AccessDB.SqlParameter("ListenerLifetime", SqlDbType.NVarChar, GetSqlNotificationTimeout()));
            AccessDB.SQLRunNonQueryProcedure(command, ConnectionString);
        }
        /// <summary>
        /// Runs _ListenerUninstall procedure for deleting all sql objects.
        /// </summary>
        /// <param name="procedureName"> Notification procedure name. </param>
        /// <param name="procedureParameters"> SqlParameterCollection containing all necesary SqlParameters for Notification procedure. </param>
        public static void SqlUninstal(string procedureName, SqlParameterCollection procedureparameters)
        {
            SqlCommand command = new SqlCommand(_ListenerUninstall);
            command.Parameters.Add(AccessDB.SqlParameter("ListenerAppName", SqlDbType.NVarChar, AppName));
            command.Parameters.Add(AccessDB.SqlParameter("ListenerProcedureName", SqlDbType.NVarChar, procedureName));
            command.Parameters.Add(AccessDB.SqlParameter("ListenerSParameters", SqlDbType.Structured, SqlParameterCollectionToDataTable(procedureparameters)));
            AccessDB.SQLRunNonQueryProcedure(command, ConnectionString);
        }
        /// <summary>
        /// Runs _ListenerRudeUninstall procedure for deleting all sql objects.
        /// </summary>
        public static void SqlRudeUninstal()
        {
            SqlCommand command = new SqlCommand(_ListenerRudeUninstall);
            command.Parameters.Add(AccessDB.SqlParameter("ListenerAppName", SqlDbType.NVarChar, AppName));
            AccessDB.SQLRunNonQueryProcedure(command, ConnectionString);
        }
        
        #endregion
    }
}