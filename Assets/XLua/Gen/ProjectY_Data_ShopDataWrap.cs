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
    public class ProjectYDataShopDataWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.Data.ShopData);
			Utils.BeginObjectRegister(type, L, translator, 0, 7, 4, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetAt", _m_GetAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Find", _m_Find);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Refresh", _m_Refresh);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Open", _m_Open);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Close", _m_Close);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Clear", _m_Clear);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Buy", _m_Buy);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "Active", _g_get_Active);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "IsOpen", _g_get_IsOpen);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Revision", _g_get_Revision);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Count", _g_get_Count);
            
			
			
			Utils.EndObjectRegister(type, L, translator, null, null,
			    null, null, null);

		    Utils.BeginClassRegister(type, L, __CreateInstance, 3, 0, 0);
			Utils.RegisterFunc(L, Utils.CLS_IDX, "For", _m_For_xlua_st_);
            Utils.RegisterFunc(L, Utils.CLS_IDX, "Prepared", _m_Prepared_xlua_st_);
            
			
            
			
			
			
			Utils.EndClassRegister(type, L, translator);
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int __CreateInstance(RealStatePtr L)
        {
            
			try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
				if(LuaAPI.lua_gettop(L) == 1)
				{
					
					var gen_ret = new ProjectY.Data.ShopData();
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.Data.ShopData constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_For_xlua_st_(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
            
                
                {
                    ProjectY.Data.AdventureData _adventure = (ProjectY.Data.AdventureData)translator.GetObject(L, 1, typeof(ProjectY.Data.AdventureData));
                    
                        var gen_ret = ProjectY.Data.ShopData.For( _adventure );
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
                    
                        var gen_ret = ProjectY.Data.ShopData.Prepared( _prepared );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.ShopData gen_to_be_invoked = (ProjectY.Data.ShopData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetAt( _index );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Find(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.ShopData gen_to_be_invoked = (ProjectY.Data.ShopData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _merchant = LuaAPI.xlua_tointeger(L, 2);
                    int _site = LuaAPI.xlua_tointeger(L, 3);
                    int _npc = LuaAPI.xlua_tointeger(L, 4);
                    
                        var gen_ret = gen_to_be_invoked.Find( _merchant, _site, _npc );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Refresh(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.ShopData gen_to_be_invoked = (ProjectY.Data.ShopData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _merchant = LuaAPI.xlua_tointeger(L, 2);
                    int _site = LuaAPI.xlua_tointeger(L, 3);
                    int _npc = LuaAPI.xlua_tointeger(L, 4);
                    int _template = LuaAPI.xlua_tointeger(L, 5);
                    int _period = LuaAPI.xlua_tointeger(L, 6);
                    int[] _entries = (int[])translator.GetObject(L, 7, typeof(int[]));
                    int[] _items = (int[])translator.GetObject(L, 8, typeof(int[]));
                    int[] _counts = (int[])translator.GetObject(L, 9, typeof(int[]));
                    int[] _prices = (int[])translator.GetObject(L, 10, typeof(int[]));
                    
                        var gen_ret = gen_to_be_invoked.Refresh( _merchant, _site, _npc, _template, _period, _entries, _items, _counts, _prices );
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
            
            
                ProjectY.Data.ShopData gen_to_be_invoked = (ProjectY.Data.ShopData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.Data.ShopStock _stock = (ProjectY.Data.ShopStock)translator.GetObject(L, 2, typeof(ProjectY.Data.ShopStock));
                    
                    gen_to_be_invoked.Open( _stock );
                    
                    
                    
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
            
            
                ProjectY.Data.ShopData gen_to_be_invoked = (ProjectY.Data.ShopData)translator.FastGetCSObj(L, 1);
            
            
                
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
            
            
                ProjectY.Data.ShopData gen_to_be_invoked = (ProjectY.Data.ShopData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.Clear(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Buy(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.ShopData gen_to_be_invoked = (ProjectY.Data.ShopData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _entryId = LuaAPI.xlua_tointeger(L, 2);
                    int _count = LuaAPI.xlua_tointeger(L, 3);
                    int _revision = LuaAPI.xlua_tointeger(L, 4);
                    ProjectY.Data.EquipmentData _equipment = (ProjectY.Data.EquipmentData)translator.GetObject(L, 5, typeof(ProjectY.Data.EquipmentData));
                    ProjectY.Data.PlayerData _player = (ProjectY.Data.PlayerData)translator.GetObject(L, 6, typeof(ProjectY.Data.PlayerData));
                    string _kind = LuaAPI.lua_tostring(L, 7);
                    int _ammo = LuaAPI.xlua_tointeger(L, 8);
                    int _capacity = LuaAPI.xlua_tointeger(L, 9);
                    int _rounds = LuaAPI.xlua_tointeger(L, 10);
                    
                        var gen_ret = gen_to_be_invoked.Buy( _entryId, _count, _revision, _equipment, _player, _kind, _ammo, _capacity, _rounds );
                        LuaAPI.lua_pushstring(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Active(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ShopData gen_to_be_invoked = (ProjectY.Data.ShopData)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.Active);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_IsOpen(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ShopData gen_to_be_invoked = (ProjectY.Data.ShopData)translator.FastGetCSObj(L, 1);
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
			
                ProjectY.Data.ShopData gen_to_be_invoked = (ProjectY.Data.ShopData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.Revision);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Count(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ShopData gen_to_be_invoked = (ProjectY.Data.ShopData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.Count);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
