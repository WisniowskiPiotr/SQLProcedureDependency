
using System;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Hosting;

namespace StudioGambit.DBConnection
{
    public class Listener : IRegisteredObject
    {
        #region fields
        /// <summary>
        /// CancellationTokenSource used to cancel Listener task.
        /// </summary>
        private static CancellationTokenSource _LisenerCancellationTokenSource;
        #endregion

        /// <summary>
        /// Creates listener and starts listening.
        /// </summary>
        public void Start()
        {
            StartListener();
        }
        /// <summary>
        /// Starts listening for notifications.
        /// </summary>
        private void StartListener()
        {
            StopListener();
            _LisenerCancellationTokenSource = new CancellationTokenSource();
            HostingEnvironment.RegisterObject(this);
            try
            {
                HostingEnvironment.QueueBackgroundWorkItem((_LisenerCancellationTokenSource) => NotificationLoop());
                //Task.Run(() => NotificationLoop(), );
            }
            catch (TaskCanceledException)
            { }

        }
        /// <summary>
        /// Required by IRegisteredObject interface. 
        /// </summary>
        public void Stop(bool immediate = false)
        {
            StopListener();
        }
        /// <summary>
        /// Stops listening for notifications. Cancels Listener task and clears sql db.
        /// </summary>
        private void StopListener()
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
            SqlProcedures.SqlRudeUninstal();
            HostingEnvironment.UnregisterObject(this);
        }
        /// <summary>
        /// Loop for listener task.
        /// </summary>
        private void NotificationLoop()
        {
            while (IsListening())
            {
                string message = SqlProcedures.GetEvent();
                if (!string.IsNullOrWhiteSpace(message))
                {
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