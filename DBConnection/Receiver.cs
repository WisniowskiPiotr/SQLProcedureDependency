
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Threading;
using System.Threading.Tasks;

namespace SQLDependency.DBConnection
{
    public class Receiver : IDisposable
    {
        public delegate void HandleMessage(NotificationMessage message);
        /// <summary>
        /// CancellationTokenSource used to cancel Listener task.
        /// </summary>
        private CancellationTokenSource LoopCancellationToken;
        public event HandleMessage MessageHandler;
        public event HandleMessage UnsubscribedMessageHandler;
        public event HandleMessage ErrorMessageHandler;

        /// <summary>
        /// Instance used 
        /// </summary>
        internal SqlProcedures SqlProcedures { get; }
        public string AppName { get; }

        /// <summary>
        /// Returns new Listener using connectionString to connect to DB.
        /// </summary>
        /// <param name="connectionString"> Connection string used for connectiong to DB. </param>
        /// <param name="sqlTimeout"> Timeout used for waiting for DependencyDB messages. </param>
        public Receiver(
            string appName, 
            string connectionString,
            HandleMessage messageHandler = null,
            HandleMessage unsubscribedMessageHandler = null,
            HandleMessage errorMessageHandler = null,
            int sqlTimeout=30)
        {
            AppName = appName;
            SqlProcedures = new SqlProcedures(connectionString, sqlTimeout);
            MessageHandler += messageHandler;
            UnsubscribedMessageHandler += unsubscribedMessageHandler ?? messageHandler;
            ErrorMessageHandler += errorMessageHandler ?? unsubscribedMessageHandler ?? messageHandler;
        }

        /// <summary>
        /// Starts listening for notifications.
        /// </summary>
        public void Start(CancellationToken loopCancellationToken)
        {
            Stop();
            LoopCancellationToken = new CancellationTokenSource();
            loopCancellationToken.Register(Stop);
            try
            {
                NotificationLoop();
            }
            catch (TaskCanceledException)
            {
            }
        }
        public void Start()
        {
            CancellationToken loopCancellationToken = new CancellationToken(false);
            Start(loopCancellationToken);
        }

        /// <summary>
        /// Stops listening for notifications. Cancels Listener task and clears sql db.
        /// </summary>
        public void Stop()
        {
            if (LoopCancellationToken != null
                && !LoopCancellationToken.IsCancellationRequested)
            {
                LoopCancellationToken.Cancel();
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
                    try
                    {
                        switch (message.MessageType)
                        {
                            case NotificationMessageType.Error:
                                ErrorMessageHandler.Invoke(message);
                                break;
                            case NotificationMessageType.NotImplementedType:
                                ErrorMessageHandler.Invoke(message);
                                break;
                            case NotificationMessageType.Unsubscribed:
                                UnsubscribedMessageHandler.Invoke(message);
                                break;
                            default:
                                MessageHandler.Invoke(message);
                                break;
                        }
                    }
                    catch (Exception ex)
                    {
                        try
                        {
                            message.AddError(ex);
                            ErrorMessageHandler.Invoke(message);
                        }
                        catch (Exception)
                        { }
                    }
                }
            }
        }

        /// <summary>
        /// Checks if listener is listening.
        /// </summary>
        /// <returns> Returns flag determining if listener is listening. </returns>
        public bool IsListening()
        {
            if (LoopCancellationToken != null
                && !LoopCancellationToken.IsCancellationRequested )
                return true;
            else
                return false;
        }

        public void Dispose()
        {
            if (IsListening())
                Stop();
        }

        public void Subscribe(string subscriberName, string procedureSchemaName, string procedureName, SqlParameterCollection procedureParameters, DateTime validTill)
        {
            Subscription subscription = new Subscription(
                    AppName,
                    subscriberName,
                    procedureSchemaName,
                    procedureName,
                    procedureParameters,
                    Convert.ToInt32((validTill - DateTime.Now).TotalSeconds)
                    );
            Subscribe(subscription);
        }
        public void Subscribe( Subscription subscription)
        {
            SqlProcedures.InstallSubscription(subscription);
        }
        public void UnSubscribe( string subscriberName = "", string procedureSchemaName = "", string procedureName = "", SqlParameterCollection procedureParameters = null, int notificationValidFor = 86400)
        {

            Subscription subscription = new Subscription(
                    AppName,
                    subscriberName,
                    procedureSchemaName,
                    procedureName,
                    procedureParameters,
                    notificationValidFor
                    );
            UnSubscribe( subscription);
        }
        public void UnSubscribe(Subscription subscription)
        {
            SqlProcedures.UninstallSubscription(subscription);
        }
    }
}