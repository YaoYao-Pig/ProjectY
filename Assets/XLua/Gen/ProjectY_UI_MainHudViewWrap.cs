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
    public class ProjectYUIMainHudViewWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.UI.MainHudView);
			Utils.BeginObjectRegister(type, L, translator, 0, 9, 2, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetCharacterSkillBar", _m_SetCharacterSkillBar);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Prepare", _m_Prepare);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetMode", _m_SetMode);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Track", _m_Track);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "TrackScreen", _m_TrackScreen);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Untrack", _m_Untrack);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetHealth", _m_SetHealth);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "ApplyLayout", _m_ApplyLayout);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "UpdateFollowers", _m_UpdateFollowers);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "Font", _g_get_Font);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "WorldLeftInset", _g_get_WorldLeftInset);
            
			
			
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
					
					var gen_ret = new ProjectY.UI.MainHudView();
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.UI.MainHudView constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetCharacterSkillBar(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.MainHudView gen_to_be_invoked = (ProjectY.UI.MainHudView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    UnityEngine.RectTransform _value = (UnityEngine.RectTransform)translator.GetObject(L, 2, typeof(UnityEngine.RectTransform));
                    
                    gen_to_be_invoked.SetCharacterSkillBar( _value );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Prepare(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.MainHudView gen_to_be_invoked = (ProjectY.UI.MainHudView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.Prepare(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetMode(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.MainHudView gen_to_be_invoked = (ProjectY.UI.MainHudView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    bool _explore = LuaAPI.lua_toboolean(L, 2);
                    bool _showNavigation = LuaAPI.lua_toboolean(L, 3);
                    
                    gen_to_be_invoked.SetMode( _explore, _showNavigation );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Track(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.MainHudView gen_to_be_invoked = (ProjectY.UI.MainHudView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.UI.UIFollower _follower = (ProjectY.UI.UIFollower)translator.GetObject(L, 2, typeof(ProjectY.UI.UIFollower));
                    UnityEngine.Camera _camera = (UnityEngine.Camera)translator.GetObject(L, 3, typeof(UnityEngine.Camera));
                    UnityEngine.Transform _target = (UnityEngine.Transform)translator.GetObject(L, 4, typeof(UnityEngine.Transform));
                    
                    gen_to_be_invoked.Track( _follower, _camera, _target );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_TrackScreen(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.MainHudView gen_to_be_invoked = (ProjectY.UI.MainHudView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.UI.UIFollower _follower = (ProjectY.UI.UIFollower)translator.GetObject(L, 2, typeof(ProjectY.UI.UIFollower));
                    UnityEngine.Vector2 _point;translator.Get(L, 3, out _point);
                    
                    gen_to_be_invoked.TrackScreen( _follower, _point );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Untrack(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.MainHudView gen_to_be_invoked = (ProjectY.UI.MainHudView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.UI.UIFollower _follower = (ProjectY.UI.UIFollower)translator.GetObject(L, 2, typeof(ProjectY.UI.UIFollower));
                    
                    gen_to_be_invoked.Untrack( _follower );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetHealth(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.MainHudView gen_to_be_invoked = (ProjectY.UI.MainHudView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    UnityEngine.UI.Image _fill = (UnityEngine.UI.Image)translator.GetObject(L, 2, typeof(UnityEngine.UI.Image));
                    float _fraction = (float)LuaAPI.lua_tonumber(L, 3);
                    
                    gen_to_be_invoked.SetHealth( _fill, _fraction );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_ApplyLayout(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.MainHudView gen_to_be_invoked = (ProjectY.UI.MainHudView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.ApplyLayout(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_UpdateFollowers(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.MainHudView gen_to_be_invoked = (ProjectY.UI.MainHudView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.UpdateFollowers(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Font(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.UI.MainHudView gen_to_be_invoked = (ProjectY.UI.MainHudView)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.Font);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_WorldLeftInset(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.UI.MainHudView gen_to_be_invoked = (ProjectY.UI.MainHudView)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushnumber(L, gen_to_be_invoked.WorldLeftInset);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
