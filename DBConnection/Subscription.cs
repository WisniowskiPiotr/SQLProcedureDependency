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
        
        string connectionString;
        SqlCommand procedureCmd;
        string subscriberName;
        DateTime validTill;

        public Subscription(string connectionString, SqlCommand procedureCmd, string subscriberName, EventHandler<NotificationEventArgs> onNotification, DateTime validTill)
        {
            this.connectionString = connectionString;
            this.procedureCmd = procedureCmd;
            this.subscriberName = subscriberName;
            this.OnNotification += onNotification;
            this.validTill = validTill;
        }

        public string GetConnectionString()
        {
            return  connectionString;
        }
        public SqlCommand GetSqlCommandCmd()
        { 
            return procedureCmd;
        }
        public string GetSqlCommandText()
        {
            return procedureCmd.CommandText;
        }
        public string GetSubscriberName()
        {
            return subscriberName;
        }
        public event EventHandler<NotificationEventArgs> OnNotification; 
        public DateTime GetValidTill()
        {
            return validTill;
        }
        public string GetHashText()
        {
            string hash = connectionString + subscriberName + procedureCmd.CommandText;
            foreach (SqlParameter sqlParameter in procedureCmd.Parameters)
            {
                hash = hash + sqlParameter.ParameterName + sqlParameter.SqlDbType.GetName() + sqlParameter.Value.ToString();
            }
            return hash;
        }
        public void InvokeNotification(NotificationEventArgs notificationEventArgs)
        {
            OnNotification.Invoke(this, notificationEventArgs);
        }

        /// <summary>
        /// Override of standard GetHashCode().
        /// </summary>
        public override int GetHashCode()
        {
            return this.GetHashText().GetHashCode();
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
            if (this.GetHashText() == sub.GetHashText())
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