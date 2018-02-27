using System;

namespace StudioGambit.DBConnection
{
    public class Subscriber : IEquatable<Subscriber>
    {
        #region fields
        /// <summary>
        /// Subscriber Name used to identyfy subscriber.
        /// </summary>
        public readonly string SubscriberName;
        /// <summary>
        /// DateTime representing subsctription lifetime of this user.
        /// </summary>
        public readonly DateTime Lifetime;
        /// <summary>
        /// Delegate type used to be run on notification.
        /// <param name="message"> EventMessage containing message details. </param>
        /// </summary>
        public delegate void OnNotification( EventMessage message);
        /// <summary>
        /// Event to be run when notification occures.
        /// </summary>
        public event OnNotification OnNotificationEvent;
        #endregion

        /// <summary>
        /// Basic constructor for creating Subscriber object.
        /// <param name="subscriberName"> Name of subscriber. Used to identify subscriber. </param>
        /// <param name="onNotification"> OnNotification method to be run when notification occures. </param>
        /// </summary>
        public Subscriber(string subscriberName, OnNotification onNotification = null)
        {
            Lifetime = DateTime.Now + new TimeSpan(0, 0, SqlProcedures.GetSqlNotificationTimeout());
            SubscriberName = subscriberName;

            if (onNotification != null)
                OnNotificationEvent += onNotification;
        }

        /// <summary>
        /// Runs appriopriate OnNotification from this subscriber depending on EventMessage.
        /// <param name="message"> EventMessage containing natification details. </param>
        /// </summary>
        public void SendNotification( EventMessage message)
        {
            switch (message.EventMessageType)
            {
                case EventMessageType.Notification:
                    OnNotificationEvent.Invoke( message);
                    break;
                default:
                    throw Helpers.ReportException( message);
            }
        }

        #region Equals overide
        /// <summary>
        /// Override of standard GetHashCode().
        /// </summary>
        public override int GetHashCode()
        {
            string hash = SubscriberName;
            return hash.GetHashCode();
        }

        /// <summary>
        /// Compares this subscriber with provided object. Returns true if SubscriberName are the same.
        /// </summary>
        /// <param name="obj"> Any object to compare. If object type is not Subscriber return false. </param>
        /// <returns> Flag determining if object is Subscriber for same SubscriberName. </returns>
        public override bool Equals(object obj)
        {
            if (obj == null) return false;
            Subscriber objAsSubscriber = obj as Subscriber;
            if (objAsSubscriber == null) return false;
            else return Equals(objAsSubscriber);
        }

        /// <summary>
        /// Compares this subscriber with provided subscriber. Returns true only if SubscriberName are the same.
        /// </summary>
        /// <param name="sub"> Subscriber to compare to. </param>
        /// <returns> Flag determining if object is Subscriber for same SubscriberName. </returns>
        public bool Equals(Subscriber sub)
        {
            if (SubscriberName == sub.SubscriberName)
                return true;
            else
                return false;
        }
        #endregion
    }
}