namespace ProjectY.UI
{
    /// <summary>Reflection bridge for the existing HUD; formatted log semantics remain in Lua.</summary>
    public static class BattleLogPresentation
    {
        public static void Set(BattleHUDView view,bool expanded,string compactText,string fullText,int count)
            => view.SetLog(expanded,compactText,fullText,count);
    }
}
