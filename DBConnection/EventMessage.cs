using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System;
using System.Data;
using System.Data.SqlClient;
using System.Diagnostics;
using System.IO;
using System.Xml;

namespace DBConnection
{
    public class EventMessage
    {
        // who - client id
        // what - wchich procedure parameters
        // new values
        // old values


        /// <summary>
        /// Raw message string.
        /// </summary>
        private readonly string MessageString;
        /// <summary>
        /// Overrides system ToString method to return Raw nessage string.
        /// </summary>
        /// <returns> Raw message string. </returns>
        public override string ToString()
        {
            return MessageString;
        }
        /// <summary>
        /// EventMessageType of message
        /// </summary>
        public readonly EventMessageType EventMessageType;
        /// <summary>
        /// Subscription constructed from information in MessageString. Used to identify maching Subscription in DependencyDB.ActiveSubscriptions.
        /// </summary>
        public readonly Subscription Subscription;
        /// <summary>
        /// Returns data contained in MessageString as DataSet.
        /// </summary>
        public DataSet GetDataSet()
        {
            DataSet ds = new DataSet();
            using (StringReader stringReader = new StringReader(MessageString))
            using (XmlTextReader xmlTextReader = new XmlTextReader(stringReader))
            {
                ds.ReadXml(xmlTextReader);
            }
            return ds;
        }
        /// <summary>
        /// Returns data contained in MessageString as JToken.
        /// </summary>
        public JToken GetJson()
        {
            string jsonText = JsonConvert.SerializeXmlNode(GetXmlDocument());
            return JToken.Parse(jsonText);
        }
        /// <summary>
        /// Returns data contained in MessageString as XmlDocument.
        /// </summary>
        public XmlDocument GetXmlDocument()
        {
                XmlDocument xml = new XmlDocument();
                xml.LoadXml(MessageString);
                return xml;
        }

        internal bool IsValid()
        {
            throw new NotImplementedException();
        }
        #endregion

        /// <summary>
        /// Public constructor for creating instance from Message string. Message string should be Xml with proper structure.
        /// </summary>
        /// <param name="xmlMessage"> Message string containing all neccesary information. </param>
        public EventMessage(string xmlMessage)
        {
            try
            {
                MessageString = xmlMessage;
                GetXmlDocument();
                XmlDocument xml = GetXmlDocument();
                EventMessageType = EventMessageTypesExtensions.GetFromString(xml.DocumentElement.Name);
                XmlNode procedure = xml.DocumentElement.FirstChild;
                string procedureName = procedure.Name;

                SqlCommand ProcedureCmd = new SqlCommand(procedureName);
                foreach (XmlNode parameter in procedure.ChildNodes)
                {
                    string parameterName = parameter["name"].InnerText;
                    SqlDbType parameterType = (SqlDbType)Enum.Parse(typeof(SqlDbType), parameter["type"].InnerText);
                    string parameterValue = parameter["value"].InnerText;
                    ProcedureCmd.Parameters.Add(AccessDB.SqlParameter(parameterName, parameterType, parameterValue));
                }
                Subscription = new Subscription(ProcedureCmd.CommandText, ProcedureCmd.Parameters);
            }
            catch (Exception ex)
            {
                this.Subscription = null;
                WriteToEventLog(ex, xmlMessage);
            }
        }
         
        /// <summary>
        ///  temporary for debug
        /// </summary>
        /// <param name="ex"></param>
        /// <param name="xmlMessage"></param>
        public void WriteToEventLog(Exception ex, string xmlMessage)
        {
            string message = "----DBConnection " + SqlProcedures.AppName + "---\n\nFatal during parsing EventMessage from string taken from DB \n\n";
            message = message + "XmlMessage: \n" + xmlMessage + "\n\n";
            message = message+ "Inner exception message: \n" + ex.Message + "\n\n";
            message = message + "Call Stack: \n" + ex.StackTrace + "\n\n";

            int event_id=9999;
            short event_category = 0;
            EventLogEntryType log_type = EventLogEntryType.Error;
            string logname = "MemSourceAPI"; // name of loging app
            EventLog.WriteEntry(logname, message, log_type, event_id, event_category);

        }
    }
}