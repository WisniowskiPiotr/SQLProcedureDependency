using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Web;

namespace StudioGambit.DBConnection
{
    public class Subscription : IEquatable<Subscription>
    {
        #region fields
        /// <summary>
        /// List of subscribers to be notified.
        /// </summary>
        public readonly List<Subscriber> Subscribers = new List<Subscriber>();
        /// <summary>
        /// Notification procedure name on which data change is watched.
        /// </summary>
        public readonly string ProcedureName;
        /// <summary>
        /// SqlParameterCollection used to run notification from ProcedureName procedure.
        /// </summary>
        public readonly SqlParameterCollection ProcedureParameters;
        #endregion

        /// <summary>
        /// Basic constructor for creating Subscription object.
        /// <param name="procedureName"> Notification procedure name on which data change is watched. </param>
        /// <param name="procedureParameters"> SqlParameterCollection used to run notification from ProcedureName procedure. </param>
        /// <param name="Subscriber"> Subscriber to be notified. </param>
        /// </summary>
        public Subscription(string procedureName, SqlParameterCollection procedureParameters, Subscriber Subscriber=null)
        {
            if (Subscriber != null)
            {
                Subscribers.Add(Subscriber);
            }
            ProcedureName = procedureName;
            ProcedureParameters = procedureParameters;
        }

        #region Equals overide
        /// <summary>
        /// Override of standard GetHashCode().
        /// </summary>
        public override int GetHashCode()
        {
            string hash = ProcedureName;
            foreach (Subscriber Subscriber in Subscribers)
            {
                hash += Subscriber.SubscriberName;
            }
            foreach (SqlParameter param in ProcedureParameters)
            {
                hash += param.ParameterName + param.SqlDbType.ToString() + param.Value.ToString();
            }
            return hash.GetHashCode();
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
            if (ProcedureName != sub.ProcedureName || ProcedureParameters.Count != sub.ProcedureParameters.Count)
                return false;
            foreach (SqlParameter param in ProcedureParameters)
            {
                if (!sub.ProcedureParameters.Contains(param.ParameterName) || sub.ProcedureParameters[param.ParameterName].Value.ToString() != param.Value.ToString() || sub.ProcedureParameters[param.ParameterName].DbType != param.DbType)
                    return false;
            }
            return true;
        }
        #endregion
    }
}