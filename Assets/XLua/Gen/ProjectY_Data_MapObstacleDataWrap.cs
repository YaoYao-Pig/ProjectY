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
    public class ProjectYDataMapObstacleDataWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.Data.MapObstacleData);
			Utils.BeginObjectRegister(type, L, translator, 0, 13, 3, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Exert", _m_Exert);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "IsInitialized", _m_IsInitialized);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Count", _m_Count);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Get", _m_Get);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Add", _m_Add);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "CompleteInitialization", _m_CompleteInitialization);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "AtCell", _m_AtCell);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "IsBlocked", _m_IsBlocked);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Request", _m_Request);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Begin", _m_Begin);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Resolve", _m_Resolve);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Cancel", _m_Cancel);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Clear", _m_Clear);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "CurrentSiteId", _g_get_CurrentSiteId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "CurrentId", _g_get_CurrentId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "RequestedId", _g_get_RequestedId);
            
			
			
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
					
					var gen_ret = new ProjectY.Data.MapObstacleData();
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.Data.MapObstacleData constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Exert(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.Data.CombatActorData _actor = (ProjectY.Data.CombatActorData)translator.GetObject(L, 2, typeof(ProjectY.Data.CombatActorData));
                    int _amount = LuaAPI.xlua_tointeger(L, 3);
                    
                        var gen_ret = gen_to_be_invoked.Exert( _actor, _amount );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_IsInitialized(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _site = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.IsInitialized( _site );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Count(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _site = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.Count( _site );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Get(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _site = LuaAPI.xlua_tointeger(L, 2);
                    int _id = LuaAPI.xlua_tointeger(L, 3);
                    
                        var gen_ret = gen_to_be_invoked.Get( _site, _id );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Add(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _site = LuaAPI.xlua_tointeger(L, 2);
                    int _rule = LuaAPI.xlua_tointeger(L, 3);
                    bool _blocks = LuaAPI.lua_toboolean(L, 4);
                    int[] _cells = (int[])translator.GetObject(L, 5, typeof(int[]));
                    int[] _items = (int[])translator.GetObject(L, 6, typeof(int[]));
                    int[] _counts = (int[])translator.GetObject(L, 7, typeof(int[]));
                    
                    gen_to_be_invoked.Add( _site, _rule, _blocks, _cells, _items, _counts );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_CompleteInitialization(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _site = LuaAPI.xlua_tointeger(L, 2);
                    
                    gen_to_be_invoked.CompleteInitialization( _site );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_AtCell(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _site = LuaAPI.xlua_tointeger(L, 2);
                    int _cell = LuaAPI.xlua_tointeger(L, 3);
                    
                        var gen_ret = gen_to_be_invoked.AtCell( _site, _cell );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_IsBlocked(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _site = LuaAPI.xlua_tointeger(L, 2);
                    int _cell = LuaAPI.xlua_tointeger(L, 3);
                    
                        var gen_ret = gen_to_be_invoked.IsBlocked( _site, _cell );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Request(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _site = LuaAPI.xlua_tointeger(L, 2);
                    int _id = LuaAPI.xlua_tointeger(L, 3);
                    
                    gen_to_be_invoked.Request( _site, _id );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Begin(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _site = LuaAPI.xlua_tointeger(L, 2);
                    int _id = LuaAPI.xlua_tointeger(L, 3);
                    
                    gen_to_be_invoked.Begin( _site, _id );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Resolve(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    bool _success = LuaAPI.lua_toboolean(L, 2);
                    
                    gen_to_be_invoked.Resolve( _success );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Cancel(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.Cancel(  );
                    
                    
                    
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
            
            
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.Clear(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_CurrentSiteId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.CurrentSiteId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_CurrentId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.CurrentId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_RequestedId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapObstacleData gen_to_be_invoked = (ProjectY.Data.MapObstacleData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.RequestedId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
