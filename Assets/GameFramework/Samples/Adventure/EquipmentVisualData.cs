using UnityEngine;
using XLua;

namespace ProjectY.Samples
{
    // Detached display DTOs. LuaTable handles are always released by the reader.
    public sealed class EquipmentVisualData
    {
        public sealed class Asset
        {
            public int Id; public string Path;
            public static Asset Read(LuaTable row) => new Asset { Id = row.Get<int>("id"), Path = row.Get<string>("path") };
        }
        public sealed class Socket { public int Id; public string Name, Kind; public Vector3 Position, Rotation; public Asset Attachment; }
        public sealed class Weapon
        {
            public int Id; public Asset Model; public Socket[] Sockets;
            public Vector3 PreviewRotation; public float PreviewZoom;
            public static Weapon Read(LuaTable row)
            {
                var result = new Weapon { Id = row.Get<int>("id"),PreviewRotation=Vector(row,"previewRotation"),PreviewZoom=row.Get<float>("previewZoom") };
                using (var asset = row.Get<LuaTable>("asset")) result.Model = Asset.Read(asset);
                using (var sockets = row.Get<LuaTable>("sockets"))
                {
                    result.Sockets = new Socket[sockets.Length];
                    for (int i = 0; i < sockets.Length; i++) using (var socket = sockets.Get<int, LuaTable>(i + 1))
                    {
                        var item = new Socket { Id = socket.Get<int>("id"), Name = socket.Get<string>("name"), Kind = socket.Get<string>("kind"), Position = Vector(socket,"position"), Rotation = Vector(socket,"rotation") };
                        using (var asset = socket.Get<LuaTable>("asset")) if (asset != null) item.Attachment = Asset.Read(asset);
                        result.Sockets[i] = item;
                    }
                }
                return result;
            }
        }
        public sealed class Pose
        {
            public int Id; public Asset Upper, Forearm, Hand;
            public Vector3 MainShoulder, MainElbow, MainHand, OffShoulder, OffElbow, OffHand, WeaponRotation;
        }
        public sealed class Action
        {
            public int Sequence, Shots, TargetQ, TargetR; public string Kind;
            public float Duration, Recoil, Pitch, HandLift, MagazineDrop;
        }
        public Weapon WeaponView; public Pose Hold; public Action Motion;
        public static Vector3 Vector(LuaTable row, string key)
        {
            using (var v = row.Get<LuaTable>(key)) return new Vector3(v.Get<int,float>(1),v.Get<int,float>(2),v.Get<int,float>(3));
        }
        public static EquipmentVisualData Read(LuaTable row)
        {
            var result = new EquipmentVisualData();
            using (var weapon = row.Get<LuaTable>("weapon")) result.WeaponView = Weapon.Read(weapon);
            using (var pose = row.Get<LuaTable>("pose"))
            {
                result.Hold = new Pose { Id = pose.Get<int>("id"), MainShoulder=Vector(pose,"mainShoulder"),MainElbow=Vector(pose,"mainElbow"),MainHand=Vector(pose,"mainHand"),
                    OffShoulder=Vector(pose,"offShoulder"),OffElbow=Vector(pose,"offElbow"),OffHand=Vector(pose,"offHand"),WeaponRotation=Vector(pose,"weaponRotation") };
                using (var a=pose.Get<LuaTable>("upper")) result.Hold.Upper=Asset.Read(a);
                using (var a=pose.Get<LuaTable>("forearm")) result.Hold.Forearm=Asset.Read(a);
                using (var a=pose.Get<LuaTable>("hand")) result.Hold.Hand=Asset.Read(a);
            }
            using (var a=row.Get<LuaTable>("action")) result.Motion=new Action { Sequence=a.Get<int>("sequence"),Kind=a.Get<string>("kind"),Shots=a.Get<int>("shots"),
                TargetQ=a.Get<int>("targetQ"),TargetR=a.Get<int>("targetR"),Duration=a.Get<float>("duration"),Recoil=a.Get<float>("recoil"),Pitch=a.Get<float>("pitch"),HandLift=a.Get<float>("handLift"),MagazineDrop=a.Get<float>("magazineDrop") };
            return result;
        }
    }
}
