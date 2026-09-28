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
    public class ProjectYDataCharacterAppearanceServiceWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.Data.CharacterAppearanceService);
			Utils.BeginObjectRegister(type, L, translator, 0, 4, 1, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Create", _m_Create);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Apply", _m_Apply);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Race", _m_Race);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "HasRace", _m_HasRace);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "Rules", _g_get_Rules);
            
			
			
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
					
					var gen_ret = new ProjectY.Data.CharacterAppearanceService();
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.Data.CharacterAppearanceService constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Create(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CharacterAppearanceService gen_to_be_invoked = (ProjectY.Data.CharacterAppearanceService)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.Data.CombatActorData _actor = (ProjectY.Data.CombatActorData)translator.GetObject(L, 2, typeof(ProjectY.Data.CombatActorData));
                    int _seed = LuaAPI.xlua_tointeger(L, 3);
                    string _race = LuaAPI.lua_tostring(L, 4);
                    string _sex = LuaAPI.lua_tostring(L, 5);
                    
                    gen_to_be_invoked.Create( _actor, _seed, _race, _sex );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Apply(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CharacterAppearanceService gen_to_be_invoked = (ProjectY.Data.CharacterAppearanceService)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.Data.CombatActorData _actor = (ProjectY.Data.CombatActorData)translator.GetObject(L, 2, typeof(ProjectY.Data.CombatActorData));
                    string _json = LuaAPI.lua_tostring(L, 3);
                    
                    gen_to_be_invoked.Apply( _actor, _json );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Race(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CharacterAppearanceService gen_to_be_invoked = (ProjectY.Data.CharacterAppearanceService)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.Data.CombatActorData _actor = (ProjectY.Data.CombatActorData)translator.GetObject(L, 2, typeof(ProjectY.Data.CombatActorData));
                    
                        var gen_ret = gen_to_be_invoked.Race( _actor );
                        LuaAPI.lua_pushstring(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_HasRace(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CharacterAppearanceService gen_to_be_invoked = (ProjectY.Data.CharacterAppearanceService)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    string _race = LuaAPI.lua_tostring(L, 2);
                    
                        var gen_ret = gen_to_be_invoked.HasRace( _race );
                        LuaAPI.lua_pushboolean(L, gen_ret);
                    
                    
                    
                    return 1;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Rules(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.CharacterAppearanceService gen_to_be_invoked = (ProjectY.Data.CharacterAppearanceService)translator.FastGetCSObj(L, 1);
                translator.Push(L, gen_to_be_invoked.Rules);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
