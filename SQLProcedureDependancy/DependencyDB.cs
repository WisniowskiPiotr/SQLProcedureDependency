using System;
using System.Collections.Concurrent;
using System.Data.SqlClient;
using System.Threading;

namespace SQLProcedureDependency
{
    /// <summary>
    /// Main class used in SqlProcedureDependency. This is used to manage Receivers.
    /// </summary>
    public static class DependencyDB 
    {
        private static ConcurrentDictionary<string, Receiver> Listeners { get; } = new ConcurrentDictionary<string, Receiver>();

        /// <summary>
        /// Adds new receiver or updates existion one.
        /// </summary>
        /// <param name="appName"> Application name which is installed in DB. </param>
        /// <param name="connectionString"> Connection string used to connect to DB. </param>
        /// <param name="messageHandler"> Method for handling incoming message. Default: no method Handler will be added to receiver. </param>
        /// <param name="unsubscribedMessageHandler"> Method for handling incoming unsubscrive message. Default: messageHandler Handler will be added to receiver. </param>
        /// <param name="errorMessageHandler"> Method for handling incoming error message. Default: messageHandler Handler will be added to receiver. </param>
        /// <returns> Returns added or updated receiver. </returns>
        public static Receiver AddReceiver(
            string appName, 
            string connectionString,
            Receiver.HandleMessage messageHandler = null,
            Receiver.HandleMessage unsubscribedMessageHandler = null,
            Receiver.HandleMessage errorMessageHandler = null)
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

        /// <summary>
        /// Stops Receiving messages from appName receiver.
        /// </summary>
        /// <param name="appName"> Application name which is installed in DB. </param>
        public static void StopReceiver(string appName)
        {
            string key = appName ;
            Receiver listener;
            if (Listeners.TryRemove(key, out listener))
            {
                listener.Stop();
            }
        }

        /// <summary>
        /// Gets receiver from DependencyDB. If no receiver is found returns null.
        /// </summary>
        /// <param name="appName"> Application name which is installed in DB. </param>
        /// <returns> Gets receiver from DependencyDB. If no receiver is found returns null. </returns>
        public static Receiver GetReceiver(string appName)
        {
            string key = appName;
            Receiver listener = null;
            Listeners.TryGetValue(key, out listener);
            return listener;
        }
    }
}