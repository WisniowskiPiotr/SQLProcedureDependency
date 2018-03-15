using Microsoft.SqlServer.Server;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace DBConnection
{
    public class SqlProcedures
    {
        public AccessDB AccessDBInstance { get; }
        public string AppName { get; }
        // max object name length is 128 ex. 'MemSourceAPI' (appName) 
        public SqlProcedures(string appName, string connectionString, int queryTimeout=30)
        {
            AppName = appName;
            AccessDBInstance = new AccessDB(connectionString, queryTimeout);
        }
        public SqlProcedures(string appName, AccessDB accessDB)
        {
            AppName = appName;
            AccessDBInstance = accessDB;
        }

        private static readonly string ProcedureNameReceiveNotification = "[DependencyDB].[ReceiveNotification]";
        private static readonly string ProcedureNameUninstallAll = "[DependencyDB].[UninstallAll]";
        private static readonly string ProcedureNameInstall = "[DependencyDB].[Install]";
        private static readonly string ProcedureNameUninstall = "[DependencyDB].[Uninstall]";

        public List<EventMessage> ReceiveNotification(int receiveTimeout=0)
        {
            SqlCommand command = new SqlCommand(ProcedureNameReceiveNotification);
            command.Parameters.Add(AccessDB.CreateSqlParameter("AppName", SqlDbType.NVarChar, AppName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("ReceiveTimeout", SqlDbType.Int, receiveTimeout));
            List<EventMessage> result = AccessDBInstance.SQLRunQueryProcedure<EventMessage>(command);
            return result;
        }

        public void SqlUninstalAll(string connectionString, int queryTimeout = 30)
        {
            SqlCommand command = new SqlCommand(ProcedureNameUninstallAll);
            command.Parameters.Add(AccessDB.CreateSqlParameter("AppName", SqlDbType.NVarChar, AppName));
            new AccessDB(connectionString, queryTimeout).SQLRunNonQueryProcedure(command);
        }

        public void SqlInstal(Subscription subscription)
        {
            SqlCommand command = new SqlCommand(ProcedureNameReceiveNotification);
            command.Parameters.Add(AccessDB.CreateSqlParameter("AppName", SqlDbType.NVarChar, AppName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("SubscriberString", SqlDbType.NVarChar, subscription.SubscriberString));
            command.Parameters.Add(AccessDB.CreateSqlParameter("ProcedureSchemaName", SqlDbType.NVarChar, subscription.ProcedureSchemaName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("ProcedureName", SqlDbType.NVarChar, subscription.ProcedureName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("ProcedureParameters", SqlDbType.Structured, SqlParameterCollectionToDataTable(subscription.ProcedureParameters)));
            command.Parameters.Add(AccessDB.CreateSqlParameter("ValidFor", SqlDbType.Int, subscription.ValidFor));
            AccessDBInstance.SQLRunNonQueryProcedure(command);
        }

        public void SqlUnInstal(Subscription subscription)
        {
            SqlCommand command = new SqlCommand(ProcedureNameReceiveNotification);
            command.Parameters.Add(AccessDB.CreateSqlParameter("AppName", SqlDbType.NVarChar, AppName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("SubscriberString", SqlDbType.NVarChar, subscription.SubscriberString));
            command.Parameters.Add(AccessDB.CreateSqlParameter("ProcedureSchemaName", SqlDbType.NVarChar, subscription.ProcedureSchemaName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("ProcedureName", SqlDbType.NVarChar, subscription.ProcedureName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("ProcedureParameters", SqlDbType.Structured, SqlParameterCollectionToDataTable(subscription.ProcedureParameters)));
            AccessDBInstance.SQLRunNonQueryProcedure(command);
        }

        /// <summary>
        /// Converts SqlParameterCollection to DataTable to be passed to db as SpParametersType.
        /// </summary>
        /// <param name="comandParameters"> SqlParameterCollection to be converted. </param>
        /// <returns> DataTable containing all neccesary comandParameters informations. </returns>
        private static List<SqlDataRecord> SqlParameterCollectionToDataTable(SqlParameterCollection comandParameters)
        {
            List<SqlDataRecord> procedureParameters = new List<SqlDataRecord>();
            SqlMetaData pName = new SqlMetaData("PName", SqlDbType.NVarChar);
            SqlMetaData pType = new SqlMetaData("PType", SqlDbType.NVarChar);
            SqlMetaData pValue = new SqlMetaData("PValue", SqlDbType.NVarChar);

            foreach (SqlParameter sqlParam in comandParameters)
            {
                string paramName = sqlParam.ParameterName;
                string paramType = sqlParam.SqlDbType.GetName();
                string paramValue = sqlParam.Value.ToString();
                SqlDataRecord sqlDataRecord = new SqlDataRecord(new[] { pName, pType, pValue });
                sqlDataRecord.SetString(0, paramName);
                sqlDataRecord.SetString(1, paramType);
                sqlDataRecord.SetString(2, paramValue);
                procedureParameters.Add(sqlDataRecord);
            }

            return procedureParameters;
        }
    }
}