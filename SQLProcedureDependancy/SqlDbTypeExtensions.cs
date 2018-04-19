using System;
using System.Data;

namespace SQLProcedureDependency.DBConnection
{
    internal static class SqlDbTypeExtensions
    {
        /// <summary>
        /// Returns string representing SqlDbType.
        /// </summary>
        /// <returns> Returns string representing SqlDbType. </returns>
        public static string GetName(this SqlDbType sqlDbType)
        {
            string name = Enum.GetName(sqlDbType.GetType(), sqlDbType);
            if (sqlDbType == SqlDbType.NVarChar || sqlDbType == SqlDbType.VarChar || sqlDbType == SqlDbType.VarBinary)
            {
                name = name + "(max)";
            }
            return name;
        }
    }
}