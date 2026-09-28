using System;
using System.IO;
using ProjectY.Data;
using ProjectY.Samples;
using UnityEditor;
using UnityEditor.SceneManagement;
using UnityEngine;
using UnityEngine.SceneManagement;
using XLua;

namespace ProjectY.Editor
{
    public static class EquipmentGripValidation
    {
        [MenuItem("Project Y/角色/验证武器局部握点微调")]
        public static void Run()
        {
            if(EditorApplication.isPlayingOrWillChangePlaymode)throw new InvalidOperationException("Edit Mode required.");
            var scene=EditorSceneManager.NewPreviewScene();var services=new FrameworkServices(null);float error=0;int cases=0;
            try
            {
                using(var lua=new LuaEnv())
                {
                    var loader=new LuaFileLoader(LuaScriptPaths.RuntimeRoot);lua.AddLoader(loader.Load);lua.Global.Set("Services",services);
                    lua.DoString(File.ReadAllText("Tools/CharacterPreview/export_equipment.lua"));
                    try
                    {
                        for(int index=0;index<11;index++)
                        {
                            AdventureViewData.Actor state;
                            using(var row=(LuaTable)lua.DoString("return CharacterEquipmentLoadout("+index+",true)")[0])state=AdventureViewData.ReadActor(row);
                            var equipment=state.Appearance.Equipment;
                            equipment.WeaponView.PrimaryGrip.Position+=new Vector3(.017f,-.013f,.021f);equipment.WeaponView.PrimaryGrip.Rotation=new Vector3(8,12,-5);
                            equipment.WeaponView.SecondaryGrip.Position+=new Vector3(-.012f,.015f,.006f);equipment.WeaponView.SecondaryGrip.Rotation=new Vector3(-5,9,3);
                            equipment.Hold.PrimaryGrip=equipment.WeaponView.PrimaryGrip;
                            if(equipment.Hold.OffHandFollowsWeapon)equipment.Hold.SecondaryGrip=equipment.WeaponView.SecondaryGrip;
                            if(equipment.OffhandView!=null)
                            {equipment.OffhandView.PrimaryGrip.Position=new Vector3(-.014f,.012f,.009f);equipment.OffhandView.PrimaryGrip.Rotation=new Vector3(-7,11,4);equipment.Hold.SecondaryGrip=equipment.OffhandView.PrimaryGrip;}
                            var pawn=UnityEngine.Object.Instantiate(AssetDatabase.LoadAssetAtPath<GameObject>("Assets/DynamicAsset/PawnLowPoly/PawnRig.prefab")).GetComponent<PawnView>();SceneManager.MoveGameObjectToScene(pawn.gameObject,scene);
                            try
                            {
                                pawn.ApplyAppearance(state.Appearance,p=>AssetDatabase.LoadAssetAtPath<GameObject>(p.Path));pawn.Capture(state,Vector3.forward*3,0);pawn.TickPresentation(.12f);
                                var animation=pawn.GetComponentInChildren<PawnAnimationView>();var weapons=pawn.GetComponentsInChildren<WeaponModelView>();
                                var main=Array.Find(weapons,w=>w.transform.IsChildOf(animation.MainGrip));
                                error=Mathf.Max(error,Vector3.Distance(animation.MainGrip.position,main.transform.TransformPoint(equipment.WeaponView.PrimaryGrip.Position)));
                                if(equipment.Hold.OffHandFollowsWeapon)error=Mathf.Max(error,Vector3.Distance(animation.OffGrip.position,main.transform.TransformPoint(equipment.WeaponView.SecondaryGrip.Position)));
                                if(equipment.OffhandView!=null)
                                {var off=Array.Find(weapons,w=>w.transform.IsChildOf(animation.OffGrip));error=Mathf.Max(error,Vector3.Distance(animation.OffGrip.position,off.transform.TransformPoint(equipment.OffhandView.PrimaryGrip.Position)));}
                                if(Quaternion.Angle(animation.MainGrip.rotation,main.transform.rotation*Quaternion.Euler(equipment.WeaponView.PrimaryGrip.Rotation))>.05f)throw new InvalidOperationException("Primary grip rotation mismatch.");
                                cases++;
                            }
                            finally{UnityEngine.Object.DestroyImmediate(pawn.gameObject);}
                        }
                    }
                    finally{lua.DoString("CloseCharacterEquipmentFixture()");lua.Global.Set<string,object>("Services",null);}
                }
                File.WriteAllText("Art/PawnCustomization/Integration/grip-validation.json","{\"cases\":"+cases+",\"maxPositionError\":"+error.ToString("R",System.Globalization.CultureInfo.InvariantCulture)+",\"nonzeroOffsets\":true,\"scaledRifle\":true}");
                if(error>.035f)throw new InvalidOperationException("Local weapon grip validation failed: "+error);
                Debug.Log("Weapon-local grip offsets passed for "+cases+" loadouts; maximum positional error "+error);
            }
            finally{services.Player.ClearListeners();EditorSceneManager.ClosePreviewScene(scene);}
        }
    }
}
