#if USE_UNI_LUA
using LuaAPI = UniLua.Lua;
using RealStatePtr = UniLua.ILuaState;
using LuaCSFunction = UniLua.CSharpFunctionDelegate;
#else
using LuaAPI = XLua.LuaDLL.Lua;
using RealStatePtr = System.IntPtr;
using LuaCSFunction = XLua.LuaDLL.lua_CSFunction;
#endif

using XLua;
using System.Collections.Generic;


namespace XLua.CSObjectWrap
{
    using Utils = XLua.Utils;
    public class ProjectYSamplesAdventureRuntimeDemoWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.Samples.AdventureRuntimeDemo);
			Utils.BeginObjectRegister(type, L, translator, 0, 25, 10, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetGMOpen", _m_SetGMOpen);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "OpenGM", _m_OpenGM);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetMainHud", _m_SetMainHud);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "ToggleEnvironment", _m_ToggleEnvironment);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "RenderedHealthActorIds", _m_RenderedHealthActorIds);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "HealthTarget", _m_HealthTarget);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "HealthScreenPosition", _m_HealthScreenPosition);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetGrowthOpen", _m_SetGrowthOpen);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetStoryOpen", _m_SetStoryOpen);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "OpenGrowth", _m_OpenGrowth);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetEquipmentOpen", _m_SetEquipmentOpen);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "OpenEquipment", _m_OpenEquipment);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetDialogueCamera", _m_SetDialogueCamera);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "EndDialogueCamera", _m_EndDialogueCamera);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SelectCharacter", _m_SelectCharacter);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SelectCharacterSkill", _m_SelectCharacterSkill);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "CancelCharacterSkill", _m_CancelCharacterSkill);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SelectBattleSkill", _m_SelectBattleSkill);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SelectBattleMove", _m_SelectBattleMove);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetBattleAutoAI", _m_SetBattleAutoAI);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "FocusBattleActor", _m_FocusBattleActor);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "StartExpedition", _m_StartExpedition);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SendCommand", _m_SendCommand);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "FitMap", _m_FitMap);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "ToggleTownCamera", _m_ToggleTownCamera);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "MainHudFont", _g_get_MainHudFont);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "WorldCamera", _g_get_WorldCamera);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "SelectedCharacterId", _g_get_SelectedCharacterId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "SelectedCharacterSkill", _g_get_SelectedCharacterSkill);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Phase", _g_get_Phase);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "LastError", _g_get_LastError);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "SelectedBattleSkill", _g_get_SelectedBattleSkill);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "IsBattleMoveSelected", _g_get_IsBattleMoveSelected);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "BattleAutoAI", _g_get_BattleAutoAI);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "BattleHUDRevision", _g_get_BattleHUDRevision);
            
			
			
			Utils.EndObjectRegister(type, L, translator, null, null,
			    null, null, null);

		    Utils.BeginClassRegister(type, L, __CreateInstance, 1, 0, 0);
			
			
            
			
			
			
			Utils.EndClassRegister(type, L, translator);
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int __CreateInstance(RealStatePtr L)
        {
            
			try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
				if(LuaAPI.lua_gettop(L) == 1)
				{
					
					var gen_ret = new ProjectY.Samples.AdventureRuntimeDemo();
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.Samples.AdventureRuntimeDemo constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetGMOpen(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    bool _value = LuaAPI.lua_toboolean(L, 2);
                    
                    gen_to_be_invoked.SetGMOpen( _value );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_OpenGM(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.OpenGM(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetMainHud(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.UI.MainHudView _value = (ProjectY.UI.MainHudView)translator.GetObject(L, 2, typeof(ProjectY.UI.MainHudView));
                    
                    gen_to_be_invoked.SetMainHud( _value );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_ToggleEnvironment(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.ToggleEnvironment(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_RenderedHealthActorIds(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                        var gen_ret = gen_to_be_invoked.RenderedHealthActorIds(  );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_HealthTarget(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _actorId = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.HealthTarget( _actorId );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_HealthScreenPosition(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _actorId = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.HealthScreenPosition( _actorId );
                        translator.PushUnityEngineVector2(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetGrowthOpen(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    bool _value = LuaAPI.lua_toboolean(L, 2);
                    
                    gen_to_be_invoked.SetGrowthOpen( _value );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetStoryOpen(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    bool _value = LuaAPI.lua_toboolean(L, 2);
                    
                    gen_to_be_invoked.SetStoryOpen( _value );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_OpenGrowth(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.OpenGrowth(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetEquipmentOpen(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    bool _value = LuaAPI.lua_toboolean(L, 2);
                    
                    gen_to_be_invoked.SetEquipmentOpen( _value );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_OpenEquipment(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.OpenEquipment(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetDialogueCamera(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _actorId = LuaAPI.xlua_tointeger(L, 2);
                    int _npcId = LuaAPI.xlua_tointeger(L, 3);
                    string _shot = LuaAPI.lua_tostring(L, 4);
                    float _distance = (float)LuaAPI.lua_tonumber(L, 5);
                    float _height = (float)LuaAPI.lua_tonumber(L, 6);
                    float _cameraPitch = (float)LuaAPI.lua_tonumber(L, 7);
                    float _fov = (float)LuaAPI.lua_tonumber(L, 8);
                    float _blend = (float)LuaAPI.lua_tonumber(L, 9);
                    float _closeup = (float)LuaAPI.lua_tonumber(L, 10);
                    float _panelFraction = (float)LuaAPI.lua_tonumber(L, 11);
                    
                    gen_to_be_invoked.SetDialogueCamera( _actorId, _npcId, _shot, _distance, _height, _cameraPitch, _fov, _blend, _closeup, _panelFraction );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_EndDialogueCamera(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.EndDialogueCamera(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SelectCharacter(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _id = LuaAPI.xlua_tointeger(L, 2);
                    
                    gen_to_be_invoked.SelectCharacter( _id );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SelectCharacterSkill(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _actorId = LuaAPI.xlua_tointeger(L, 2);
                    int _skillId = LuaAPI.xlua_tointeger(L, 3);
                    string _target = LuaAPI.lua_tostring(L, 4);
                    
                    gen_to_be_invoked.SelectCharacterSkill( _actorId, _skillId, _target );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_CancelCharacterSkill(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.CancelCharacterSkill(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SelectBattleSkill(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _id = LuaAPI.xlua_tointeger(L, 2);
                    
                    gen_to_be_invoked.SelectBattleSkill( _id );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SelectBattleMove(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.SelectBattleMove(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetBattleAutoAI(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    bool _value = LuaAPI.lua_toboolean(L, 2);
                    
                    gen_to_be_invoked.SetBattleAutoAI( _value );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_FocusBattleActor(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _id = LuaAPI.xlua_tointeger(L, 2);
                    
                    gen_to_be_invoked.FocusBattleActor( _id );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_StartExpedition(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.StartExpedition(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SendCommand(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
			    int gen_param_count = LuaAPI.lua_gettop(L);
            
                if(gen_param_count == 5&& (LuaAPI.lua_isnil(L, 2) || LuaAPI.lua_type(L, 2) == LuaTypes.LUA_TSTRING)&& LuaTypes.LUA_TNUMBER == LuaAPI.lua_type(L, 3)&& LuaTypes.LUA_TNUMBER == LuaAPI.lua_type(L, 4)&& LuaTypes.LUA_TNUMBER == LuaAPI.lua_type(L, 5)) 
                {
                    string _command = LuaAPI.lua_tostring(L, 2);
                    int _a = LuaAPI.xlua_tointeger(L, 3);
                    int _b = LuaAPI.xlua_tointeger(L, 4);
                    int _c = LuaAPI.xlua_tointeger(L, 5);
                    
                    gen_to_be_invoked.SendCommand( _command, _a, _b, _c );
                    
                    
                    
                    return 0;
                }
                if(gen_param_count == 4&& (LuaAPI.lua_isnil(L, 2) || LuaAPI.lua_type(L, 2) == LuaTypes.LUA_TSTRING)&& LuaTypes.LUA_TNUMBER == LuaAPI.lua_type(L, 3)&& LuaTypes.LUA_TNUMBER == LuaAPI.lua_type(L, 4)) 
                {
                    string _command = LuaAPI.lua_tostring(L, 2);
                    int _a = LuaAPI.xlua_tointeger(L, 3);
                    int _b = LuaAPI.xlua_tointeger(L, 4);
                    
                    gen_to_be_invoked.SendCommand( _command, _a, _b );
                    
                    
                    
                    return 0;
                }
                if(gen_param_count == 3&& (LuaAPI.lua_isnil(L, 2) || LuaAPI.lua_type(L, 2) == LuaTypes.LUA_TSTRING)&& LuaTypes.LUA_TNUMBER == LuaAPI.lua_type(L, 3)) 
                {
                    string _command = LuaAPI.lua_tostring(L, 2);
                    int _a = LuaAPI.xlua_tointeger(L, 3);
                    
                    gen_to_be_invoked.SendCommand( _command, _a );
                    
                    
                    
                    return 0;
                }
                if(gen_param_count == 2&& (LuaAPI.lua_isnil(L, 2) || LuaAPI.lua_type(L, 2) == LuaTypes.LUA_TSTRING)) 
                {
                    string _command = LuaAPI.lua_tostring(L, 2);
                    
                    gen_to_be_invoked.SendCommand( _command );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.Samples.AdventureRuntimeDemo.SendCommand!");
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_FitMap(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.FitMap(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_ToggleTownCamera(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.ToggleTownCamera(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_MainHudFont(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.MainHudFont);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_WorldCamera(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.WorldCamera);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_SelectedCharacterId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.SelectedCharacterId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_SelectedCharacterSkill(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.SelectedCharacterSkill);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Phase(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushstring(L, gen_to_be_invoked.Phase);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_LastError(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushstring(L, gen_to_be_invoked.LastError);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_SelectedBattleSkill(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.SelectedBattleSkill);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_IsBattleMoveSelected(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.IsBattleMoveSelected);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_BattleAutoAI(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.BattleAutoAI);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_BattleHUDRevision(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Samples.AdventureRuntimeDemo gen_to_be_invoked = (ProjectY.Samples.AdventureRuntimeDemo)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.BattleHUDRevision);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
