using SQLProcedureDependency.Message;
using System;
using System.Collections.Generic;
using System.Data.SqlClient;
using System.Threading;
using System.Threading.Tasks;

namespace SQLProcedureDependency
{
    public class Receiver : IDisposable
    {
        /// <summary>
        /// CancellationTokenSource used to cancel listening of this receiver.
        /// </summary>
        private CancellationTokenSource LoopCancellationToken;
        /// <summary>
        /// Instance used to run sql scripts.
        /// </summary>
        internal SqlProcedures SqlProcedures { get; }
        /// <summary>
        /// Delegate used to handle NotificationMessages.
        /// </summary>
        /// <param name="message"> Message to be handled. </param>
        public delegate void HandleMessage(NotificationMessage message);
        /// <summary>
        /// Handler used to handle typical NotificationMessage.
        /// </summary>
        public event HandleMessage MessageHandler;
        /// <summary>
        /// Handler used to handle unsubscribe NotificationMessage.
        /// </summary>
        public event HandleMessage UnsubscribedMessageHandler;
        /// <summary>
        /// Handler used to handle error NotificationMessage.
        /// </summary>
        public event HandleMessage ErrorMessageHandler;
        /// <summary>
        /// Application name for which messages listener will be listening.
        /// </summary>
        public string AppName { get; }

        /// <summary>
        /// Creates new receiver witch specified properies.
        /// </summary>
        /// <param name="appName"> Application name for which messages listener will be listening. </param>
        /// <param name="connectionString"> Connection string used to connect to DB. </param>
        /// <param name="messageHandler"> Handler used to handle typical NotificationMessage. Default: no handler is specified. </param>
        /// <param name="unsubscribedMessageHandler"> Handler used to handle unsubscribe NotificationMessage. Default: messageHandler handler is used. </param>
        /// <param name="errorMessageHandler"> Handler used to handle unsubscribe NotificationMessage. Default: unsubscribedMessageHandler handler is used. </param>
        /// <param name="sqlTimeout"> Timeout in seconds used for query. Default value uses value set in constructor. 0 indicates infinite. Default: 30. </param>
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
        /// <param name="loopCancellationToken"> CancellationToken used to cancel listening. Method is sync. </param>
        public void Listen(CancellationToken loopCancellationToken)
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

        /// <summary>
        /// Starts listening for notifications.
        /// </summary>
        public void Listen()
        {
            CancellationToken loopCancellationToken = new CancellationToken(false);
            Listen(loopCancellationToken);
        }
        
        /// <summary>
        /// Stops listening for notifications. Cancels Listener task.
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
        /// Main loop for listener task.
        /// </summary>
        private void NotificationLoop()
        {
            while (IsListening())
            {
                List<NotificationMessage> messages = new List<NotificationMessage>();
                try
                {
                    messages = SqlProcedures.ReceiveSubscription(AppName);
                }
                catch (Exception ex)
                {
                    try
                    {
                        ErrorMessageHandler.Invoke(new NotificationMessage(ex.Message));
                    }
                    catch (Exception)
                    { }
                }
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
                            case NotificationMessageType.Empty:
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

        /// <summary>
        /// Destructor of object. Calls Stop() internally.
        /// </summary>
        public void Dispose()
        {
            if (IsListening())
                Stop();
        }

        /// <summary>
        /// Subscribes for notification.
        /// </summary>
        /// <param name="subscriberName"> SubscriberName used to identify subscriber. </param>
        /// <param name="procedureSchemaName"> Schema name of procedure for which subscription will be made. </param>
        /// <param name="procedureName"> Procedure name for which subscription will be made. </param>
        /// <param name="procedureParameters"> Procedure parameters for which subscription will be made. </param>
        /// <param name="validTill"> DateTime till when subscription will be active. </param>
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

        /// <summary>
        /// Subscribes for notification.
        /// </summary>
        /// <param name="subscription"> Subscription used to subscribe. </param>
        public void Subscribe( Subscription subscription)
        {
            SqlProcedures.InstallSubscription(subscription);
        }

        /// <summary>
        /// UnSubscribe from notification.
        /// </summary>
        /// <param name="subscriberName"> SubscriberName used to identify subscriber. </param>
        /// <param name="procedureSchemaName"> Schema name of procedure for which subscription will be made. </param>
        /// <param name="procedureName"> Procedure name for which subscription will be made. </param>
        /// <param name="procedureParameters"> Procedure parameters for which subscription will be made. </param>
        /// <param name="validTill"> DateTime till when notification of unsubsctription will be active. </param>
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

        /// <summary>
        /// UnSubscribe from notification.
        /// </summary>
        /// <param name="subscription"> Subscription used to unsubscribe. </param>
        public void UnSubscribe(Subscription subscription)
        {
            SqlProcedures.UninstallSubscription(subscription);
        }
    }
}
