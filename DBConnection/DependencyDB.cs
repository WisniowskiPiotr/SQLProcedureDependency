using System;
using System.Collections.Concurrent;
using System.Data.SqlClient;

namespace DBConnection
{
    public static class DependencyDB 
    {
        public delegate void HandleMessage(string subscriberString, NotificationMessage message);

        private static ConcurrentDictionary<string,Listener> Listeners = new ConcurrentDictionary<string, Listener>();
        public static void StartListener(string appName, string connectionString, HandleMessage messageHandler )
        {
            string key = appName + connectionString;
            Listener listener = Listeners.AddOrUpdate(
                    key,
                    (foundkey) => new Listener(appName, connectionString, messageHandler),
                    (foundkey, oldListener) => { oldListener.MessageHandler = messageHandler; return oldListener; }
                    );
            if (!listener.IsListening())
            {
                listener.Start();
            }
        }
        public static void StopListener(string appName, string connectionString)
        {
            string key = appName + connectionString;
            Listener listener;
            if (Listeners.TryRemove(key, out listener))
            {
                listener.Stop();
            }
        }
        public static void Subscribe(string appName, string connectionString, string subscriberName, string procedureSchemaName, string procedureName, SqlParameterCollection procedureParameters, DateTime validTill)
        {
            Subscription subscription = new Subscription(
                    appName,
                    subscriberName,
                    procedureSchemaName,
                    procedureName,
                    procedureParameters,
                    Convert.ToInt32((validTill - DateTime.Now).TotalSeconds)
                    );
            Subscribe(appName, connectionString, subscription);
        }
        public static void Subscribe(string appName, string connectionString, Subscription subscription)
        {
            string key = appName + connectionString;
            Listener listener = Listeners[key];
            if (listener != null)
            {
                listener.SqlProcedures.InstallSubscription(subscription);
            }
            else
                throw new NullReferenceException("No DependencyDB.StartListener() invoked for current appName and connectionString combination.");
        }
        public static void UnSubscribe(string appName, string connectionString, string subscriberName, string procedureSchemaName="", string procedureName="", SqlParameterCollection procedureParameters = null, int notificationValidFor = 86400)
        {
            Subscription subscription = new Subscription(
                    appName,
                    subscriberName,
                    procedureSchemaName,
                    procedureName,
                    procedureParameters,
                    notificationValidFor
                    );
            UnSubscribe(appName, connectionString, subscription);
        }
        public static void UnSubscribe(string appName, string connectionString, Subscription subscription)
        {
            string key = appName + connectionString;
            Listener listener = Listeners[key];
            if (listener != null)
            {
                listener.SqlProcedures.UninstallSubscription(subscription);
            }
            else
                throw new NullReferenceException("No DependencyDB.StartListener() invoked for current appName and connectionString combination.");
        }
    }
}