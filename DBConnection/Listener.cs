
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace DBConnection
{
    internal class Listener
    {
        /// <summary>
        /// CancellationTokenSource used to cancel Listener task.
        /// </summary>
        private CancellationTokenSource _LisenerCancellationTokenSource;

        /// <summary>
        /// Instance used 
        /// </summary>
        private SqlProcedures _SqlProcedures;

        /// <summary>
        /// Returns new Listener using connectionString to connect to DB.
        /// </summary>
        /// <param name="connectionString"> Connection string used for connectiong to DB. </param>
        /// <param name="sqlTimeout"> Timeout used for waiting for DependencyDB messages. </param>
        public Listener(string connectionString, int sqlTimeout=30)
        {
            _SqlProcedures = new SqlProcedures(connectionString, sqlTimeout);
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
                Task.Run(() => NotificationLoop(), _LisenerCancellationTokenSource.Token);
            }
            catch (TaskCanceledException)
            { }
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
                List<EventMessage> messages = _SqlProcedures.GetEvent();
                foreach (EventMessage message in messages)
                {
                    if(message.IsValid())
                        DependencyDB.HandleNotification(message);
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
    }
}