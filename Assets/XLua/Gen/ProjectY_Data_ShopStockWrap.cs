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
    public class ProjectYDataShopStockWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.Data.ShopStock);
			Utils.BeginObjectRegister(type, L, translator, 0, 2, 7, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetAt", _m_GetAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Find", _m_Find);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "MerchantId", _g_get_MerchantId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "SiteId", _g_get_SiteId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "LocalNpcId", _g_get_LocalNpcId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "TemplateId", _g_get_TemplateId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Period", _g_get_Period);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "OccupationRecoveryAt", _g_get_OccupationRecoveryAt);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Count", _g_get_Count);
            
			
			
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
					
					var gen_ret = new ProjectY.Data.ShopStock();
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.Data.ShopStock constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.ShopStock gen_to_be_invoked = (ProjectY.Data.ShopStock)translator.FastGetCSObj(L, 1);
            
            
                
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
            
            
                ProjectY.Data.ShopStock gen_to_be_invoked = (ProjectY.Data.ShopStock)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _entry = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.Find( _entry );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_MerchantId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ShopStock gen_to_be_invoked = (ProjectY.Data.ShopStock)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.MerchantId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_SiteId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ShopStock gen_to_be_invoked = (ProjectY.Data.ShopStock)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.SiteId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_LocalNpcId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ShopStock gen_to_be_invoked = (ProjectY.Data.ShopStock)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.LocalNpcId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_TemplateId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ShopStock gen_to_be_invoked = (ProjectY.Data.ShopStock)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.TemplateId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Period(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ShopStock gen_to_be_invoked = (ProjectY.Data.ShopStock)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.Period);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_OccupationRecoveryAt(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.ShopStock gen_to_be_invoked = (ProjectY.Data.ShopStock)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushnumber(L, gen_to_be_invoked.OccupationRecoveryAt);
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
			
                ProjectY.Data.ShopStock gen_to_be_invoked = (ProjectY.Data.ShopStock)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.Count);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
