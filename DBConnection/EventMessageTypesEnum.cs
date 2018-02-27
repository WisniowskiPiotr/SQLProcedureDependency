
namespace StudioGambit.DBConnection
{
    /// <summary>
    /// Typical EventMessageTypes set from root node from xml notification message.
    /// </summary>
    public enum EventMessageType { NotImplemented = 0, Notification = 1, OutdatedNotification = 2, RemoveNotification = 3 }

    public static class EventMessageTypesExtensions
    {
        /// <summary>
        /// Retrievs EventMessageType from name string.
        /// </summary>
        /// <param name="name"> Name defining type of message. Typicaly root node name from xml notification message. </param>
        /// <returns> Corerct EventMessageType appriopriate for name string. </returns>
        public static EventMessageType GetFromString(string name)
        {
            switch (name)
            {
                case "Notification":
                    return EventMessageType.Notification; ;
                case "OutdatedNotification":
                    return EventMessageType.OutdatedNotification;
                case "RemoveNotification":
                    return EventMessageType.RemoveNotification;
                default:
                    return EventMessageType.NotImplemented;
            }
        }
    }
}