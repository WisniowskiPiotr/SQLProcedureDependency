using StudioGambit.DBConnection;
using System;
using System.Data.SqlClient;
using System.Text;

namespace DBConnection
{
    public static partial class Helpers
    {
        /// <summary>
        /// Privides additional data when exception occures in DependencyDb.EventMessage context.
        /// </summary>
        /// <param name="eventMessage"> DependencyDB.EventMessage which contains information . </param>
        /// <param name="ex"> InnerException if occured. </param>
        /// <returns> New Exception with additional debug data. </returns>
        public static Exception ReportException(EventMessage eventMessage, Exception ex = null)
        {
            StringBuilder addInfo = new StringBuilder("Exception durng receiving notification from DependencyDB. EventMessage: ", 100);
            addInfo.Append(Environment.NewLine);
            addInfo.Append(eventMessage.ToString());
            addInfo.Append(Environment.NewLine);
            addInfo.Append("Subscriptions: ");
            addInfo.Append(Environment.NewLine);

            addInfo.Append(eventMessage.Subscription.ProcedureName);
            addInfo.Append(": ");
            foreach (SqlParameter param in eventMessage.Subscription.ProcedureParameters)
            {
                addInfo.Append(param.ParameterName);
                addInfo.Append(" ");
                addInfo.Append(param.SqlDbType.GetName());
                addInfo.Append(" ");
                addInfo.Append(param.Value);
                addInfo.Append(", ");
            }
            addInfo.Append("Subscriber count: ");
            addInfo.Append(eventMessage.Subscription.Subscribers.Count);
            addInfo.Append(Environment.NewLine);
            
            if (ex != null)
                return new Exception(addInfo.ToString(), ex);
            else
                return new Exception(addInfo.ToString());
        }

        /// <summary>
        /// Privides additional data when SQL exception occures.
        /// </summary>
        /// <param name="command"> SqlCommand which was executed when exception occures. </param>
        /// <param name="ex"> Inner exception which did occure. </param>
        /// <returns> Exception with additional data from SqlCommand. </returns>
        public static Exception ReportException(SqlCommand command, Exception ex)
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