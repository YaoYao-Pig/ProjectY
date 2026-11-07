using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using UnityEngine;

namespace ProjectY.Data
{
    /// <summary>Bounded presentation data. It contains no gameplay entities or simulation state.</summary>
    public sealed class WorldMenuSnapshot
    {
        public const int Width=64, Height=48, MaxLandmarks=128;
        public uint Seed;
        public float[] Heights=new float[Width*Height];
        public Color32[] Colors=new Color32[Width*Height];
        public Vector3[] Landmarks=Array.Empty<Vector3>();
        public byte[] LandmarkKinds=Array.Empty<byte>(); // 0 tree, 1 town, 2 castle
        public void Validate()
        {
            if(Heights==null||Colors==null||Heights.Length!=Width*Height||Colors.Length!=Heights.Length||Landmarks==null||LandmarkKinds==null||Landmarks.Length>MaxLandmarks||Landmarks.Length!=LandmarkKinds.Length)
                throw new InvalidDataException("Invalid menu preview dimensions.");
            foreach(float h in Heights)if(float.IsNaN(h)||float.IsInfinity(h)||h<0||h>2.5f)throw new InvalidDataException("Invalid menu preview height.");
            for(int i=0;i<Landmarks.Length;i++)
            {var p=Landmarks[i];if(float.IsNaN(p.sqrMagnitude)||float.IsInfinity(p.sqrMagnitude)||Mathf.Abs(p.x)>4.1f||Mathf.Abs(p.z)>2.81f||p.y<0||p.y>2.5f||LandmarkKinds[i]>2)throw new InvalidDataException("Invalid menu preview landmark.");}
        }
    }

    public sealed class WorldMenuSelection
    {
        public string Id="",WorldName="",CreatedAt="";
        public int Status; // 0 no world, 1 cached, 2 legacy/missing cache, 3 unreadable cache/catalog
        public WorldMenuSnapshot Snapshot;
    }

    [Serializable] internal sealed class MenuSaveHeader
    { public int version;public uint seed;public string savedAt,worldName,createdAt; }

    public sealed partial class CharacterSaveService
    {
        private const int PreviewMagic=0x50574D59, PreviewVersion=1, PreviewLimit=65536;
        private static readonly Regex ActorsHeader=new Regex(@",\s*""actors""\s*:",RegexOptions.CultureInvariant);
        internal string PreviewPath(string id)=>SlotPath(id)+".preview";
        internal string CreatedAt=>currentCreatedAt;
        internal string WorldName=>currentWorldName;
        internal static string NormalizeCreationTime(string value,string path)
        {
            if(string.IsNullOrEmpty(value))return (File.Exists(path)?File.GetCreationTimeUtc(path):DateTime.UtcNow).ToString("o",CultureInfo.InvariantCulture);
            if(!DateTimeOffset.TryParse(value,CultureInfo.InvariantCulture,DateTimeStyles.RoundtripKind,out var time))throw new InvalidDataException(ProjectY.UI.LuaLanguage.Get("MenuCreatedTimeInvalid"));
            return time.UtcDateTime.ToString("o",CultureInfo.InvariantCulture);
        }
        // Header reads are capped independently of world size. Never deserialize actor/inventory/world data here.
        private static MenuSaveHeader ReadMenuHeader(string path)
        {
            using(var reader=new StreamReader(path,Encoding.UTF8,true,4096))
            {
                var chars=new char[32768];int n=reader.ReadBlock(chars,0,chars.Length);string prefix=new string(chars,0,n);
                var marker=ActorsHeader.Match(prefix);if(!marker.Success)throw new InvalidDataException("Campaign metadata header is missing or too large.");
                var header=JsonUtility.FromJson<MenuSaveHeader>(prefix.Substring(0,marker.Index)+"}");
                if(header==null||header.version<1||header.version>32)throw new InvalidDataException("Unsupported campaign metadata version.");
                header.createdAt=NormalizeCreationTime(header.createdAt,path);return header;
            }
        }
        private IEnumerable<string> MenuSlotIds()
        {
            if(File.Exists(legacyPath))yield return "legacy";
            if(!Directory.Exists(campaignDirectory))yield break;
            foreach(string path in Directory.EnumerateFiles(campaignDirectory,"*.json",SearchOption.TopDirectoryOnly))
            {string id=Path.GetFileNameWithoutExtension(path);if(IsCampaignId(id))yield return id;}
        }
        private static bool HeaderHasWorld(MenuSaveHeader h)=>h.version==9||h.version==11||(h.version>=12&&h.version%2==0);
        internal WorldMenuSelection LatestMenuPreview()
        {
            string newest=null;MenuSaveHeader newestHeader=null;bool unreadable=false;
            foreach(string id in MenuSlotIds())
            {
                MenuSaveHeader h;
                try{h=ReadMenuHeader(SlotPath(id));}
                catch(Exception error) when(error is InvalidDataException||error is IOException||error is UnauthorizedAccessException||error is ArgumentException)
                {Debug.LogWarning("Campaign preview metadata: "+error.Message);unreadable=true;continue;}
                if(!HeaderHasWorld(h))continue;
                int order=newestHeader==null?1:string.CompareOrdinal(h.createdAt,newestHeader.createdAt);
                if(order>0||(order==0&&string.CompareOrdinal(id,newest)>0)){newest=id;newestHeader=h;}
            }
            if(newest==null)return new WorldMenuSelection{Status=unreadable?3:0};
            return ReadMenuPreview(newest,newestHeader);
        }
        internal WorldMenuSelection SelectedMenuPreview(string id)=>ReadMenuPreview(id,ReadMenuHeader(SlotPath(id)));
        private WorldMenuSelection ReadMenuPreview(string id,MenuSaveHeader h)
        {
            var selection=new WorldMenuSelection{Id=id,WorldName=h.worldName??"",CreatedAt=h.createdAt,Status=2};
            if(!HeaderHasWorld(h)||!File.Exists(PreviewPath(id)))return selection;
            try
            {
                var info=new FileInfo(PreviewPath(id));if(info.Length<24||info.Length>PreviewLimit)throw new InvalidDataException("Invalid menu preview size.");
                using(var stream=File.OpenRead(info.FullName))using(var reader=new BinaryReader(stream))
                {
                    if(reader.ReadInt32()!=PreviewMagic||reader.ReadInt32()!=PreviewVersion)throw new InvalidDataException("Unsupported menu preview.");
                    var snapshot=new WorldMenuSnapshot{Seed=reader.ReadUInt32()};
                    if(snapshot.Seed!=h.seed||reader.ReadInt32()!=WorldMenuSnapshot.Width||reader.ReadInt32()!=WorldMenuSnapshot.Height)throw new InvalidDataException("Menu preview identity mismatch.");
                    int count=reader.ReadInt32();if(count<0||count>WorldMenuSnapshot.MaxLandmarks)throw new InvalidDataException("Menu preview landmark limit.");
                    for(int i=0;i<snapshot.Heights.Length;i++){snapshot.Heights[i]=reader.ReadUInt16()/10000f;snapshot.Colors[i]=new Color32(reader.ReadByte(),reader.ReadByte(),reader.ReadByte(),255);}
                    snapshot.Landmarks=new Vector3[count];snapshot.LandmarkKinds=new byte[count];
                    for(int i=0;i<count;i++){snapshot.Landmarks[i]=new Vector3(reader.ReadSingle(),reader.ReadSingle(),reader.ReadSingle());snapshot.LandmarkKinds[i]=reader.ReadByte();}
                    if(stream.Position!=stream.Length)throw new InvalidDataException("Trailing menu preview data.");
                    snapshot.Validate();selection.Snapshot=snapshot;selection.Status=1;
                }
            }
            catch(Exception error) when(error is InvalidDataException||error is IOException||error is UnauthorizedAccessException||error is ArgumentException)
            {Debug.LogWarning("Campaign preview cache: "+error.Message);selection.Status=3;}
            return selection;
        }
        internal void StoreMenuPreview(WorldMenuSnapshot snapshot)
        {
            snapshot.Validate();if(!File.Exists(FilePath))return; // Initial world save may have failed; no orphan preview.
            string path=PreviewPath(currentSlotId),temp=path+".tmp";
            using(var stream=new FileStream(temp,FileMode.Create,FileAccess.Write,FileShare.None))using(var writer=new BinaryWriter(stream))
            {
                writer.Write(PreviewMagic);writer.Write(PreviewVersion);writer.Write(snapshot.Seed);writer.Write(WorldMenuSnapshot.Width);writer.Write(WorldMenuSnapshot.Height);writer.Write(snapshot.Landmarks.Length);
                for(int i=0;i<snapshot.Heights.Length;i++){writer.Write((ushort)Mathf.RoundToInt(snapshot.Heights[i]*10000));writer.Write(snapshot.Colors[i].r);writer.Write(snapshot.Colors[i].g);writer.Write(snapshot.Colors[i].b);}
                for(int i=0;i<snapshot.Landmarks.Length;i++){var p=snapshot.Landmarks[i];writer.Write(p.x);writer.Write(p.y);writer.Write(p.z);writer.Write(snapshot.LandmarkKinds[i]);}
                writer.Flush();stream.Flush(true);
            }
            if(File.Exists(path))File.Replace(temp,path,null);else File.Move(temp,path);
        }
        internal void DeleteCampaignSlot(string id)
        {
            string path=SlotPath(id);if(!File.Exists(path))throw new FileNotFoundException("Campaign save no longer exists.");
            // Delete optional derivatives first; a failure retains the authoritative save and its identity.
            foreach(string extra in new[]{PreviewPath(id),PreviewPath(id)+".tmp",path+".tmp",path+".bak"})if(File.Exists(extra))File.Delete(extra);
            File.Delete(path);if(id==currentSlotId)HasSave=false;
        }
    }
}
