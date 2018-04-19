using System;
using System.Data.SqlClient;
using System.Text;

namespace SQLProcedureDependency.DBConnection
{
    internal static partial class Helpers
    {
        /// <summary>
        /// Privides additional data when SQL exception occures.
        /// </summary>
        /// <param name="command"> SqlCommand which was executed when exception occures. </param>
        /// <param name="ex"> Inner exception which did occure. </param>
        /// <returns> Exception with additional data from SqlCommand. </returns>
        public static Exception ReportException(SqlCommand command, SqlException ex)
        {
            StringBuilder addInfo = new StringBuilder("Exception durng SQL command: ", 100);
            addInfo.Append(command.CommandText);
            addInfo.Append(Environment.NewLine);
            addInfo.Append("Parameter values: ");
            foreach (SqlParameter sqlparameter in command.Parameters)
            {
                addInfo.Append(sqlparameter.Value);
                addInfo.Append(", ");
            }
            return new Exception(addInfo.ToString(), ex);
        }
    }
}