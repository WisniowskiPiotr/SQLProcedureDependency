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
        private string ProcedureNameInstall;
        private string ProcedureNameReceiveNotification;
        private string ProcedureNameUninstall;
        // max object name length is 128 ex. 'MemSourceAPI' (appName) 
        public SqlProcedures(string appName, string connectionString, int queryTimeout=30)
        {
            AppName = appName;
            AccessDBInstance = new AccessDB(connectionString, queryTimeout);
            SetProcedureNames(appName);
        }
        public SqlProcedures(string appName, AccessDB accessDB)
        {
            AppName = appName;
            AccessDBInstance = accessDB;
            SetProcedureNames(appName);
        }

        private void SetProcedureNames(string appName)
        {
            ProcedureNameInstall = "[" + appName + "].[P_InstallSubscription]";
            ProcedureNameReceiveNotification = "[" + appName + "].[P_ReceiveSubscription]";
            ProcedureNameUninstall = "[" + appName + "].[P_UninstallSubscription]";
        }

        public void InstallSubscription(Subscription subscription)
        {
            SqlCommand command = new SqlCommand(ProcedureNameInstall);
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_SubscriberString", SqlDbType.NVarChar, subscription.SubscriberString));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_SubscriptionHash", SqlDbType.Int, subscription.GetHashCode()));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_ProcedureSchemaName", SqlDbType.NVarChar, subscription.ProcedureSchemaName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_ProcedureName", SqlDbType.NVarChar, subscription.ProcedureName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("TBL_ProcedureParameters", SqlDbType.Structured, SqlParameterCollectionToDataTable(subscription.ProcedureParameters)));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_NotificationValidFor", SqlDbType.Int, subscription.ValidFor));
            AccessDBInstance.SQLRunNonQueryProcedure(command);
        }

        public List<EventMessage> ReceiveSubscription(int receiveTimeout= 150000)
        {
            SqlCommand command = new SqlCommand(ProcedureNameReceiveNotification);
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_ReceiveTimeout", SqlDbType.Int, receiveTimeout));
            List<EventMessage> result = AccessDBInstance.SQLRunQueryProcedure<EventMessage>(command);
            return result;
        }
        
        public void SqlUnInstal(Subscription subscription)
        {
            SqlCommand command = new SqlCommand(ProcedureNameUninstall);
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_SubscriberString", SqlDbType.NVarChar, subscription.SubscriberString));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_SubscriptionHash", SqlDbType.Int, subscription.GetHashCode()));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_ProcedureSchemaName", SqlDbType.NVarChar, subscription.ProcedureSchemaName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_ProcedureName", SqlDbType.NVarChar, subscription.ProcedureName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("TBL_ProcedureParameters", SqlDbType.Structured, SqlParameterCollectionToDataTable(subscription.ProcedureParameters)));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_NotificationValidFor", SqlDbType.Int, subscription.ValidFor));
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