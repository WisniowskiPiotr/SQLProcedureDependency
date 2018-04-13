
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace SQLDependency.DBConnection
{
    internal class Listener : IDisposable
    {
        /// <summary>
        /// CancellationTokenSource used to cancel Listener task.
        /// </summary>
        private CancellationTokenSource _LisenerCancellationTokenSource;
        private Task listenerJob;
        public DependencyDB.HandleMessage MessageHandler { get; }
        public DependencyDB.HandleMessage UnsubscribedMessageHandler { get; }
        public DependencyDB.HandleMessage ErrorMessageHandler { get; }

        /// <summary>
        /// Instance used 
        /// </summary>
        public SqlProcedures SqlProcedures { get; }
        public string AppName { get; }

        /// <summary>
        /// Returns new Listener using connectionString to connect to DB.
        /// </summary>
        /// <param name="connectionString"> Connection string used for connectiong to DB. </param>
        /// <param name="sqlTimeout"> Timeout used for waiting for DependencyDB messages. </param>
        public Listener(
            string appName, 
            string connectionString, 
            DependencyDB.HandleMessage messageHandler, 
            DependencyDB.HandleMessage unsubscribedMessageHandler = null, 
            DependencyDB.HandleMessage errorMessageHandler = null, 
            int sqlTimeout=30)
        {
            AppName = appName;
            SqlProcedures = new SqlProcedures(connectionString, sqlTimeout);
            MessageHandler = messageHandler;
            UnsubscribedMessageHandler = unsubscribedMessageHandler ?? messageHandler;
            ErrorMessageHandler = errorMessageHandler ?? unsubscribedMessageHandler ?? messageHandler;
        }

        /// <summary>
        /// Starts listening for notifications.
        /// </summary>
        public void Start()
        {
            Stop();
            _LisenerCancellationTokenSource = new CancellationTokenSource();
            try
            {
                listenerJob=Task.Factory.StartNew(
                    NotificationLoop,
                    _LisenerCancellationTokenSource.Token//, 
                    //TaskCreationOptions.LongRunning,
                    //TaskScheduler.Default
                    );
            }
            catch (TaskCanceledException)
            {
            }
        }

        /// <summary>
        /// Stops listening for notifications. Cancels Listener task and clears sql db.
        /// </summary>
        public void Stop()
        {
            if (_LisenerCancellationTokenSource != null
                && !_LisenerCancellationTokenSource.Token.IsCancellationRequested
                && _LisenerCancellationTokenSource.Token.CanBeCanceled)
                _LisenerCancellationTokenSource.Cancel();
            
            if (_LisenerCancellationTokenSource != null)
            {
                _LisenerCancellationTokenSource.Dispose();
                _LisenerCancellationTokenSource = null;
            }
        }

        /// <summary>
        /// Loop for listener task.
        /// </summary>
        private void NotificationLoop()
        {
            while (IsListening())
            {
                List<NotificationMessage> messages = SqlProcedures.ReceiveSubscription(AppName);
                foreach (NotificationMessage message in messages)
                {
                    switch (message.MessageType)
                    {
                        case NotificationMessageType.Error:
                            ErrorMessageHandler.Invoke(message.SubscriberString, message);
                            break;
                    }
                    MessageHandler.Invoke(message.SubscriberString, message);
                }
            }
        }

        /// <summary>
        /// Checks if listener is listening.
        /// </summary>
        /// <returns> Returns flag determining if listener is listening. </returns>
        public bool IsListening()
        {
            if (_LisenerCancellationTokenSource != null
                && !_LisenerCancellationTokenSource.IsCancellationRequested
                && listenerJob !=null
                && listenerJob.Status == TaskStatus.Running)
                return true;
            else
                return false;
        }

        public void Dispose()
        {
            if (IsListening())
                Stop();
        }
    }
}