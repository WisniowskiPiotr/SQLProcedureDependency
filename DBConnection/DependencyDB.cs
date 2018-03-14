using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Xml.Linq;
using static DBConnection.Listener;

namespace DBConnection
{
    public static class DependencyDB
    {
        
        private static ConcurrentDictionary<string,Listener> Listeners = new ConcurrentDictionary<string, Listener>();
        public static Listener StartListener(string connectionString)
        {
            Listener listener = Listeners[connectionString];
            if (listener == null)
            {
                listener = new Listener(connectionString);
                //Listeners.Add(listener);
            }
            if (!listener.IsListening())
            {
                listener.Start();
            }
            
            return listener;
        }
        public static void StopListener(string connectionString)
        {
            //Listener existingListener = Listeners.Find(x => x.ConnectionString == connectionString);
            //lock (Listeners)
            //{
            //    if (existingListener != null)
            //    {
            //        if (existingListener.IsListening())
            //        {
            //            existingListener.Stop();
            //        }
            //        Listeners.Remove(existingListener);
            //    }
            //}
        }
        public static void Subscribe(string connectionString, SqlCommand procedureCmd, string subscriberName, HandleNotification onNotification, DateTime validTill)
        {
            //Subscription subscription = new Subscription(connectionString, procedureCmd, subscriberName, onNotification, validTill);
            //Listener listener = Listeners.Find(x => x.ConnectionString == connectionString);
            //if (listener == null)
            //{
            //    listener = StartListener(connectionString);
            //}
            //listener.AddSubscription(subscription);
        }
        public static void UnSubscribe(string connectionString, string subscriberName, SqlCommand procedureCmd)
        {
            //Listener listener = Listeners.Find(x => x.ConnectionString == connectionString);
            //if (listener == null)
            //    return;
            //Subscription subscription = new Subscription(connectionString, procedureCmd, subscriberName, null, new DateTime());
            //listener.RemoveSubscription(subscription);
        }

        //internal static void UnSubscribeAll(string connectionString)
        //{
        //     Listeners.RemoveAll(x => x.ConnectionString == connectionString);

        //    if (listener == null)
        //        return;
        //    listener.
        //    throw new NotImplementedException();
        //}
    }
}