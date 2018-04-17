using System;
using System.Collections.Concurrent;
using System.Data.SqlClient;
using System.Threading;
using static SQLDependency.DBConnection.Receiver;

namespace SQLDependency.DBConnection
{
    public static class DependencyDB 
    {
        private static ConcurrentDictionary<string, Receiver> Listeners { get; } = new ConcurrentDictionary<string, Receiver>();

        public static Receiver AddReceiver(
            string appName, 
            string connectionString,
            HandleMessage messageHandler = null,
            HandleMessage unsubscribedMessageHandler = null,
            HandleMessage errorMessageHandler = null)
        {
            string key = appName;
            Receiver listener = Listeners.AddOrUpdate(
                key,
                (foundkey) => 
                {
                    return new Receiver(appName, connectionString, messageHandler, unsubscribedMessageHandler, errorMessageHandler);
                },
                (foundkey, oldListener) => 
                {
                    if (oldListener.IsListening())
                    {
                        if (oldListener.SqlProcedures.AccessDBInstance.ConnectionString != connectionString)
                        {
                            throw new InvalidOperationException("Listener for " + appName + " is already started. Updating it during its work is prohibited.");
                        }
                        else
                        {
                            //oldListener.MessageHandler += messageHandler;
                            //oldListener.UnsubscribedMessageHandler += unsubscribedMessageHandler;
                            //oldListener.ErrorMessageHandler += errorMessageHandler;
                            return oldListener;
                        }
                        
                    }
                    return new Receiver(appName, connectionString, messageHandler, unsubscribedMessageHandler, errorMessageHandler);
                });
            return listener;
        }
        public static void StopReceiver(string appName)
        {
            string key = appName ;
            Receiver listener;
            if (Listeners.TryRemove(key, out listener))
            {
                listener.Stop();
            }
        }
        public static Receiver GetReceiver(string appName)
        {
            string key = appName;
            Receiver listener = null;
            Listeners.TryGetValue(key, out listener);
            return listener;
        }
    }
}