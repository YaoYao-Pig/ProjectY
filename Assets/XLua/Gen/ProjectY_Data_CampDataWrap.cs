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
    public class ProjectYDataCampDataWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.Data.CampData);
			Utils.BeginObjectRegister(type, L, translator, 0, 15, 6, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetLevelAt", _m_GetLevelAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetStorageAt", _m_GetStorageAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetJobAt", _m_GetJobAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetLevel", _m_GetLevel);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Stored", _m_Stored);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "JobFor", _m_JobFor);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Open", _m_Open);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Close", _m_Close);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Clear", _m_Clear);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Upgrade", _m_Upgrade);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Enqueue", _m_Enqueue);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Claim", _m_Claim);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Deposit", _m_Deposit);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Withdraw", _m_Withdraw);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Wait", _m_Wait);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "IsOpen", _g_get_IsOpen);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Revision", _g_get_Revision);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "LevelCount", _g_get_LevelCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "StorageCount", _g_get_StorageCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "JobCount", _g_get_JobCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "StoredTotal", _g_get_StoredTotal);
            
			
			
			Utils.EndObjectRegister(type, L, translator, null, null,
			    null, null, null);

		    Utils.BeginClassRegister(type, L, __CreateInstance, 4, 0, 0);
			Utils.RegisterFunc(L, Utils.CLS_IDX, "For", _m_For_xlua_st_);
            Utils.RegisterFunc(L, Utils.CLS_IDX, "Prepared", _m_Prepared_xlua_st_);
            Utils.RegisterFunc(L, Utils.CLS_IDX, "StackKind", _m_StackKind_xlua_st_);
            
			
            
			
			
			
			Utils.EndClassRegister(type, L, translator);
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int __CreateInstance(RealStatePtr L)
        {
            
			try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
				if(LuaAPI.lua_gettop(L) == 1)
				{
					
					var gen_ret = new ProjectY.Data.CampData();
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.Data.CampData constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_For_xlua_st_(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
            
                
                {
                    ProjectY.Data.AdventureData _adventure = (ProjectY.Data.AdventureData)translator.GetObject(L, 1, typeof(ProjectY.Data.AdventureData));
                    
                        var gen_ret = ProjectY.Data.CampData.For( _adventure );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Prepared_xlua_st_(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
            
                
                {
                    ProjectY.Data.PreparedCharacterSave _prepared = (ProjectY.Data.PreparedCharacterSave)translator.GetObject(L, 1, typeof(ProjectY.Data.PreparedCharacterSave));
                    
                        var gen_ret = ProjectY.Data.CampData.Prepared( _prepared );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetLevelAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetLevelAt( _index );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetStorageAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetStorageAt( _index );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetJobAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetJobAt( _index );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetLevel(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _facility = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetLevel( _facility );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Stored(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _item = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.Stored( _item );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_JobFor(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _facility = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.JobFor( _facility );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Open(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.Open(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Close(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.Close(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Clear(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.Clear(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Upgrade(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _facility = LuaAPI.xlua_tointeger(L, 2);
                    int _expectedLevel = LuaAPI.xlua_tointeger(L, 3);
                    int _revision = LuaAPI.xlua_tointeger(L, 4);
                    int _coins = LuaAPI.xlua_tointeger(L, 5);
                    int[] _items = (int[])translator.GetObject(L, 6, typeof(int[]));
                    int[] _counts = (int[])translator.GetObject(L, 7, typeof(int[]));
                    ProjectY.Data.EquipmentData _equipment = (ProjectY.Data.EquipmentData)translator.GetObject(L, 8, typeof(ProjectY.Data.EquipmentData));
                    ProjectY.Data.PlayerData _player = (ProjectY.Data.PlayerData)translator.GetObject(L, 9, typeof(ProjectY.Data.PlayerData));
                    
                        var gen_ret = gen_to_be_invoked.Upgrade( _facility, _expectedLevel, _revision, _coins, _items, _counts, _equipment, _player );
                        LuaAPI.lua_pushstring(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Enqueue(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _facility = LuaAPI.xlua_tointeger(L, 2);
                    int _recipe = LuaAPI.xlua_tointeger(L, 3);
                    int _requiredLevel = LuaAPI.xlua_tointeger(L, 4);
                    double _now = LuaAPI.lua_tonumber(L, 5);
                    double _duration = LuaAPI.lua_tonumber(L, 6);
                    int _revision = LuaAPI.xlua_tointeger(L, 7);
                    int _coins = LuaAPI.xlua_tointeger(L, 8);
                    int[] _items = (int[])translator.GetObject(L, 9, typeof(int[]));
                    int[] _counts = (int[])translator.GetObject(L, 10, typeof(int[]));
                    ProjectY.Data.EquipmentData _equipment = (ProjectY.Data.EquipmentData)translator.GetObject(L, 11, typeof(ProjectY.Data.EquipmentData));
                    ProjectY.Data.PlayerData _player = (ProjectY.Data.PlayerData)translator.GetObject(L, 12, typeof(ProjectY.Data.PlayerData));
                    
                        var gen_ret = gen_to_be_invoked.Enqueue( _facility, _recipe, _requiredLevel, _now, _duration, _revision, _coins, _items, _counts, _equipment, _player );
                        LuaAPI.lua_pushstring(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Claim(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _facility = LuaAPI.xlua_tointeger(L, 2);
                    int _revision = LuaAPI.xlua_tointeger(L, 3);
                    double _now = LuaAPI.lua_tonumber(L, 4);
                    int[] _items = (int[])translator.GetObject(L, 5, typeof(int[]));
                    int[] _counts = (int[])translator.GetObject(L, 6, typeof(int[]));
                    string[] _kinds = (string[])translator.GetObject(L, 7, typeof(string[]));
                    ProjectY.Data.EquipmentData _equipment = (ProjectY.Data.EquipmentData)translator.GetObject(L, 8, typeof(ProjectY.Data.EquipmentData));
                    
                        var gen_ret = gen_to_be_invoked.Claim( _facility, _revision, _now, _items, _counts, _kinds, _equipment );
                        LuaAPI.lua_pushstring(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_StackKind_xlua_st_(RealStatePtr L)
        {
		    try {
            
            
            
                
                {
                    string _kind = LuaAPI.lua_tostring(L, 1);
                    
                        var gen_ret = ProjectY.Data.CampData.StackKind( _kind );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Deposit(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _item = LuaAPI.xlua_tointeger(L, 2);
                    int _count = LuaAPI.xlua_tointeger(L, 3);
                    int _capacity = LuaAPI.xlua_tointeger(L, 4);
                    int _revision = LuaAPI.xlua_tointeger(L, 5);
                    ProjectY.Data.EquipmentData _equipment = (ProjectY.Data.EquipmentData)translator.GetObject(L, 6, typeof(ProjectY.Data.EquipmentData));
                    
                        var gen_ret = gen_to_be_invoked.Deposit( _item, _count, _capacity, _revision, _equipment );
                        LuaAPI.lua_pushstring(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Withdraw(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _item = LuaAPI.xlua_tointeger(L, 2);
                    int _count = LuaAPI.xlua_tointeger(L, 3);
                    int _revision = LuaAPI.xlua_tointeger(L, 4);
                    string _kind = LuaAPI.lua_tostring(L, 5);
                    ProjectY.Data.EquipmentData _equipment = (ProjectY.Data.EquipmentData)translator.GetObject(L, 6, typeof(ProjectY.Data.EquipmentData));
                    
                        var gen_ret = gen_to_be_invoked.Withdraw( _item, _count, _revision, _kind, _equipment );
                        LuaAPI.lua_pushstring(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Wait(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _minutes = LuaAPI.xlua_tointeger(L, 2);
                    int _revision = LuaAPI.xlua_tointeger(L, 3);
                    ProjectY.Data.NarrativeData _narrative = (ProjectY.Data.NarrativeData)translator.GetObject(L, 4, typeof(ProjectY.Data.NarrativeData));
                    
                        var gen_ret = gen_to_be_invoked.Wait( _minutes, _revision, _narrative );
                        LuaAPI.lua_pushstring(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_IsOpen(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.IsOpen);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Revision(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.Revision);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_LevelCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.LevelCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_StorageCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.StorageCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_JobCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.JobCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_StoredTotal(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.CampData gen_to_be_invoked = (ProjectY.Data.CampData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.StoredTotal);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
