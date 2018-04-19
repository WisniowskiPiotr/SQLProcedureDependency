using System.Xml.Linq;

namespace SQLDependency.DBConnection
{
    public class NotificationData
    {
        private string XmlMessage { get; }

        /// <summary>
        /// Constructor of NotificationData object in which data is stored.
        /// </summary>
        /// <param name="value"> String containing raw xml data from Sql message. </param>
        public NotificationData( string value) : this( XDocument.Parse(value).Root) { }

        /// <summary>
        /// Constructor of NotificationData object in which data is stored.
        /// </summary>
        /// <param name="xElement"> XElement containing data from Sql message. </param>
        public NotificationData( XElement xElement)
        {
            XmlMessage = xElement.ToString();
        }

        /// <summary>
        /// Returns raw xml data from Sql message.
        /// </summary>
        /// <returns> Returns raw xml data from Sql message. </returns>
        public override string ToString()
        {
            return XmlMessage;
        }
    }
}