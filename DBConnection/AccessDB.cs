using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace SQLDependency.DBConnection
{
    /// <summary>
    /// Class reprezenting generic DataBase connection.
    /// </summary>
    public class AccessDB
    {
        /// <summary>
        /// Connection string used during standard connections to DB.
        /// </summary>
        public string ConnectionString;
        /// <summary>
        /// Returns timeout in seconds for AccessDB queries in seconds.
        /// </summary>
        public int SqlQueryTimeout;

        /// <summary>
        /// Create obcject used to connect to DB with specified connection string.
        /// </summary>
        /// <param name="connectionString">Connection string used to connect to DB. </param>
        /// <param name="sqlQueryTimeout">Timeout in seconds used during execution of queries in seconds. Default: 30s. </param>
        public AccessDB(string connectionString, int sqlQueryTimeout=30)
        {
            ConnectionString = connectionString;
            SqlQueryTimeout = sqlQueryTimeout;
        }

        /// <summary>
        /// Connects and executes sql procedure with returning a list of objects.
        /// </summary>
        /// <param name="command"> SqlCommand used for query. Only command text and command parameters must be set properly. </param>
        /// <param name="columnNames"> Array of column names wchich values are used in object creator. If null then all columns are passed to object constructor. Default: null. </param>
        /// <param name="sqlQueryTimeout"> Timeout in seconds used for query. Default value uses value set in constructor. 0 indicates infinite. Default: -1. </param>
        /// <param name="disposeCommand"> If true command will be disposed after execution. Default: true. </param>
        /// <returns> List of objects constructed from each row returned from DB. </returns>
        public List<T> SQLRunQueryProcedure<T>(SqlCommand command, string[] columnNames = null, int sqlQueryTimeout = -1,  bool disposeCommand = true)
        {
            List<T> collection = new List<T>();
            using (SqlConnection connection = new SqlConnection(ConnectionString))
            {
                PrepareSQLCommand(command, connection, sqlQueryTimeout);
                try
                {
                    command.Connection.Open();
                    using (SqlDataReader sqlDataReader = command.ExecuteReader(CommandBehavior.SingleResult))
                    {
                        while (sqlDataReader.Read())
                        {
                            int columnCount = (columnNames != null)? columnNames.Length: sqlDataReader.FieldCount;
                            object[] cells = new object[columnCount];
                            for (int i = 0; i < columnCount; i++)
                            {
                                object obj;
                                if (columnNames != null)
                                {
                                    obj = sqlDataReader[columnNames[i]];
                                }
                                else
                                {
                                    obj = sqlDataReader[i];
                                };
                                if (obj == DBNull.Value)
                                {
                                    cells[i] = null;
                                }
                                else
                                {
                                    cells[i] = obj;
                                }
                            }
                            collection.Add((T)Activator.CreateInstance(typeof(T), cells));
                        }
                    }
                }
                catch (SqlException ex)
                {
                    throw Helpers.ReportException(command, ex);
                }
                finally
                {
                    command.Connection.Close();
                    if (disposeCommand)
                        command.Dispose();
                }
            }
            return collection;
        }

        /// <summary>
        /// Connects and executes sql procedure without returning a value.
        /// </summary>
        /// <param name="command"> SqlCommand used for query. Only command text and command parameters must be set properly. </param>
        /// <param name="sqlQueryTimeout"> Timeout in seconds used for query. Default value uses value set in constructor. 0 indicates infinite. Default: -1. </param>
        /// <param name="disposeCommand"> If true command will be disposed after execution. Default: true. </param>
        public void SQLRunNonQueryProcedure(SqlCommand command, int sqlQueryTimeout = 0, bool disposeCommand = true)
        {
            using (SqlConnection connection = new SqlConnection(ConnectionString))
            {
                PrepareSQLCommand(command, connection, sqlQueryTimeout);
                try
                {
                    command.Connection.Open();
                    command.ExecuteNonQuery();
                }
                catch (SqlException ex)
                {
                    throw Helpers.ReportException(command, ex);
                }
                finally
                {
                    command.Connection.Close();
                    if (disposeCommand)
                        command.Dispose();
                }
            }
        }

        /// <summary>
        /// Prepares SqlCommand for execution.
        /// </summary>
        /// <param name="command"> SqlCommand which values are to be set. </param>
        /// <param name="connection"> SqlConnection to be set in command. </param>
        /// <param name="sqlQueryTimeout"> Timeout in seconds used for query. Default value uses value set in constructor. 0 indicates infinite. Default: -1. </param>
        private void PrepareSQLCommand(SqlCommand command, SqlConnection connection, int sqlQueryTimeout = 0)
        {
            if (command.CommandText.Trim().Contains(" "))
                command.CommandType = CommandType.Text;
            else
                command.CommandType = CommandType.StoredProcedure;
            command.Connection = connection;
            if(sqlQueryTimeout <0)
                command.CommandTimeout = SqlQueryTimeout;
            else
                command.CommandTimeout = sqlQueryTimeout;

            foreach (SqlParameter sqlparameter in command.Parameters)
            {
                RepairSQLBug(sqlparameter);
            }
        }

        /// <summary>
        /// Repairs SQL bug when a table in parameter is passed to SQL DB.
        /// </summary>
        /// <param name="sqlparameter"> Sqlparameter for which TypeName need to be fixed. </param>
        private void RepairSQLBug(SqlParameter sqlparameter)
        {
            if (sqlparameter.SqlDbType != SqlDbType.Structured)
            {
                return;
            }
            string name = sqlparameter.TypeName;
            int index = name.IndexOf(".");
            if (index == -1)
            {
                return;
            }
            name = name.Substring(index + 1);
            if (name.Contains("."))
            {
                sqlparameter.TypeName = name;
            }
        }

        /// <summary>
        /// Creates SqlParameter with parameterName, paramType and value set.
        /// </summary>
        /// <param name="parameterName"> Parameter name to be set. If name not starts with @ it will be added. </param>
        /// <param name="paramType"> SqlDbType of resulting parameter. </param>
        /// <param name="value"> Value to be set. </param>
        /// <returns> Creates SqlParameter with parameterName, paramType and value set. </returns>
        public static SqlParameter CreateSqlParameter(string parameterName, SqlDbType paramType, object value)
        {
            if (string.IsNullOrEmpty(parameterName))
                throw new ArgumentNullException(parameterName);
            if (parameterName[0] != '@')
                parameterName = "@" + parameterName;
            if (value == null)
            {
                value = DBNull.Value;
            }
            SqlParameter sqlParameter = new SqlParameter(parameterName, paramType)
            {
                Value = value
            };
            return sqlParameter;
        }
    }
}