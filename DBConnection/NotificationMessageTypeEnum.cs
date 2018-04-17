
namespace SQLDependency.DBConnection
{
    /// <summary>
    /// Typical EventMessageTypes set from root node from xml notification message.
    /// </summary>
    public enum NotificationMessageType
    {
        NotImplementedType = 0,
        InsertedData = 1,
        DeletedData = 2,
        InsertedAndDeletedData = 3,
        Unsubscribed = 4,
        Error = 5,
        Empty = 6
    }
}