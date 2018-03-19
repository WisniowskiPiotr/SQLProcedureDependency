using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Xml.Linq;

namespace DBConnection
{
    public class Subscription : IEquatable<Subscription>
    {

        public string SubscriberString;
        public string ProcedureSchemaName;
        public string ProcedureName;
        public SqlParameterCollection ProcedureParameters;
        public int ValidFor;

        public Subscription( string subscriberString="", string procedureSchemaName="", string procedureName="", SqlParameterCollection procedureParameters=null, int validFor= 432000)
        {
            SubscriberString = subscriberString;
            ProcedureSchemaName = procedureSchemaName;
            ProcedureName = procedureName;
            ProcedureParameters = procedureParameters;
            ValidFor = validFor;
        }

        public string GetHashText(string appName = "")
        {
            string hash = appName + ProcedureSchemaName + ProcedureName;
            foreach (SqlParameter sqlParameter in ProcedureParameters)
            {
                hash = hash + sqlParameter.ParameterName + sqlParameter.SqlDbType.GetName() + sqlParameter.Value.ToString();
            }
            return hash;
        }

        public override int GetHashCode()
        {
            int hash = this.GetHashText().GetHashCode();
            if (hash < 0)
                return -hash;
            else
                return hash;
        }

        /// <summary>
        /// Compares this subscriprion with provided object. Returns true only if procedureName and procedureParameters are the same.
        /// </summary>
        /// <param name="obj"> Any object to compare. If object type is not Subscription return false. </param>
        /// <returns> Flag determining if object is Subscription for same procedureName and procedureParameters. </returns>
        public override bool Equals(object obj)
        {
            if (obj == null) return false;
            Subscription objAsSubscription = obj as Subscription;
            if (objAsSubscription == null) return false;
            else return Equals(objAsSubscription);
        }

        /// <summary>
        /// Compares this subscriprion with provided subscriprion. Returns true only if procedureName and procedureParameters are the same.
        /// </summary>
        /// <param name="sub"> Subscription to compare to. </param>
        /// <returns> Flag determining if object is Subscription for same procedureName and procedureParameters. </returns>
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