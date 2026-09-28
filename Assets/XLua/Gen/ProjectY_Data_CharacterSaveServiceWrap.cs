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
    public class ProjectYDataCharacterSaveServiceWrap 
    {
        public static void __Register(RealStatePtr L)
        {
			ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			System.Type type = typeof(ProjectY.Data.CharacterSaveService);
			Utils.BeginObjectRegister(type, L, translator, 0, 3, 3, 0);
			
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Save", _m_Save);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Prepare", _m_Prepare);
			Utils.RegisterFunc(L, Utils.METHOD_IDX, "Apply", _m_Apply);
			
			
			Utils.RegisterFunc(L, Utils.GETTER_IDX, "FilePath", _g_get_FilePath);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "HasSave", _g_get_HasSave);
            Utils.RegisterFunc(L, Utils.GETTER_IDX, "Status", _g_get_Status);
            
			
			
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
				if(LuaAPI.lua_gettop(L) == 3 && translator.Assignable<ProjectY.Data.CharacterAppearanceService>(L, 2) && (LuaAPI.lua_isnil(L, 3) || LuaAPI.lua_type(L, 3) == LuaTypes.LUA_TSTRING))
				{
					ProjectY.Data.CharacterAppearanceService _appearance = (ProjectY.Data.CharacterAppearanceService)translator.GetObject(L, 2, typeof(ProjectY.Data.CharacterAppearanceService));
					string _filePath = LuaAPI.lua_tostring(L, 3);
					
					var gen_ret = new ProjectY.Data.CharacterSaveService(_appearance, _filePath);
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				if(LuaAPI.lua_gettop(L) == 2 && translator.Assignable<ProjectY.Data.CharacterAppearanceService>(L, 2))
				{
					ProjectY.Data.CharacterAppearanceService _appearance = (ProjectY.Data.CharacterAppearanceService)translator.GetObject(L, 2, typeof(ProjectY.Data.CharacterAppearanceService));
					
					var gen_ret = new ProjectY.Data.CharacterSaveService(_appearance);
					translator.Push(L, gen_ret);
                    
					return 1;
				}
				
			}
			catch(System.Exception gen_e) {
				return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
			}
            return LuaAPI.luaL_error(L, "invalid arguments to ProjectY.Data.CharacterSaveService constructor!");
            
        }
        
		
        
		
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _m_Save(RealStatePtr L)
        {
		    try {
            
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
            
            
                ProjectY.Data.CharacterSaveService gen_to_be_invoked = (ProjectY.Data.CharacterSaveService)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.Data.AdventureData _adventure = (ProjectY.Data.AdventureData)translator.GetObject(L, 2, typeof(ProjectY.Data.AdventureData));
                    ProjectY.Data.PlayerData _player = (ProjectY.Data.PlayerData)translator.GetObject(L, 3, typeof(ProjectY.Data.PlayerData));
                    
                    gen_to_be_invoked.Save( _adventure, _player );
                    
                    
                    
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
            
            
                ProjectY.Data.CharacterSaveService gen_to_be_invoked = (ProjectY.Data.CharacterSaveService)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.Data.EquipmentData _current = (ProjectY.Data.EquipmentData)translator.GetObject(L, 2, typeof(ProjectY.Data.EquipmentData));
                    
                        var gen_ret = gen_to_be_invoked.Prepare( _current );
                        translator.Push(L, gen_ret);
                    
                    
                    
                    return 1;
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
            
            
                ProjectY.Data.CharacterSaveService gen_to_be_invoked = (ProjectY.Data.CharacterSaveService)translator.FastGetCSObj(L, 1);
            
            
                
                {
                    ProjectY.Data.PreparedCharacterSave _prepared = (ProjectY.Data.PreparedCharacterSave)translator.GetObject(L, 2, typeof(ProjectY.Data.PreparedCharacterSave));
                    ProjectY.Data.AdventureData _adventure = (ProjectY.Data.AdventureData)translator.GetObject(L, 3, typeof(ProjectY.Data.AdventureData));
                    ProjectY.Data.PlayerData _player = (ProjectY.Data.PlayerData)translator.GetObject(L, 4, typeof(ProjectY.Data.PlayerData));
                    
                    gen_to_be_invoked.Apply( _prepared, _adventure, _player );
                    
                    
                    
                    return 0;
                }
                
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            
        }
        
        
        
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_FilePath(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.CharacterSaveService gen_to_be_invoked = (ProjectY.Data.CharacterSaveService)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushstring(L, gen_to_be_invoked.FilePath);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_HasSave(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.CharacterSaveService gen_to_be_invoked = (ProjectY.Data.CharacterSaveService)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushboolean(L, gen_to_be_invoked.HasSave);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        [MonoPInvokeCallbackAttribute(typeof(LuaCSFunction))]
        static int _g_get_Status(RealStatePtr L)
        {
		    try {
                ObjectTranslator translator = ObjectTranslatorPool.Instance.Find(L);
			
                ProjectY.Data.CharacterSaveService gen_to_be_invoked = (ProjectY.Data.CharacterSaveService)translator.FastGetCSObj(L, 1);
                LuaAPI.lua_pushstring(L, gen_to_be_invoked.Status);
            } catch(System.Exception gen_e) {
                return LuaAPI.luaL_error(L, "c# exception:" + gen_e);
            }
            return 1;
        }
        
        
        
		
		
		
		
    }
}
