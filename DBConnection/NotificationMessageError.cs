using System.Xml.Linq;

namespace SQLDependency.DBConnection
{
    public class NotificationMessageError
    {
        /// <summary>
        /// Error number provided by sql.
        /// </summary>
        public string ErrorNumber { get; }
        /// <summary>
        /// ErrorSeverity number provided by sql.
        /// </summary>
        public string ErrorSeverity { get; }
        /// <summary>
        /// ErrorState provided by sql.
        /// </summary>
        public string ErrorState { get; }
        /// <summary>
        /// Procedure which resulted in error provided by sql.
        /// </summary>
        public string ErrorProcedure { get; }
        /// <summary>
        /// Line number provided by sql where error did occure.
        /// </summary>
        public string ErrorLine { get; }
        /// <summary>
        /// ErrorMessage provided by sql.
        /// </summary>
        public string ErrorMessage { get; }
        /// <summary>
        /// XDocument containing parsed error message.
        /// </summary>
        private XDocument Error { get; }
        
        /// <summary>
        /// Constructor of NotificationMessageError class which in which error data is stored.
        /// </summary>
        /// <param name="value"> String containing raw xml data from Sql message. </param>
        public NotificationMessageError(string value) : this(XDocument.Parse(value).Root.Element("error")){ }

        /// <summary>
        /// Constructor of NotificationMessageError class which in which data is stored.
        /// </summary>
        /// <param name="xElement"> XElement containing error data from Sql message. </param>
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

        /// <summary>
        /// Returns raw xml data from Sql error message.
        /// </summary>
        /// <returns> Returns raw xml data from Sql error message. </returns>
        public override string ToString()
        {
            return Error.Root.Value;
        }
    }
}
