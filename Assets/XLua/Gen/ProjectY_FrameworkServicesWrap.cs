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
    public class ProjectYFrameworkServicesWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.FrameworkServices);
			Utils.BeginObjectRegister(type, L, translator, 0, 3, 4, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "ReadConfig", _m_ReadConfig);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "LogError", _m_LogError);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Log", _m_Log);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "Player", _g_get_Player);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Adventure", _g_get_Adventure);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Localization", _g_get_Localization);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "UI", _g_get_UI);
            
			
			
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
				if(LuaAPI.lua_gettop(L) == 2 && translator.Assignable<ProjectY.UI.UIHost>(L, 2))
				{
					ProjectY.UI.UIHost _ui = (ProjectY.UI.UIHost)translator.GetObject(L, 2, typeof(ProjectY.UI.UIHost));
					
					var gen_ret = new ProjectY.FrameworkServices(_ui);
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.FrameworkServices constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_ReadConfig(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.FrameworkServices gen_to_be_invoked = (ProjectY.FrameworkServices)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _name = LuaAPI.lua_tostring(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.ReadConfig( _name );
                        LuaAPI.lua_pushstring(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_LogError(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.FrameworkServices gen_to_be_invoked = (ProjectY.FrameworkServices)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _message = LuaAPI.lua_tostring(L, 2);
                    
                    gen_to_be_invoked.LogError( _message );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Log(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.FrameworkServices gen_to_be_invoked = (ProjectY.FrameworkServices)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _message = LuaAPI.lua_tostring(L, 2);
                    
                    gen_to_be_invoked.Log( _message );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Player(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.FrameworkServices gen_to_be_invoked = (ProjectY.FrameworkServices)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.Player);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Adventure(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.FrameworkServices gen_to_be_invoked = (ProjectY.FrameworkServices)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.Adventure);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Localization(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.FrameworkServices gen_to_be_invoked = (ProjectY.FrameworkServices)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.Localization);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_UI(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.FrameworkServices gen_to_be_invoked = (ProjectY.FrameworkServices)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.UI);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
