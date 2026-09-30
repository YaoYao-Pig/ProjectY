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
    public class ProjectYDataNarrativeDataWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.Data.NarrativeData);
			Utils.BeginObjectRegister(type, L, translator, 0, 17, 12, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetProgressAt", _m_GetProgressAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetValueKeyAt", _m_GetValueKeyAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetValue", _m_GetValue);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetValue", _m_SetValue);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Status", _m_Status);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Begin", _m_Begin);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Ready", _m_Ready);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Complete", _m_Complete);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "RecordKill", _m_RecordKill);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "KillCount", _m_KillCount);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "AdvanceMinutes", _m_AdvanceMinutes);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetLineAt", _m_GetLineAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "BeginDialogue", _m_BeginDialogue);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "EnterDialogueNode", _m_EnterDialogueNode);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "AddDialogueLine", _m_AddDialogueLine);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "CloseDialogue", _m_CloseDialogue);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Clear", _m_Clear);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "Revision", _g_get_Revision);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Minutes", _g_get_Minutes);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "ProgressCount", _g_get_ProgressCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "ValueCount", _g_get_ValueCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "DialogueOpen", _g_get_DialogueOpen);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "DialogueId", _g_get_DialogueId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "DialogueNodeId", _g_get_DialogueNodeId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "DialogueNpcId", _g_get_DialogueNpcId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "DialogueLocalNpcId", _g_get_DialogueLocalNpcId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "DialogueActorId", _g_get_DialogueActorId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "DialogueVersion", _g_get_DialogueVersion);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "LineCount", _g_get_LineCount);
            
			
			
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
					
					var gen_ret = new ProjectY.Data.NarrativeData();
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.Data.NarrativeData constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetProgressAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetProgressAt( _index );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetValueKeyAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetValueKeyAt( _index );
                        LuaAPI.lua_pushstring(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetValue(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _key = LuaAPI.lua_tostring(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetValue( _key );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetValue(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _key = LuaAPI.lua_tostring(L, 2);
                    int _value = LuaAPI.xlua_tointeger(L, 3);
                    
                    gen_to_be_invoked.SetValue( _key, _value );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Status(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _kind = LuaAPI.lua_tostring(L, 2);
                    int _id = LuaAPI.xlua_tointeger(L, 3);
                    
                        var gen_ret = gen_to_be_invoked.Status( _kind, _id );
                        LuaAPI.lua_pushstring(L, gen_ret);
                    
                    
                    
                    return 1;
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
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _kind = LuaAPI.lua_tostring(L, 2);
                    int _id = LuaAPI.xlua_tointeger(L, 3);
                    
                    gen_to_be_invoked.Begin( _kind, _id );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Ready(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _kind = LuaAPI.lua_tostring(L, 2);
                    int _id = LuaAPI.xlua_tointeger(L, 3);
                    
                    gen_to_be_invoked.Ready( _kind, _id );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Complete(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _kind = LuaAPI.lua_tostring(L, 2);
                    int _id = LuaAPI.xlua_tointeger(L, 3);
                    
                    gen_to_be_invoked.Complete( _kind, _id );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_RecordKill(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _templateId = LuaAPI.xlua_tointeger(L, 2);
                    
                    gen_to_be_invoked.RecordKill( _templateId );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_KillCount(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _kind = LuaAPI.lua_tostring(L, 2);
                    int _id = LuaAPI.xlua_tointeger(L, 3);
                    int _templateId = LuaAPI.xlua_tointeger(L, 4);
                    
                        var gen_ret = gen_to_be_invoked.KillCount( _kind, _id, _templateId );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_AdvanceMinutes(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    double _minutes = LuaAPI.lua_tonumber(L, 2);
                    
                    gen_to_be_invoked.AdvanceMinutes( _minutes );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetLineAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetLineAt( _index );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_BeginDialogue(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _dialogue = LuaAPI.xlua_tointeger(L, 2);
                    int _npc = LuaAPI.xlua_tointeger(L, 3);
                    int _localNpc = LuaAPI.xlua_tointeger(L, 4);
                    int _actor = LuaAPI.xlua_tointeger(L, 5);
                    
                    gen_to_be_invoked.BeginDialogue( _dialogue, _npc, _localNpc, _actor );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_EnterDialogueNode(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _node = LuaAPI.xlua_tointeger(L, 2);
                    
                    gen_to_be_invoked.EnterDialogueNode( _node );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_AddDialogueLine(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _speaker = LuaAPI.lua_tostring(L, 2);
                    string _text = LuaAPI.lua_tostring(L, 3);
                    bool _choice = LuaAPI.lua_toboolean(L, 4);
                    
                    gen_to_be_invoked.AddDialogueLine( _speaker, _text, _choice );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_CloseDialogue(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.CloseDialogue(  );
                    
                    
                    
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
            
            
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.Clear(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Revision(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.Revision);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Minutes(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushnumber(L, gen_to_be_invoked.Minutes);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_ProgressCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.ProgressCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_ValueCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.ValueCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_DialogueOpen(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.DialogueOpen);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_DialogueId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.DialogueId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_DialogueNodeId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.DialogueNodeId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_DialogueNpcId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.DialogueNpcId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_DialogueLocalNpcId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.DialogueLocalNpcId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_DialogueActorId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.DialogueActorId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_DialogueVersion(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.DialogueVersion);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_LineCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.NarrativeData gen_to_be_invoked = (ProjectY.Data.NarrativeData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.LineCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
