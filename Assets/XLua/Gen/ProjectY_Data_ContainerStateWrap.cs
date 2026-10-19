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
    public class ProjectYDataContainerStateWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.Data.ContainerState);
			Utils.BeginObjectRegister(type, L, translator, 0, 1, 10, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetCellAt", _m_GetCellAt);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "Durability", _g_get_Durability);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "MaxDurability", _g_get_MaxDurability);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Destroyed", _g_get_Destroyed);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "RequiresBreaking", _g_get_RequiresBreaking);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Unlocked", _g_get_Unlocked);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "UnlockEncounterId", _g_get_UnlockEncounterId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Rotation", _g_get_Rotation);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "CellCount", _g_get_CellCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "CanSearch", _g_get_CanSearch);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Configured", _g_get_Configured);
            
			
			
			Utils.EndObjectRegister(type, L, translator, null, null,
			    null, null, null);

		    Utils.BeginClassRegister(type, L, __CreateInstance, 7, 0, 0);
			Utils.RegisterFunc(L, Utils.CLS_IDX, "Of", _m_Of_xlua_st_);
            Utils.RegisterFunc(L, Utils.CLS_IDX, "Revision", _m_Revision_xlua_st_);
            Utils.RegisterFunc(L, Utils.CLS_IDX, "Initialize", _m_Initialize_xlua_st_);
            Utils.RegisterFunc(L, Utils.CLS_IDX, "Unlock", _m_Unlock_xlua_st_);
            Utils.RegisterFunc(L, Utils.CLS_IDX, "Hit", _m_Hit_xlua_st_);
            Utils.RegisterFunc(L, Utils.CLS_IDX, "AdvanceCooldowns", _m_AdvanceCooldowns_xlua_st_);
            
			
            
			
			
			
			Utils.EndClassRegister(type, L, translator);
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int __CreateInstance(RealStatePtr L)
        {
            return LuaAPI.luaL_error(L, "ProjectY.Data.ContainerState does not have a constructor!");
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetCellAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.ContainerState gen_to_be_invoked = (ProjectY.Data.ContainerState)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetCellAt( _index );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Of_xlua_st_(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
            
                
                {
                    ProjectY.Data.MapAreaLootData _row = (ProjectY.Data.MapAreaLootData)translator.GetObject(L, 1, typeof(ProjectY.Data.MapAreaLootData));
                    
                        var gen_ret = ProjectY.Data.ContainerState.Of( _row );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Revision_xlua_st_(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
            
                
                {
                    ProjectY.Data.MapAreaStateData _area = (ProjectY.Data.MapAreaStateData)translator.GetObject(L, 1, typeof(ProjectY.Data.MapAreaStateData));
                    
                        var gen_ret = ProjectY.Data.ContainerState.Revision( _area );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Initialize_xlua_st_(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
            
                
                {
                    ProjectY.Data.MapAreaStateData _area = (ProjectY.Data.MapAreaStateData)translator.GetObject(L, 1, typeof(ProjectY.Data.MapAreaStateData));
                    int _id = LuaAPI.xlua_tointeger(L, 2);
                    int _durability = LuaAPI.xlua_tointeger(L, 3);
                    bool _requiresBreaking = LuaAPI.lua_toboolean(L, 4);
                    int _encounter = LuaAPI.xlua_tointeger(L, 5);
                    int _rotation = LuaAPI.xlua_tointeger(L, 6);
                    int[] _footprint = (int[])translator.GetObject(L, 7, typeof(int[]));
                    
                    ProjectY.Data.ContainerState.Initialize( _area, _id, _durability, _requiresBreaking, _encounter, _rotation, _footprint );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Unlock_xlua_st_(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
            
                
                {
                    ProjectY.Data.MapAreaStateData _area = (ProjectY.Data.MapAreaStateData)translator.GetObject(L, 1, typeof(ProjectY.Data.MapAreaStateData));
                    int _id = LuaAPI.xlua_tointeger(L, 2);
                    
                    ProjectY.Data.ContainerState.Unlock( _area, _id );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Hit_xlua_st_(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
            
                
                {
                    ProjectY.Data.MapAreaStateData _area = (ProjectY.Data.MapAreaStateData)translator.GetObject(L, 1, typeof(ProjectY.Data.MapAreaStateData));
                    int _id = LuaAPI.xlua_tointeger(L, 2);
                    int _amount = LuaAPI.xlua_tointeger(L, 3);
                    
                        var gen_ret = ProjectY.Data.ContainerState.Hit( _area, _id, _amount );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_AdvanceCooldowns_xlua_st_(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
            
                
                {
                    ProjectY.Data.CombatActorData _actor = (ProjectY.Data.CombatActorData)translator.GetObject(L, 1, typeof(ProjectY.Data.CombatActorData));
                    
                    ProjectY.Data.ContainerState.AdvanceCooldowns( _actor );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Durability(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ContainerState gen_to_be_invoked = (ProjectY.Data.ContainerState)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.Durability);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_MaxDurability(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ContainerState gen_to_be_invoked = (ProjectY.Data.ContainerState)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.MaxDurability);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Destroyed(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ContainerState gen_to_be_invoked = (ProjectY.Data.ContainerState)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.Destroyed);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_RequiresBreaking(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ContainerState gen_to_be_invoked = (ProjectY.Data.ContainerState)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.RequiresBreaking);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Unlocked(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ContainerState gen_to_be_invoked = (ProjectY.Data.ContainerState)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.Unlocked);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_UnlockEncounterId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ContainerState gen_to_be_invoked = (ProjectY.Data.ContainerState)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.UnlockEncounterId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Rotation(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ContainerState gen_to_be_invoked = (ProjectY.Data.ContainerState)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.Rotation);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_CellCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ContainerState gen_to_be_invoked = (ProjectY.Data.ContainerState)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.CellCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_CanSearch(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ContainerState gen_to_be_invoked = (ProjectY.Data.ContainerState)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.CanSearch);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Configured(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ContainerState gen_to_be_invoked = (ProjectY.Data.ContainerState)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.Configured);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
