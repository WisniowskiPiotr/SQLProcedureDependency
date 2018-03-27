using System;
using System.Collections.Generic;
using System.Text;
using System.Xml.Linq;

namespace DBConnection
{
    public class NotificationMessageError
    {
        public string ErrorNumber { get; }
        public string ErrorSeverity { get; }
        public string ErrorState { get; }
        public string ErrorProcedure { get; }
        public string ErrorLine { get; }
        public string ErrorMessage { get; }
        public XDocument Error { get; }

        public NotificationMessageError(string value) : this(XDocument.Parse(value).Root.Element("error")){ }

        public NotificationMessageError(XElement xElement)
        {
            Error = new XDocument( xElement);
            ErrorNumber = xElement.Element("number").Value;
            ErrorSeverity = xElement.Element("severity").Value;
            ErrorState = xElement.Element("state").Value;
            ErrorProcedure = xElement.Element("procedure").Value;
            ErrorLine = xElement.Element("linenb").Value;
            ErrorMessage = xElement.Element("message").Value;
        }

        public override string ToString()
        {
            return Error.Root.Value;
        }
    }
}
