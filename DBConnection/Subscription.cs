using System;
using System.Data;
using System.Data.SqlClient;
using System.Security.Cryptography;
using System.Text;

namespace SQLDependency.DBConnection
{
    public class Subscription : IEquatable<Subscription>
    {
        /// <summary>
        /// Application name asociated with subsctription.
        /// </summary>
        public string MainServiceName;
        /// <summary>
        /// String which is used to identify subsctriber. Max 200 chars.
        /// </summary>
        public string SubscriberString;
        /// <summary>
        /// Procedure schema name for which subscription will be made. 
        /// </summary>
        public string ProcedureSchemaName;
        /// <summary>
        /// Procedure name for which subscription will be made. 
        /// </summary>
        public string ProcedureName;
        /// <summary>
        /// Procedure parameters for which subscription will be made.
        /// </summary>
        public SqlParameterCollection ProcedureParameters;
        /// <summary>
        /// Amout of seconds till when subscription will be active.
        /// </summary>
        public int ValidFor;

        /// <summary>
        /// Creates subsctription object witch provided data.
        /// </summary>
        /// <param name="mainServiceName"> Application name asociated with subsctription. </param>
        /// <param name="subscriberString"> String which is used to identify subsctriber. Max 200 chars. </param>
        /// <param name="procedureSchemaName"> Procedure schema name for which subscription will be made. </param>
        /// <param name="procedureName"> Procedure name for which subscription will be made. </param>
        /// <param name="procedureParameters"> Procedure parameters for which subscription will be made. </param>
        /// <param name="validFor"> Amout of seconds till when subscription will be active. Default: two days. </param>
        public Subscription(string mainServiceName = "", string subscriberString="", string procedureSchemaName="", string procedureName="", SqlParameterCollection procedureParameters=null, int validFor= 172800)
        {
            if (subscriberString.Length > 200)
                throw new ArgumentException("Subscriber String must be shorter than 200 chars. Provided subsctiber string: " + subscriberString);
            MainServiceName = mainServiceName;
            SubscriberString = subscriberString;
            ProcedureSchemaName = procedureSchemaName;
            ProcedureName = procedureName;
            ProcedureParameters = procedureParameters;
            ValidFor = validFor;

            if (ProcedureParameters == null)
            {
                SqlCommand cmd = new SqlCommand();
                cmd.Parameters.Add(AccessDB.CreateSqlParameter("@V_RemoveAllParameters", SqlDbType.Bit, true));
                ProcedureParameters = cmd.Parameters;
            }
        }

        /// <summary>
        /// Gets text used to uniqaly identify subscription and produce hashcode.
        /// </summary>
        /// <returns> Gets text used to uniqaly identify subscription and produce hashcode. </returns>
        public string GetHashText()
        {
            string hash = MainServiceName + ProcedureSchemaName + ProcedureName;
            foreach (SqlParameter sqlParameter in ProcedureParameters)
            {
                hash = hash + sqlParameter.ParameterName + sqlParameter.SqlDbType.GetName() + sqlParameter.Value.ToString();
            }
            return hash;
        }

        /// <summary>
        /// Gets hashcode used to uniqaly identify subscription based on GetHashText().
        /// </summary>
        /// <returns> Gets hashcode used to uniqaly identify subscription based on GetHashText(). </returns>
        public override int GetHashCode()
        {
            char[] mystring = GetHashText().ToCharArray();
            int result = int.MinValue;
            for (int i = 0; i < mystring.Length; i++)
            {
                result = unchecked(result + ((int)mystring[i] * 617 * i));
            }
            return result;
        }

        /// <summary>
        /// Checks is subscription has enougth data to be installed in DB.
        /// </summary>
        /// <returns></returns>
        public bool CanBeInstalled()
        {
            if (!string.IsNullOrWhiteSpace(MainServiceName) &&
                !string.IsNullOrWhiteSpace(SubscriberString) &&
                !string.IsNullOrWhiteSpace(ProcedureSchemaName) &&
                !string.IsNullOrWhiteSpace(ProcedureName) &&
                ProcedureParameters != null &&
                ValidFor > 0)
                return true;
            else
                return false;
        }

        /// <summary>
        /// Compares this subscriprion with provided object. Returns true only if mainServiceName, procedureSchemaName, procedureName and procedureParameters are the same.
        /// </summary>
        /// <param name="obj"> Any object to compare. If object type is not Subscription return false. </param>
        /// <returns> Flag determining if object is Subscription for same mainServiceName, procedureSchemaName, procedureName and procedureParameters. </returns>
        public override bool Equals(object obj)
        {
            if (obj == null) return false;
            Subscription objAsSubscription = obj as Subscription;
            if (objAsSubscription == null) return false;
            else return Equals(objAsSubscription);
        }

        /// <summary>
        /// Compares this subscriprion with provided subscriprion. Returns true only if mainServiceName, procedureSchemaName, procedureName and procedureParameters are the same.
        /// </summary>
        /// <param name="sub"> Subscription to compare to. </param>
        /// <returns> Flag determining if object is Subscription for same mainServiceName, procedureSchemaName, procedureName and procedureParameters. </returns>
        public bool Equals(Subscription sub)
        {
            if (this.GetHashText() == sub.GetHashText() && this.SubscriberString == sub.SubscriberString)
            {
                return true;
            }
            else
            {
                return false;
            }
        }

    }
}