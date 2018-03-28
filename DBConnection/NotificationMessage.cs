
using System;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.IO;
using System.Xml;
using System.Xml.Linq;

namespace DBConnection
{
    public class NotificationMessage : Subscription
    {
        /// <summary>
        /// Raw message string.
        /// </summary>
        public string MessageString { get; }
        /// <summary>
        /// DateTime till when Subscription is not outdated.
        /// </summary>
        public DateTime ValidTill { get; }
        /// <summary>
        /// Message parsed XDocument.
        /// </summary>
        public XDocument Message { get; }
        public NotificationMessageError Error { get; }
        public NotificationData Inserted { get; }
        public NotificationData Deleted { get; }
        public NotificationMessageType MessageType { get; } = NotificationMessageType.NotImplementedType;

        /// <summary>
        /// Public constructor for creating instance from Message string. Message string should be Xml with proper structure.
        /// </summary>
        /// <param name="xmlMessage"> Message string containing all neccesary information. </param>
        public NotificationMessage(string xmlMessage)
        {
            MessageString = xmlMessage;
            Message = XDocument.Parse(xmlMessage);
            base.MainServiceName = Message.Element("notification").Attribute("servicename").Value;
            base.SubscriberString = Message.Element("notification").Attribute("subscriberstring").Value;
            ValidTill = DateTime.Parse( Message.Element("notification").Attribute("validtill").Value );
            base.ValidFor = Convert.ToInt32((ValidTill - DateTime.Now).TotalSeconds);
            base.ProcedureSchemaName = Message.Element("notification").Element("schema").Attribute("name").Value;
            base.ProcedureName = Message.Element("notification").Element("schema").Element("procedure").Attribute("name").Value;
            if (Message.Element("notification").Element("error") != null)
            {
                Error = new NotificationMessageError(Message.Element("notification").Element("error"));
            }
            if (Message.Element("notification").Element("inserted") != null)
            {
                Inserted = new NotificationData(Message.Element("notification").Element("inserted"));
            }
            if (Message.Element("notification").Element("deleted") != null)
            {
                Deleted = new NotificationData(Message.Element("notification").Element("deleted"));
            }

            if (Inserted != null)
                MessageType = NotificationMessageType.InsertedData;
            if (Deleted != null)
                MessageType = NotificationMessageType.DeletedData;
            if (Inserted != null && Deleted != null)
                MessageType = NotificationMessageType.InsertedAndDeletedData;
            if (Message.Element("notification").Element("unsubscribed") != null)
                MessageType = NotificationMessageType.Unsubscribed;
            if (Error!=null)
                MessageType = NotificationMessageType.Error;

            SqlCommand ProcedureCmd = new SqlCommand(base.ProcedureSchemaName + "." + base.ProcedureName);
            foreach (XElement parameter in Message.Element("notification").Element("schema").Element("procedure").Elements("parameter"))
            {
                string parameterName = parameter.Element("name").Value;
                SqlDbType parameterType = (SqlDbType)Enum.Parse(typeof(SqlDbType), parameter.Element("type").Value);
                string parameterValue = parameter.Element("value").Value;
                ProcedureCmd.Parameters.Add(AccessDB.CreateSqlParameter(parameterName, parameterType, parameterValue));
            }
            base.ProcedureParameters = ProcedureCmd.Parameters;
        }
        
        /// <summary>
        /// Overrides system ToString method to return Raw nessage string.
        /// </summary>
        /// <returns> Raw message string. </returns>
        public override string ToString()
        {
            return MessageString;
        }
    }
}