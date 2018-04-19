using Microsoft.SqlServer.Server;
using SQLProcedureDependency.DBConnection;
using SQLProcedureDependency.Message;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace SQLProcedureDependency
{
    internal class SqlProcedures
    {
        private const string ProcedureNameInstall = "[P_InstallSubscription]";
        private const string ProcedureNameReceiveNotification = "[P_ReceiveSubscription]";
        private const string ProcedureNameUninstall = "[P_UninstallSubscription]";
        /// <summary>
        /// AccessDB instance used to connect to DB.
        /// </summary>
        public AccessDB AccessDBInstance { get; }

        /// <summary>
        /// Create SqlProcedures which allows execution of DependencyDB procedures.
        /// </summary>
        /// <param name="connectionString"> Connection string with all admin provilages used to connect to DB. </param>
        /// <param name="sqlQueryTimeout"> Timeout used during execution of queries in seconds. Default: 30s. </param>
        public SqlProcedures( string connectionString, int queryTimeout=30)
        {
            AccessDBInstance = new AccessDB(connectionString, queryTimeout);
        }

        /// <summary>
        /// Create SqlProcedures which allows execution of DependencyDB procedures.
        /// </summary>
        /// <param name="accessDB"> AccessDB class used to connect to DB. </param>
        public SqlProcedures( AccessDB accessDB)
        {
            AccessDBInstance = accessDB;
        }

        /// <summary>
        /// Procedure used to install subsctiption in DB.
        /// </summary>
        /// <param name="subscription"> Subscription to be installed. </param>
        public void InstallSubscription(Subscription subscription)
        {
            if (!subscription.CanBeInstalled())
            {
                throw new ArgumentException(subscription.GetHashText() + " subscription cannot be installed, as not enougth data provided. ");
            }
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

        /// <summary>
        /// Procedure used to receive messages from DB.
        /// </summary>
        /// <param name="appName"> Application name from which messages will be returned. </param>
        /// <param name="receiveTimeout"> Timeout used during execution of queries in seconds. Default: 30s. (schould be less tchan typical app pool recucle time = 90s )</param>
        /// <returns></returns>
        public List<NotificationMessage> ReceiveSubscription(string appName, int receiveTimeout = 30)
        {
            string schemaName = "[" + appName + "]";
            SqlCommand command = new SqlCommand(schemaName + "." + ProcedureNameReceiveNotification);
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_ReceiveTimeout", SqlDbType.Int, receiveTimeout * 1000));
            List<NotificationMessage> result = AccessDBInstance.SQLRunQueryProcedure<NotificationMessage>(command,null, 0);
            return result;
        }

        /// <summary>
        /// Procedure used to uninstall subsctiption from DB.
        /// </summary>
        /// <param name="subscription"> Subscription to be uninstalled. </param>
        public void UninstallSubscription(Subscription subscription)
        {
            string schemaName = "[" + subscription.MainServiceName + "]";
            SqlCommand command = new SqlCommand(schemaName + "." + ProcedureNameUninstall);
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_SubscriberString", SqlDbType.NVarChar, subscription.SubscriberString));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_SubscriptionHash", SqlDbType.Int, subscription.CanBeInstalled() ? (object)subscription.GetHashCode() : null));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_ProcedureSchemaName", SqlDbType.NVarChar, subscription.ProcedureSchemaName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_ProcedureName", SqlDbType.NVarChar, subscription.ProcedureName));
            command.Parameters.Add(AccessDB.CreateSqlParameter("TBL_ProcedureParameters", SqlDbType.Structured, SqlParameterCollectionToDataTable(subscription.ProcedureParameters)));
            command.Parameters.Add(AccessDB.CreateSqlParameter("V_NotificationValidFor", SqlDbType.Int, subscription.ValidFor));
            AccessDBInstance.SQLRunNonQueryProcedure(command);
        }

        /// <summary>
        /// Converts SqlParameterCollection to be passed to db as SpParametersType.
        /// </summary>
        /// <param name="comandParameters"> SqlParameterCollection to be converted. </param>
        /// <returns> DataTable containing all neccesary comandParameters information. </returns>
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
                string paramValue = GetSqlParameterStringValue(sqlParam.Value, sqlParam.SqlDbType);
                SqlDataRecord sqlDataRecord = new SqlDataRecord(new[] { pName, pType, pValue });
                sqlDataRecord.SetString(0, paramName);
                sqlDataRecord.SetString(1, paramType);
                sqlDataRecord.SetString(2, paramValue);
                procedureParameters.Add(sqlDataRecord);
            }

            return procedureParameters;
        }

        /// <summary>
        /// Returns string witch valid Sql value for specified type.
        /// </summary>
        /// <param name="paramValue"> Value to be converted to string. </param>
        /// <param name="sqlDbType"> SqlDbType of paramValue. </param>
        /// <returns> Returns string witch valid Sql value for specified type. </returns>
        private static string GetSqlParameterStringValue(object paramValue, SqlDbType sqlDbType)
        {
            if (paramValue == DBNull.Value || paramValue == null)
                return "null";
            switch (sqlDbType)
            {
                case SqlDbType.Bit:
                    bool value;
                    if (!Boolean.TryParse(paramValue.ToString(), out value))
                    {
                        throw new ArgumentException( paramValue + " is not boolean. ");
                    }
                    return value ? "1" : "0" ;
                case SqlDbType.Char:
                    return "'" + paramValue.ToString().Replace("'","") + "'";
                case SqlDbType.Date:
                    return "'" + paramValue.ToString().Replace("'", "") + "'";
                case SqlDbType.DateTime:
                    return "'" + paramValue.ToString().Replace("'", "") + "'";
                case SqlDbType.DateTime2:
                    return "'" + paramValue.ToString().Replace("'", "") + "'";
                case SqlDbType.DateTimeOffset:
                    return "'" + paramValue.ToString().Replace("'", "") + "'";
                case SqlDbType.Image:
                    throw new ArgumentException(" Binary types ( in Your case SqlDbType.Image ) as parameter types in stored procedures are not supported. Consider changing Your procedure not to accept this parameter type. ");
                case SqlDbType.NChar:
                    return "'" + paramValue.ToString().Replace("'", "''") + "'";
                case SqlDbType.NText:
                    return "'" + paramValue.ToString().Replace("'", "''") + "'";
                case SqlDbType.NVarChar:
                    return "'" + paramValue.ToString().Replace("'", "''") + "'";
                case SqlDbType.SmallDateTime:
                    return "'" + paramValue.ToString().Replace("'", "") + "'";
                case SqlDbType.Structured:
                    throw new ArgumentException(" Table types as parameter types in stored procedures are not supported. Consider changing Your procedure not to accept this parameter type. ");
                case SqlDbType.Text:
                    return "'" + paramValue.ToString().Replace("'", "''") + "'";
                case SqlDbType.Time:
                    return "'" + paramValue.ToString().Replace("'", "") + "'";
                case SqlDbType.Timestamp:
                    throw new ArgumentException(" Binary types ( in Your case SqlDbType.Timestamp ) as parameter types in stored procedures are not supported. Consider changing Your procedure not to accept this parameter type. ");
                case SqlDbType.Udt:
                    throw new ArgumentException(" User defined types as parameter types in stored procedures are not supported. Consider changing Your procedure not to accept this parameter type. ");
                case SqlDbType.UniqueIdentifier:
                    return "{ GUID '" + paramValue.ToString().Replace("'", "") + "'}";
                case SqlDbType.VarBinary:
                    throw new ArgumentException(" Binary types ( in Your case SqlDbType.VarBinary ) as parameter types in stored procedures are not supported. Consider changing Your procedure not to accept this parameter type. ");
                case SqlDbType.VarChar:
                    return "'" + paramValue.ToString().Replace("'", "''") + "'";
                case SqlDbType.Variant:
                    throw new ArgumentException(" Variant types as parameter types in stored procedures are not supported. Consider changing Your procedure not to accept this parameter type. ");
                case SqlDbType.Xml:
                    return "'" + paramValue.ToString().Replace("'", "''") + "'";
                default:
                    return paramValue.ToString().Replace("'", "''");
            }
        }
    }
}