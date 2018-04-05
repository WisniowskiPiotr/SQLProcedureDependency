using System.Xml.Linq;

namespace SQLDependency.DBConnection
{
    public class NotificationData
    {
        private string XmlMessage { get; }

        public NotificationData( string value) : this( XDocument.Parse(value).Root) { }

        public NotificationData( XElement xElement)
        {
            XmlMessage = xElement.ToString();
        }
        
        public override string ToString()
        {
            return XmlMessage;
        }
    }
}