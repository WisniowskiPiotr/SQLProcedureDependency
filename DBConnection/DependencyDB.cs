using System;
using System.Collections.Concurrent;
using System.Data.SqlClient;

namespace SQLDependency.DBConnection
{
    public static class DependencyDB 
    {
        public delegate void HandleMessage( NotificationMessage message);

        private static ConcurrentDictionary<string, Listener> Listeners { get; } = new ConcurrentDictionary<string, Listener>();
        public static void StartListener(string appName, string connectionString, HandleMessage messageHandler, HandleMessage unsubscribedMessageHandler = null, HandleMessage errorMessageHandler = null)
        {
            string key = appName;
            Listener listener = Listeners.AddOrUpdate(
                key,
                (foundkey) => 
                {
                    return new Listener(appName, connectionString, messageHandler, unsubscribedMessageHandler, errorMessageHandler);
                },
                (foundkey, oldListener) => 
                {
                    if (oldListener.IsListening())
                    {
                        throw new InvalidOperationException("Listener for " + appName + " is already started. Updating it during its work is prohibited.");
                    }
                    return new Listener(appName, connectionString, messageHandler, unsubscribedMessageHandler, errorMessageHandler);
                });
            if (!listener.IsListening())
            {
                listener.Start();
            }
        }
        public static void StopListener(string appName)
        {
            string key = appName ;
            Listener listener;
            if (Listeners.TryRemove(key, out listener))
            {
                listener.Stop();
            }
        }
        public static void Subscribe(string appName, string subscriberName, string procedureSchemaName, string procedureName, SqlParameterCollection procedureParameters, DateTime validTill)
        {
            Subscription subscription = new Subscription(
                    appName,
                    subscriberName,
                    procedureSchemaName,
                    procedureName,
                    procedureParameters,
                    Convert.ToInt32((validTill - DateTime.Now).TotalSeconds)
                    );
            Subscribe(appName, subscription);
        }
        public static void Subscribe(string appName,  Subscription subscription)
        {
            string key = appName;
            Listener listener ;
            if (Listeners.TryGetValue(key, out listener))
            {
                listener.SqlProcedures.InstallSubscription(subscription);
            }
            else
                throw new NullReferenceException("No DependencyDB.StartListener() invoked for current appName.");
        }
        public static void UnSubscribe(string appName, string subscriberName="", string procedureSchemaName="", string procedureName="", SqlParameterCollection procedureParameters = null, int notificationValidFor = 86400)
        {
            Subscription subscription = new Subscription(
                    appName,
                    subscriberName,
                    procedureSchemaName,
                    procedureName,
                    procedureParameters,
                    notificationValidFor
                    );
            UnSubscribe(appName, subscription);
        }
        public static void UnSubscribe(string appName, Subscription subscription)
        {
            string key = appName;
            Listener listener;
            if (Listeners.TryGetValue(key, out listener))
            {
                listener.SqlProcedures.UninstallSubscription(subscription);
            }
            else
                throw new NullReferenceException("No DependencyDB.StartListener() invoked for current appName.");
        }
    }
}