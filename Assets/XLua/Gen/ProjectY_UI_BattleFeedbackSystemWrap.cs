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
    public class ProjectYUIBattleFeedbackSystemWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.UI.BattleFeedbackSystem);
			Utils.BeginObjectRegister(type, L, translator, 0, 9, 1, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "QueueHealth", _m_QueueHealth);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "QueueImpact", _m_QueueImpact);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "QueueDamage", _m_QueueDamage);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "BindDamageNumbers", _m_BindDamageNumbers);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "UnbindDamageNumbers", _m_UnbindDamageNumbers);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "BindHealth", _m_BindHealth);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "UnbindHealth", _m_UnbindHealth);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Skip", _m_Skip);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Clear", _m_Clear);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "ScreenOffset", _g_get_ScreenOffset);
            
			
			
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
					
					var gen_ret = new ProjectY.UI.BattleFeedbackSystem();
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.UI.BattleFeedbackSystem constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_QueueHealth(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.BattleFeedbackSystem gen_to_be_invoked = (ProjectY.UI.BattleFeedbackSystem)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _actorId = LuaAPI.xlua_tointeger(L, 2);
                    int _healthId = LuaAPI.xlua_tointeger(L, 3);
                    float _fraction = (float)LuaAPI.lua_tonumber(L, 4);
                    
                    gen_to_be_invoked.QueueHealth( _actorId, _healthId, _fraction );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_QueueImpact(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.BattleFeedbackSystem gen_to_be_invoked = (ProjectY.UI.BattleFeedbackSystem)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _shotIndex = LuaAPI.xlua_tointeger(L, 2);
                    bool _critical = LuaAPI.lua_toboolean(L, 3);
                    bool _defeated = LuaAPI.lua_toboolean(L, 4);
                    
                    gen_to_be_invoked.QueueImpact( _shotIndex, _critical, _defeated );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_QueueDamage(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.BattleFeedbackSystem gen_to_be_invoked = (ProjectY.UI.BattleFeedbackSystem)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _actorId = LuaAPI.xlua_tointeger(L, 2);
                    int _amount = LuaAPI.xlua_tointeger(L, 3);
                    int _shotIndex = LuaAPI.xlua_tointeger(L, 4);
                    bool _critical = LuaAPI.lua_toboolean(L, 5);
                    
                    gen_to_be_invoked.QueueDamage( _actorId, _amount, _shotIndex, _critical );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_BindDamageNumbers(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.BattleFeedbackSystem gen_to_be_invoked = (ProjectY.UI.BattleFeedbackSystem)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.UI.DamageNumberAnimation _numbers = (ProjectY.UI.DamageNumberAnimation)translator.GetObject(L, 2, typeof(ProjectY.UI.DamageNumberAnimation));
                    int _actorId = LuaAPI.xlua_tointeger(L, 3);
                    int _healthId = LuaAPI.xlua_tointeger(L, 4);
                    UnityEngine.Font _font = (UnityEngine.Font)translator.GetObject(L, 5, typeof(UnityEngine.Font));
                    
                    gen_to_be_invoked.BindDamageNumbers( _numbers, _actorId, _healthId, _font );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_UnbindDamageNumbers(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.BattleFeedbackSystem gen_to_be_invoked = (ProjectY.UI.BattleFeedbackSystem)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.UI.DamageNumberAnimation _numbers = (ProjectY.UI.DamageNumberAnimation)translator.GetObject(L, 2, typeof(ProjectY.UI.DamageNumberAnimation));
                    
                    gen_to_be_invoked.UnbindDamageNumbers( _numbers );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_BindHealth(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.BattleFeedbackSystem gen_to_be_invoked = (ProjectY.UI.BattleFeedbackSystem)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.UI.HealthBarAnimation _bar = (ProjectY.UI.HealthBarAnimation)translator.GetObject(L, 2, typeof(ProjectY.UI.HealthBarAnimation));
                    int _actorId = LuaAPI.xlua_tointeger(L, 3);
                    int _healthId = LuaAPI.xlua_tointeger(L, 4);
                    float _fraction = (float)LuaAPI.lua_tonumber(L, 5);
                    
                    gen_to_be_invoked.BindHealth( _bar, _actorId, _healthId, _fraction );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_UnbindHealth(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.BattleFeedbackSystem gen_to_be_invoked = (ProjectY.UI.BattleFeedbackSystem)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.UI.HealthBarAnimation _bar = (ProjectY.UI.HealthBarAnimation)translator.GetObject(L, 2, typeof(ProjectY.UI.HealthBarAnimation));
                    
                    gen_to_be_invoked.UnbindHealth( _bar );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Skip(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.BattleFeedbackSystem gen_to_be_invoked = (ProjectY.UI.BattleFeedbackSystem)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.Skip(  );
                    
                    
                    
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
            
            
                ProjectY.UI.BattleFeedbackSystem gen_to_be_invoked = (ProjectY.UI.BattleFeedbackSystem)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.Clear(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_ScreenOffset(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.UI.BattleFeedbackSystem gen_to_be_invoked = (ProjectY.UI.BattleFeedbackSystem)translator.FastGetCSObj(L, 1);
                translator.PushUnityEngineVector2(L, gen_to_be_invoked.ScreenOffset);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
