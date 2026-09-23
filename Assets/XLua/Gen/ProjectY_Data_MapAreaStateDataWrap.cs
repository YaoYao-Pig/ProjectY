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
    public class ProjectYDataMapAreaStateDataWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.Data.MapAreaStateData);
			Utils.BeginObjectRegister(type, L, translator, 0, 18, 11, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetNpcAt", _m_GetNpcAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetMemberIdAt", _m_GetMemberIdAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetMemberCellAt", _m_GetMemberCellAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetKnownAt", _m_GetKnownAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetVisibleAt", _m_GetVisibleAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "GetRouteAt", _m_GetRouteAt);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "IsKnown", _m_IsKnown);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "AddNpc", _m_AddNpc);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "IsNpcOccupied", _m_IsNpcOccupied);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "IsSquadReserved", _m_IsSquadReserved);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "MoveNpc", _m_MoveNpc);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetInteraction", _m_SetInteraction);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Reveal", _m_Reveal);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetRoute", _m_SetRoute);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "DeployMembers", _m_DeployMembers);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "SetSquadRoute", _m_SetSquadRoute);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Stop", _m_Stop);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Advance", _m_Advance);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "NpcCount", _g_get_NpcCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "InteractionKind", _g_get_InteractionKind);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "InteractionId", _g_get_InteractionId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "SiteId", _g_get_SiteId);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "CellIndex", _g_get_CellIndex);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "CellCount", _g_get_CellCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "KnownCount", _g_get_KnownCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "VisibleCount", _g_get_VisibleCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "RemainingSteps", _g_get_RemainingSteps);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "MemberCount", _g_get_MemberCount);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Revision", _g_get_Revision);
            
			
			
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
				if(LuaAPI.lua_gettop(L) == 4 && LuaTypes.LUA_TNUMBER == LuaAPI.lua_type(L, 2) && LuaTypes.LUA_TNUMBER == LuaAPI.lua_type(L, 3) && LuaTypes.LUA_TNUMBER == LuaAPI.lua_type(L, 4))
				{
					int _siteId = LuaAPI.xlua_tointeger(L, 2);
					int _cellCount = LuaAPI.xlua_tointeger(L, 3);
					int _entryIndex = LuaAPI.xlua_tointeger(L, 4);
					
					var gen_ret = new ProjectY.Data.MapAreaStateData(_siteId, _cellCount, _entryIndex);
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.Data.MapAreaStateData constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetNpcAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetNpcAt( _index );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetMemberIdAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetMemberIdAt( _index );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetMemberCellAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetMemberCellAt( _index );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetKnownAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetKnownAt( _index );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetVisibleAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetVisibleAt( _index );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_GetRouteAt(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _index = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.GetRouteAt( _index );
                        LuaAPI.xlua_pushinteger(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_IsKnown(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _cellIndex = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.IsKnown( _cellIndex );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_AddNpc(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _id = LuaAPI.xlua_tointeger(L, 2);
                    int _cell = LuaAPI.xlua_tointeger(L, 3);
                    
                    gen_to_be_invoked.AddNpc( _id, _cell );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_IsNpcOccupied(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _cell = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.IsNpcOccupied( _cell );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_IsSquadReserved(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _cell = LuaAPI.xlua_tointeger(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.IsSquadReserved( _cell );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_MoveNpc(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _id = LuaAPI.xlua_tointeger(L, 2);
                    int _cell = LuaAPI.xlua_tointeger(L, 3);
                    int _patrolCursor = LuaAPI.xlua_tointeger(L, 4);
                    float _pause = (float)LuaAPI.lua_tonumber(L, 5);
                    
                    gen_to_be_invoked.MoveNpc( _id, _cell, _patrolCursor, _pause );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetInteraction(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int _kind = LuaAPI.xlua_tointeger(L, 2);
                    int _id = LuaAPI.xlua_tointeger(L, 3);
                    
                    gen_to_be_invoked.SetInteraction( _kind, _id );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Reveal(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int[] _cells = (int[])translator.GetObject(L, 2, typeof(int[]));
                    
                    gen_to_be_invoked.Reveal( _cells );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetRoute(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int[] _cells = (int[])translator.GetObject(L, 2, typeof(int[]));
                    
                    gen_to_be_invoked.SetRoute( _cells );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_DeployMembers(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int[] _ids = (int[])translator.GetObject(L, 2, typeof(int[]));
                    int[] _cells = (int[])translator.GetObject(L, 3, typeof(int[]));
                    
                    gen_to_be_invoked.DeployMembers( _ids, _cells );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_SetSquadRoute(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    int[] _cells = (int[])translator.GetObject(L, 2, typeof(int[]));
                    
                    gen_to_be_invoked.SetSquadRoute( _cells );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Stop(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    
                    gen_to_be_invoked.Stop(  );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Advance(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    float _deltaTime = (float)LuaAPI.lua_tonumber(L, 2);
                    float _stepSeconds = (float)LuaAPI.lua_tonumber(L, 3);
                    
                        var gen_ret = gen_to_be_invoked.Advance( _deltaTime, _stepSeconds );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_NpcCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.NpcCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_InteractionKind(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.InteractionKind);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_InteractionId(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.InteractionId);
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
			
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.SiteId);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_CellIndex(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.CellIndex);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_CellCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.CellCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_KnownCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.KnownCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_VisibleCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.VisibleCount);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_RemainingSteps(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.RemainingSteps);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_MemberCount(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.MemberCount);
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
			
                ProjectY.Data.MapAreaStateData gen_to_be_invoked = (ProjectY.Data.MapAreaStateData)translator.FastGetCSObj(L, 1);
                LuaAPI.xlua_pushinteger(L, gen_to_be_invoked.Revision);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
