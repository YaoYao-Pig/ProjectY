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
    public class ProjectYDataMapAreaEncounterDataWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.Data.MapAreaEncounterData);
			Utils.BeginObjectRegister(type, L, translator, 0, 4, 6, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetEnemyAt", _m_GetEnemyAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "AttachParty", _m_AttachParty);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "DetachParty", _m_DetachParty);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "AddEnemy", _m_AddEnemy);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "Id", _g_get_Id);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "EncounterId", _g_get_EncounterId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "PartyId", _g_get_PartyId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Detached", _g_get_Detached);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "EnemyCount", _g_get_EnemyCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Defeated", _g_get_Defeated);
            
			
			
			Utils.EndObjectRegister(type, L, translator, null, null,
			    null, null, null);

		    Utils.BeginClassRegister(type, L, __CreateInstance, 1, 0, 0);
			
			
            
			
			
			
			Utils.EndClassRegister(type, L, translator);
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int __CreateInstance(RealStatePtr L)
        {
            return LuaAPI.luaL_error(L, "ProjectY.Data.MapAreaEncounterData does not have a constructor!");
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetEnemyAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaEncounterData gen_to_be_invoked = (ProjectY.Data.MapAreaEncounterData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetEnemyAt( _index );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_AttachParty(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaEncounterData gen_to_be_invoked = (ProjectY.Data.MapAreaEncounterData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.Data.WorldPartyData _party = (ProjectY.Data.WorldPartyData)translator.GetObject(L, 2, typeof(ProjectY.Data.WorldPartyData));
                    
                    gen_to_be_invoked.AttachParty( _party );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_DetachParty(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaEncounterData gen_to_be_invoked = (ProjectY.Data.MapAreaEncounterData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.DetachParty(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_AddEnemy(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaEncounterData gen_to_be_invoked = (ProjectY.Data.MapAreaEncounterData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _id = LuaAPI.xlua_tointeger(L, 2);
                    int _templateId = LuaAPI.xlua_tointeger(L, 3);
                    int _q = LuaAPI.xlua_tointeger(L, 4);
                    int _r = LuaAPI.xlua_tointeger(L, 5);
                    
                        var gen_ret = gen_to_be_invoked.AddEnemy( _id, _templateId, _q, _r );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Id(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaEncounterData gen_to_be_invoked = (ProjectY.Data.MapAreaEncounterData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.Id);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_EncounterId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaEncounterData gen_to_be_invoked = (ProjectY.Data.MapAreaEncounterData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.EncounterId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_PartyId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaEncounterData gen_to_be_invoked = (ProjectY.Data.MapAreaEncounterData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.PartyId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Detached(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaEncounterData gen_to_be_invoked = (ProjectY.Data.MapAreaEncounterData)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.Detached);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_EnemyCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaEncounterData gen_to_be_invoked = (ProjectY.Data.MapAreaEncounterData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.EnemyCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Defeated(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaEncounterData gen_to_be_invoked = (ProjectY.Data.MapAreaEncounterData)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.Defeated);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
