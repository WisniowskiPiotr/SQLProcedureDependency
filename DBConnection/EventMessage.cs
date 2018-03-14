
using System;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.IO;
using System.Xml;
using System.Xml.Linq;

namespace DBConnection
{
    public class EventMessage : Subscription
    {
        public enum EventMessageType
        {
            Auto,
            //ForXmlType,
            //InsertExecType,
            //OpenRowSetType
        }
        
        public readonly EventMessageType MessageType;
        
        /// <summary>
        /// Raw message string.
        /// </summary>
        private readonly string MessageString;

        /// <summary>
        /// Public constructor for creating instance from Message string. Message string should be Xml with proper structure.
        /// </summary>
        /// <param name="xmlMessage"> Message string containing all neccesary information. </param>
        public EventMessage(string xmlMessage)
        {
            //try
            //{
            //    MessageString = xmlMessage;
            //    XmlDocument = XDocument.Parse(xmlMessage);

            //    GetXmlDocument();
            //    XmlDocument xml = GetXmlDocument();
            //    EventMessageType = EventMessageTypesExtensions.GetFromString(xml.DocumentElement.Name);
            //    XmlNode procedure = xml.DocumentElement.FirstChild;
            //    string procedureName = procedure.Name;

            //    SqlCommand ProcedureCmd = new SqlCommand(procedureName);
            //    foreach (XmlNode parameter in procedure.ChildNodes)
            //    {
            //        string parameterName = parameter["name"].InnerText;
            //        SqlDbType parameterType = (SqlDbType)Enum.Parse(typeof(SqlDbType), parameter["type"].InnerText);
            //        string parameterValue = parameter["value"].InnerText;
            //        ProcedureCmd.Parameters.Add(AccessDB.CreateSqlParameter(parameterName, parameterType, parameterValue));
            //    }
            //    Subscription = new Subscription(ProcedureCmd.CommandText, ProcedureCmd.Parameters);
            //}
            //catch (Exception ex)
            //{
            //    this.Subscription = null;
            //    WriteToEventLog(ex, xmlMessage);
            //}
        }
        // who - client id
        // what - wchich procedure parameters
        // new values
        // old values


        
        /// <summary>
        /// Overrides system ToString method to return Raw nessage string.
        /// </summary>
        /// <returns> Raw message string. </returns>
        public override string ToString()
        {
            return MessageString;
        }
        
        public bool IsValid()
        {
            throw new NotImplementedException();
        }
    }
}