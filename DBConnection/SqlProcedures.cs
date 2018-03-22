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
        private string ProcedureNameInstall = "[P_InstallSubscription]";
        private string ProcedureNameReceiveNotification = "[P_ReceiveSubscription]";
        private string ProcedureNameUninstall = "[P_UninstallSubscription]";

        public SqlProcedures( string connectionString, int queryTimeout=30)
        {
            AccessDBInstance = new AccessDB(connectionString, queryTimeout);
        }
        public SqlProcedures( AccessDB accessDB)
        {
            AccessDBInstance = accessDB;
        }

        public void InstallSubscription(Subscription subscription)
        {
            string schemaName = "[" + subscription.MainServiceName + "]";
            SqlCommand command = new SqlCommand(schemaName + "." + ProcedureNameInstall);
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_SubscriberString", SqlDbType.NVarChar, subscription.SubscriberString));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_SubscriptionHash", SqlDbType.Int, subscription.GetHashCode()));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_ProcedureSchemaName", SqlDbType.NVarChar, subscription.ProcedureSchemaName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_ProcedureName", SqlDbType.NVarChar, subscription.ProcedureName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("TBL_ProcedureParameters", SqlDbType.Structured, SqlParameterCollectionToDataTable(subscription.ProcedureParameters)));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_NotificationValidFor", SqlDbType.Int, subscription.ValidFor));
            AccessDBInstance.SQLRunNonQueryProcedure(command);
        }

        public List<EventMessage> ReceiveSubscription(string appName, int receiveTimeout= 150000)
        {
            string schemaName = "[" + appName + "]";
            SqlCommand command = new SqlCommand(schemaName + "." + ProcedureNameReceiveNotification);
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_ReceiveTimeout", SqlDbType.Int, receiveTimeout));
            List<EventMessage> result = AccessDBInstance.SQLRunQueryProcedure<EventMessage>(command, receiveTimeout);
            return result;
        }
        
        public void UninstallSubscription(Subscription subscription)
        {
            string schemaName = "[" + subscription.MainServiceName + "]";
            SqlCommand command = new SqlCommand(schemaName + "." + ProcedureNameUninstall);
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
            SqlMetaData pName = new SqlMetaData("PName", SqlDbType.NVarChar, 100);
            SqlMetaData pType = new SqlMetaData("PType", SqlDbType.NVarChar, 20);
            SqlMetaData pValue = new SqlMetaData("PValue", SqlDbType.NVarChar, 4000);

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