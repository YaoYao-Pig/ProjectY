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
    public class ProjectYUISkillTooltipViewWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.UI.SkillTooltipView);
			Utils.BeginObjectRegister(type, L, translator, 0, 15, 1, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Begin", _m_Begin);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "AddTag", _m_AddTag);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "AddStat", _m_AddStat);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "AddSynergy", _m_AddSynergy);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetNavigation", _m_SetNavigation);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Show", _m_Show);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Hide", _m_Hide);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "ContainsPointer", _m_ContainsPointer);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "KeepOpen", _m_KeepOpen);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "OnPointerEnter", _m_OnPointerEnter);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "OnPointerExit", _m_OnPointerExit);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "TakeLink", _m_TakeLink);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "OnPointerClick", _m_OnPointerClick);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "ClickAt", _m_ClickAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "RebuildLayout", _m_RebuildLayout);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "Visible", _g_get_Visible);
            
			
			
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
					
					var gen_ret = new ProjectY.UI.SkillTooltipView();
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.UI.SkillTooltipView constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Begin(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _title = LuaAPI.lua_tostring(L, 2);
                    string _body = LuaAPI.lua_tostring(L, 3);
                    
                    gen_to_be_invoked.Begin( _title, _body );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_AddTag(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _label = LuaAPI.lua_tostring(L, 2);
                    string _foregroundHtml = LuaAPI.lua_tostring(L, 3);
                    string _backgroundHtml = LuaAPI.lua_tostring(L, 4);
                    
                    gen_to_be_invoked.AddTag( _label, _foregroundHtml, _backgroundHtml );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_AddStat(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _label = LuaAPI.lua_tostring(L, 2);
                    string _value = LuaAPI.lua_tostring(L, 3);
                    string _valueColorHtml = LuaAPI.lua_tostring(L, 4);
                    
                    gen_to_be_invoked.AddStat( _label, _value, _valueColorHtml );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_AddSynergy(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _title = LuaAPI.lua_tostring(L, 2);
                    string _description = LuaAPI.lua_tostring(L, 3);
                    bool _discovered = LuaAPI.lua_toboolean(L, 4);
                    bool _active = LuaAPI.lua_toboolean(L, 5);
                    
                    gen_to_be_invoked.AddSynergy( _title, _description, _discovered, _active );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetNavigation(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    bool _backEnabled = LuaAPI.lua_toboolean(L, 2);
                    string _breadcrumb = LuaAPI.lua_tostring(L, 3);
                    
                    gen_to_be_invoked.SetNavigation( _backEnabled, _breadcrumb );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Show(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    UnityEngine.RectTransform _nextAnchor = (UnityEngine.RectTransform)translator.GetObject(L, 2, typeof(UnityEngine.RectTransform));
                    
                    gen_to_be_invoked.Show( _nextAnchor );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Hide(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.Hide(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_ContainsPointer(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                        var gen_ret = gen_to_be_invoked.ContainsPointer(  );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_KeepOpen(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
			    int gen_param_count = LuaAPI.lua_gettop(L);
            
                if(gen_param_count == 1) 
                {
                    
                        var gen_ret = gen_to_be_invoked.KeepOpen(  );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                if(gen_param_count == 2&& LuaTypes.LUA_TBOOLEAN == LuaAPI.lua_type(L, 2)) 
                {
                    bool _anchorHovered = LuaAPI.lua_toboolean(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.KeepOpen( _anchorHovered );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.UI.SkillTooltipView.KeepOpen!");
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_OnPointerEnter(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    UnityEngine.EventSystems.PointerEventData _data = (UnityEngine.EventSystems.PointerEventData)translator.GetObject(L, 2, typeof(UnityEngine.EventSystems.PointerEventData));
                    
                    gen_to_be_invoked.OnPointerEnter( _data );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_OnPointerExit(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    UnityEngine.EventSystems.PointerEventData _data = (UnityEngine.EventSystems.PointerEventData)translator.GetObject(L, 2, typeof(UnityEngine.EventSystems.PointerEventData));
                    
                    gen_to_be_invoked.OnPointerExit( _data );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_TakeLink(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                        var gen_ret = gen_to_be_invoked.TakeLink(  );
                        LuaAPI.lua_pushstring(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_OnPointerClick(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    UnityEngine.EventSystems.PointerEventData _data = (UnityEngine.EventSystems.PointerEventData)translator.GetObject(L, 2, typeof(UnityEngine.EventSystems.PointerEventData));
                    
                    gen_to_be_invoked.OnPointerClick( _data );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_ClickAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    UnityEngine.Vector2 _screenPosition;translator.Get(L, 2, out _screenPosition);
                    UnityEngine.Camera _camera = (UnityEngine.Camera)translator.GetObject(L, 3, typeof(UnityEngine.Camera));
                    
                        var gen_ret = gen_to_be_invoked.ClickAt( _screenPosition, _camera );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_RebuildLayout(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.RebuildLayout(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Visible(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.UI.SkillTooltipView gen_to_be_invoked = (ProjectY.UI.SkillTooltipView)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.Visible);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
