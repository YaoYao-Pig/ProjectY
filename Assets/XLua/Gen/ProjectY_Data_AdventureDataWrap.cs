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
    public class ProjectYDataAdventureDataWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.Data.AdventureData);
			Utils.BeginObjectRegister(type, L, translator, 0, 22, 17, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "HasStoryTrigger", _m_HasStoryTrigger);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetJournalAt", _m_GetJournalAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetEventContext", _m_SetEventContext);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Record", _m_Record);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetPartyAt", _m_GetPartyAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "HasVisited", _m_HasVisited);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Reset", _m_Reset);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "AddPartyActor", _m_AddPartyActor);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "PrepareRecruitActor", _m_PrepareRecruitActor);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "AddPreparedRecruit", _m_AddPreparedRecruit);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "BeginEvent", _m_BeginEvent);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "BeginAreaEvent", _m_BeginAreaEvent);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "ResolveChoice", _m_ResolveChoice);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "BeginBattle", _m_BeginBattle);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "BeginAreaBattle", _m_BeginAreaBattle);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "BeginArea", _m_BeginArea);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "BeginEventArea", _m_BeginEventArea);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "LeaveArea", _m_LeaveArea);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "BeginSettlement", _m_BeginSettlement);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "FinishAreaBattle", _m_FinishAreaBattle);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Complete", _m_Complete);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "ReturnToMap", _m_ReturnToMap);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "EventReturnPhase", _g_get_EventReturnPhase);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "StoryTriggerKey", _g_get_StoryTriggerKey);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "JournalCount", _g_get_JournalCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "EventActorId", _g_get_EventActorId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "EventLocation", _g_get_EventLocation);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Battle", _g_get_Battle);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Areas", _g_get_Areas);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Equipment", _g_get_Equipment);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Narrative", _g_get_Narrative);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Seed", _g_get_Seed);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Phase", _g_get_Phase);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "SiteId", _g_get_SiteId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "EventId", _g_get_EventId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "ChoiceId", _g_get_ChoiceId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "AreaEncounterId", _g_get_AreaEncounterId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "ResultText", _g_get_ResultText);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "PartyCount", _g_get_PartyCount);
            
			
			
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
					
					var gen_ret = new ProjectY.Data.AdventureData();
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.Data.AdventureData constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_HasStoryTrigger(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _key = LuaAPI.lua_tostring(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.HasStoryTrigger( _key );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetJournalAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetJournalAt( _index );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetEventContext(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _actorId = LuaAPI.xlua_tointeger(L, 2);
                    string _location = LuaAPI.lua_tostring(L, 3);
                    
                    gen_to_be_invoked.SetEventContext( _actorId, _location );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Record(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _kind = LuaAPI.lua_tostring(L, 2);
                    string _title = LuaAPI.lua_tostring(L, 3);
                    string _body = LuaAPI.lua_tostring(L, 4);
                    string _location = LuaAPI.lua_tostring(L, 5);
                    int _eventId = LuaAPI.xlua_tointeger(L, 6);
                    int _choiceId = LuaAPI.xlua_tointeger(L, 7);
                    int _subjectId = LuaAPI.xlua_tointeger(L, 8);
                    bool _shared = LuaAPI.lua_toboolean(L, 9);
                    
                    gen_to_be_invoked.Record( _kind, _title, _body, _location, _eventId, _choiceId, _subjectId, _shared );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetPartyAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetPartyAt( _index );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_HasVisited(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _siteId = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.HasVisited( _siteId );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Reset(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    uint _seed = LuaAPI.xlua_touint(L, 2);
                    
                    gen_to_be_invoked.Reset( _seed );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_AddPartyActor(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _id = LuaAPI.xlua_tointeger(L, 2);
                    int _templateId = LuaAPI.xlua_tointeger(L, 3);
                    
                        var gen_ret = gen_to_be_invoked.AddPartyActor( _id, _templateId );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_PrepareRecruitActor(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _id = LuaAPI.xlua_tointeger(L, 2);
                    int _templateId = LuaAPI.xlua_tointeger(L, 3);
                    
                        var gen_ret = gen_to_be_invoked.PrepareRecruitActor( _id, _templateId );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_AddPreparedRecruit(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.Data.CombatActorData _actor = (ProjectY.Data.CombatActorData)translator.GetObject(L, 2, typeof(ProjectY.Data.CombatActorData));
                    
                    gen_to_be_invoked.AddPreparedRecruit( _actor );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_BeginEvent(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _siteId = LuaAPI.xlua_tointeger(L, 2);
                    int _eventId = LuaAPI.xlua_tointeger(L, 3);
                    
                    gen_to_be_invoked.BeginEvent( _siteId, _eventId );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_BeginAreaEvent(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _eventId = LuaAPI.xlua_tointeger(L, 2);
                    string _triggerKey = LuaAPI.lua_tostring(L, 3);
                    
                    gen_to_be_invoked.BeginAreaEvent( _eventId, _triggerKey );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_ResolveChoice(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _choiceId = LuaAPI.xlua_tointeger(L, 2);
                    
                    gen_to_be_invoked.ResolveChoice( _choiceId );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_BeginBattle(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.BeginBattle(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_BeginAreaBattle(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _encounterId = LuaAPI.xlua_tointeger(L, 2);
                    
                    gen_to_be_invoked.BeginAreaBattle( _encounterId );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_BeginArea(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _siteId = LuaAPI.xlua_tointeger(L, 2);
                    
                    gen_to_be_invoked.BeginArea( _siteId );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_BeginEventArea(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _siteId = LuaAPI.xlua_tointeger(L, 2);
                    
                    gen_to_be_invoked.BeginEventArea( _siteId );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_LeaveArea(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.LeaveArea(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_BeginSettlement(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.BeginSettlement(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_FinishAreaBattle(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _result = LuaAPI.lua_tostring(L, 2);
                    
                    gen_to_be_invoked.FinishAreaBattle( _result );
                    
                    
                    
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
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _result = LuaAPI.lua_tostring(L, 2);
                    
                    gen_to_be_invoked.Complete( _result );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_ReturnToMap(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.ReturnToMap(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_EventReturnPhase(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushstring(L, gen_to_be_invoked.EventReturnPhase);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_StoryTriggerKey(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushstring(L, gen_to_be_invoked.StoryTriggerKey);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_JournalCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.JournalCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_EventActorId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.EventActorId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_EventLocation(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushstring(L, gen_to_be_invoked.EventLocation);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Battle(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.Battle);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Areas(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.Areas);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Equipment(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.Equipment);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Narrative(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.Narrative);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Seed(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushuint(L, gen_to_be_invoked.Seed);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Phase(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushstring(L, gen_to_be_invoked.Phase);
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
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.SiteId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_EventId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.EventId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_ChoiceId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.ChoiceId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_AreaEncounterId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.AreaEncounterId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_ResultText(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushstring(L, gen_to_be_invoked.ResultText);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_PartyCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.AdventureData gen_to_be_invoked = (ProjectY.Data.AdventureData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.PartyCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
