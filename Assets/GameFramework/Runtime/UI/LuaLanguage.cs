using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;
using ProjectY.Data;
using UnityEngine;

namespace ProjectY.UI
{
    /// <summary>C# UI uses the same exported LuaTxt entries and runtime overrides as Language.lua.</summary>
    public static class LuaLanguage
    {
        private static Dictionary<string,string> defaults;
        public static string Get(string id)
        {
            if(string.IsNullOrEmpty(id))throw new ArgumentException("A UI language key is required.",nameof(id));
            var translated=LocalizationService.Shared.Find("LuaTxt",id);
            if(translated!=null)return translated;
            if(defaults==null)defaults=ReadDefaults();
            if(defaults.TryGetValue(id,out var text))return text;
            throw new InvalidOperationException("Missing LuaTxt entry: "+id+". Export Language.lua before using this UI.");
        }
        public static string Format(string id,params object[] values) => string.Format(CultureInfo.InvariantCulture,Get(id),values);

        // LuaTxt is the fixed id:string, txt:text, desc:string table. Reuse its existing YCFG artifact;
        // no second authoring source, generated C# dictionary or separate language asset is maintained.
        private static Dictionary<string,string> ReadDefaults()
        {
            var asset=Resources.Load<TextAsset>("_Gen/Config/LuaTxt");
            if(asset==null)throw new InvalidOperationException("Missing exported LuaTxt config.");
            using(var stream=new MemoryStream(asset.bytes,false))
            using(var reader=new BinaryReader(stream,Encoding.UTF8))
            {
                if(Encoding.ASCII.GetString(reader.ReadBytes(4))!="YCFG"||reader.ReadUInt16()!=1)
                    throw new InvalidDataException("Unsupported LuaTxt binary format.");
                if(ReadString(reader).Length!=64)throw new InvalidDataException("Invalid LuaTxt schema fingerprint.");
                uint count=reader.ReadUInt32();
                if(count>100000)throw new InvalidDataException("Invalid LuaTxt row count.");
                var values=new Dictionary<string,string>(StringComparer.Ordinal);
                for(uint i=0;i<count;i++)
                {
                    string id=ReadString(reader),text=ReadString(reader);ReadString(reader);
                    if(string.IsNullOrEmpty(id))throw new InvalidDataException("Empty LuaTxt key.");
                    values.Add(id,text);
                }
                if(stream.Position!=stream.Length)throw new InvalidDataException("LuaTxt must have exactly id, txt and desc string columns.");
                return values;
            }
        }
        private static string ReadString(BinaryReader reader)
        {
            uint length=reader.ReadUInt32();
            if(length>1048576||length>reader.BaseStream.Length-reader.BaseStream.Position)throw new InvalidDataException("Truncated LuaTxt string.");
            return new UTF8Encoding(false,true).GetString(reader.ReadBytes((int)length));
        }
#if UNITY_EDITOR
        public static void ReloadDefaults() => defaults=null;
#endif
    }
}
