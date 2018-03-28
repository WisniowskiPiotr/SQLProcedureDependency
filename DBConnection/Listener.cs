
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace DBConnection
{
    class Listener : IDisposable
    {
        /// <summary>
        /// CancellationTokenSource used to cancel Listener task.
        /// </summary>
        private CancellationTokenSource _LisenerCancellationTokenSource;
        public DependencyDB.HandleMessage MessageHandler;

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
        public Listener(string appName, string connectionString, DependencyDB.HandleMessage messageHandler, int sqlTimeout=30)
        {
            AppName = appName;
            SqlProcedures = new SqlProcedures(connectionString, sqlTimeout);
            MessageHandler = messageHandler;
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
                Task.Factory.StartNew(
                    NotificationLoop,
                    _LisenerCancellationTokenSource.Token, 
                    TaskCreationOptions.LongRunning,
                    TaskScheduler.Default
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
                && !_LisenerCancellationTokenSource.IsCancellationRequested)
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