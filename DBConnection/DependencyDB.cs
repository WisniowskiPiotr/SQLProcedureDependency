using System;
using System.Collections.Concurrent;
using System.Data.SqlClient;
using System.Threading;

namespace SQLDependency.DBConnection
{
    public static class DependencyDB 
    {
        private static ConcurrentDictionary<string, Receiver> Listeners { get; } = new ConcurrentDictionary<string, Receiver>();

        public static Receiver AddReceiver(string appName, string connectionString)
        {
            string key = appName;
            Receiver listener = Listeners.AddOrUpdate(
                key,
                (foundkey) => 
                {
                    return new Receiver(appName, connectionString);
                },
                (foundkey, oldListener) => 
                {
                    if (oldListener.IsListening())
                    {
                        throw new InvalidOperationException("Listener for " + appName + " is already started. Updating it during its work is prohibited.");
                    }
                    return new Receiver(appName, connectionString);
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