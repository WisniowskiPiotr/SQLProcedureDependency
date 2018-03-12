using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.IO;
using System.Xml.Linq;
using static DBConnection.Listener;

namespace DBConnection
{
    public static class DependencyDB
    {
        
        private static List<Listener> _listeners = new List<Listener>();
        public static Listener StartListener(string connectionString)
        {
            Listener listener = _listeners.Find(x => x.ConnectionString == connectionString);
            lock (_listeners)
            {
                if (listener == null)
                {
                    listener = new Listener(connectionString);
                    _listeners.Add(listener);
                }
                if (!listener.IsListening())
                {
                    listener.Start();
                }
            }
            return listener;
        }
        public static void StopListener(string connectionString)
        {
            Listener existingListener = _listeners.Find(x => x.ConnectionString == connectionString);
            lock (_listeners)
            {
                if (existingListener != null)
                {
                    if (existingListener.IsListening())
                    {
                        existingListener.Stop();
                    }
                    _listeners.Remove(existingListener);
                }
            }
        }
        public static void Subscribe(string connectionString, SqlCommand procedureCmd, string subscriberName, HandleNotification onNotification, DateTime validTill)
        {
            Subscription subscription = new Subscription(connectionString, procedureCmd, subscriberName, onNotification, validTill);
            Listener listener = _listeners.Find(x => x.ConnectionString == connectionString);
            if (listener == null)
            {
                listener = StartListener(connectionString);
            }
            listener.AddSubscription(subscription);
        }
        public static void UnSubscribe(string connectionString, string subscriberName, SqlCommand procedureCmd)
        {
            Listener listener = _listeners.Find(x => x.ConnectionString == connectionString);
            if (listener == null)
                return;
            Subscription subscription = new Subscription(connectionString, procedureCmd, subscriberName, null, new DateTime());
            listener.RemoveSubscription(subscription);
        }
        
    }
}