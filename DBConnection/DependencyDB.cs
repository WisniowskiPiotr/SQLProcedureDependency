using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;

namespace DBConnection
{
    public class DependencyDB
    {
        private AccessDB AccessDBInstance;
        
        /// <summary>
        /// DependencyDB instance to keep track of it by IRegisteredObject.
        /// </summary>
        private static Listener _listener=new Listener ();
        /// <summary>
        /// Main list of active subscriptions. Should be locked when modified to always get consistend data.
        /// </summary>
        private static readonly List<Subscription> ActiveSubscriptions = new List<Subscription>();
        #endregion

        #region SubscribeForNotification
        /// <summary>
        /// Subscribes for notification when data in sql will change.
        /// </summary>
        /// <param name="subscriberName"> Name to be used for recognizing subscriber. </param>
        /// <param name="onNotificationMethod"> Delegate to be run when data will change. </param>
        /// <param name="procedureCmd"> Sql command containing notification procedure name and required sql parameters. </param>
        public static void SubscribeForNotification(string subscriberName, Subscriber.OnNotification onNotificationMethod, SqlCommand procedureCmd)
        {
            Subscriber Subscriber = new Subscriber(subscriberName, onNotificationMethod);
            SubscribeForNotification(new Subscription(procedureCmd.CommandText, procedureCmd.Parameters, Subscriber));
        }
        /// <summary>
        /// Subscribes for notification when data in sql will change.
        /// </summary>
        /// <param name="subscriberName"> Name to be used for recognizing subscriber. </param>
        /// <param name="onNotificationMethod"> Delegate to be run when data will change. </param>
        /// <param name="procedureName"> Notification procedure name. </param>
        /// <param name="procedureParameters"> SqlParameterCollection containing all necesary SqlParameters for Notification procedure. </param>
        public static void SubscribeForNotification(string subscriberName, Subscriber.OnNotification onNotificationMethod, string procedureName, SqlParameterCollection procedureParameters)
        {
            Subscriber Subscriber = new Subscriber(subscriberName, onNotificationMethod);
            SubscribeForNotification(new Subscription(procedureName, procedureParameters, Subscriber));
        }
        
        /// <summary>
        /// Subscribes for notification when data in sql will change.
        /// </summary>
        /// <param name="subscription"> subscription to be added to ActiveSubscriptions list. </param>
        public static void SubscribeForNotification(Subscription subscription)
        {
            if (ConfigurationManager.AppSettings["DependencyDB_Enabled"] == "true")
            {
                if (!_listener.IsListening())
                    _listener.Start();
                lock (ActiveSubscriptions)
                {
                    bool shouldInstalSql = false;
                    foreach (Subscriber Subscriber in subscription.Subscribers)
                    {
                        if (ActiveSubscriptions.Contains(subscription))
                        {
                            List<Subscriber> Subscribers = ActiveSubscriptions.Find(x => x.Equals(subscription)).Subscribers;
                            Subscribers.Add(Subscriber);
                        }
                        else
                        {
                            shouldInstalSql = true;
                            ActiveSubscriptions.Add(subscription);
                        }
                    }
                    if (shouldInstalSql)
                        SqlProcedures.SqlInstal(subscription.ProcedureName, subscription.ProcedureParameters);
                }
            }
        }
        #endregion

        #region IsSubscribed
        /// <summary>
        /// Checks if user is already subscribed.
        /// </summary>
        /// <param name="subscriberName"> Name to be used for recognizing subscriber. </param>
        /// <param name="procedureName"> Notification procedure name. </param>
        /// <param name="procedureParameters"> SqlParameterCollection containing all necesary SqlParameters for Notification procedure. </param>
        /// <returns> Flag indicating if user is subscribed for notifiaction. </returns>
        public static bool IsSubscribed(string subscriberName, string procedureName, SqlParameterCollection procedureParameters)
        {
            Subscriber subscriber = new Subscriber(subscriberName);
            Subscription subsctription = new Subscription(procedureName, procedureParameters, subscriber);
            return IsSubscribed(subsctription);
        }
        /// <summary>
        /// Checks if user is already subscribed.
        /// </summary>
        /// <param name="subscriberName"> Name to be used for recognizing subscriber. </param>
        /// <param name="procedureCmd"> Sql command containing notification procedure name and required sql parameters. </param>
        /// /// <returns> Flag indicating if user is subscribed for notifiaction. </returns>
        public static bool IsSubscribed(string subscriberName, SqlCommand procedureCmd)
        {
            Subscriber subscriber = new Subscriber(subscriberName);
            Subscription subsctription = new Subscription(procedureCmd.CommandText, procedureCmd.Parameters, subscriber);
            return IsSubscribed(subsctription);
        }
        /// <summary>
        /// Checks if user is already subscribed.
        /// </summary>
        /// <param name="subscription"> subscription to be added to ActiveSubscriptions list. </param>
        /// /// <returns> Flag indicating if user is subscribed for notifiaction. </returns>
        public static bool IsSubscribed(Subscription subscription)
        {
            Subscription acitveSubscription = ActiveSubscriptions.Find(x => x.Equals(subscription));
            if (acitveSubscription == null)
                return false;
            foreach (Subscriber subscriber in subscription.Subscribers)
            {
                if (!acitveSubscription.Subscribers.Contains(subscriber))
                    return false;
            }
            return true;
        }
        #endregion

        #region UnsubscribeFromNotification
        /// <summary>
        /// Unsubscribes from notification.
        /// </summary>
        /// <param name="SubscriberName"> Name to be used for recognizing subscriber. </param>
        /// <param name="procedureCmd"> Sql command containing notification procedure name and required sql parameters. </param>
        public static void UnsubscribeFromNotification(string subscriberName, SqlCommand procedureCmd = null)
        {
            Subscriber Subscriber = new Subscriber(subscriberName);
            if (procedureCmd == null)
                procedureCmd = new SqlCommand("");
            UnsubscribeFromNotification(new Subscription(procedureCmd.CommandText, procedureCmd.Parameters, Subscriber));
        }
        /// <summary>
        /// Unsubscribes from notification.
        /// </summary>
        /// <param name="SubscriberName"> Name to be used for recognizing subscriber. </param>
        /// <param name="procedureName"> Notification procedure name. </param>
        /// <param name="procedureParameters"> SqlParameterCollection containing all necesary SqlParameters for Notification procedure. </param>
        public static void UnsubscribeFromNotification(string subscriberName, string procedureName, SqlParameterCollection procedureParameters)
        {
            Subscriber Subscriber = new Subscriber(subscriberName);
            UnsubscribeFromNotification(new Subscription(procedureName, procedureParameters, Subscriber));
        }
        /// <summary>
        /// Unsubscribes from notification.
        /// </summary>
        /// <param name="subscription"> subscription to be removed from ActiveSubscriptions list. </param>
        public static void UnsubscribeFromNotification(Subscription subscription)
        {
            lock (ActiveSubscriptions)
            {
                if (subscription == null || (string.IsNullOrWhiteSpace(subscription.ProcedureName) && subscription.Subscribers.Count <= 0))
                {
                    // remove all subscriptions
                    foreach (Subscription sub in ActiveSubscriptions)
                    {
                        sub.Subscribers.Clear();
                    }
                }
                else if (string.IsNullOrWhiteSpace(subscription.ProcedureName))
                {
                    // remove subscribers from all subsctiptions
                    foreach (Subscription activesubscription in ActiveSubscriptions)
                    {
                        activesubscription.Subscribers.RemoveAll(x => subscription.Subscribers.Contains(x));
                    }
                }
                else if (subscription.Subscribers.Count <= 0)
                {
                    // remove subscription with all subscribers from ActiveSubscriptions
                    ActiveSubscriptions.RemoveAll(x => x.Equals(subscription));
                }
                else
                {
                    // remove subscribers from particular subscription
                    Subscription activesubscription = ActiveSubscriptions.Find(x => x.Equals(subscription));
                    activesubscription.Subscribers.RemoveAll(x => subscription.Subscribers.Contains(x));
                }
                RemoveDeadSubsctriptions();
            }
        }
        /// <summary>
        /// Removes all dead or timeout notifications from ActiveSubscriptions list.
        /// </summary>
        private static void RemoveDeadSubsctriptions()
        {
            foreach (Subscription subscription in ActiveSubscriptions)
            {
                subscription.Subscribers.RemoveAll(x => x.Lifetime < DateTime.Now );
                if (subscription.Subscribers.Count <= 0)
                    SqlProcedures.SqlUninstal(subscription.ProcedureName, subscription.ProcedureParameters);
            }
            ActiveSubscriptions.RemoveAll(x => x.Subscribers.Count <= 0);
            if (ActiveSubscriptions.Count <= 0)
                _listener.Stop();
        }
        #endregion

        /// <summary>
        /// Finds correct Subscription in ActiveSubscriptions and sends notification to each Subscriber.
        /// </summary>
        /// <param name="message"> Message to be handled. </param>
        public static void HandleNotification(EventMessage message)
        {
            Subscription activeSubscription;

            EventMessage eventMessage = new EventMessage(message);
            if (eventMessage.Subscription == null)
                return;
            lock (ActiveSubscriptions)
            {
                RemoveDeadSubsctriptions();
                activeSubscription = ActiveSubscriptions.Find(x => x.Equals(eventMessage.Subscription));
            }
            if (activeSubscription != null)
            {
                switch (eventMessage.EventMessageType)
                {
                    case EventMessageType.Notification:
                        foreach (Subscriber Subscriber in activeSubscription.Subscribers)
                        {
                            eventMessage.Subscription.Subscribers.Clear();
                            eventMessage.Subscription.Subscribers.Add(Subscriber);
                            Subscriber.SendNotification(eventMessage);
                        }
                        break;
                    case EventMessageType.OutdatedNotification:
                        SqlProcedures.SqlInstal(eventMessage.Subscription.ProcedureName, eventMessage.Subscription.ProcedureParameters);
                        break;
                    default:
                        UnsubscribeFromNotification(eventMessage.Subscription);
                        break;
                }
            }
            else if (eventMessage.EventMessageType != EventMessageType.RemoveNotification)
            {
                SqlProcedures.SqlUninstal(eventMessage.Subscription.ProcedureName, eventMessage.Subscription.ProcedureParameters);
            }
        }
    }
}