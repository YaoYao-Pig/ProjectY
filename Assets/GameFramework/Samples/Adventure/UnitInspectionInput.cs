namespace ProjectY.Samples
{
    /// <summary>Details-panel input ownership; authoritative inspection state lives in AdventureData.</summary>
    public static class UnitInspectionInput
    {
        public static void SetOpen(AdventureRuntimeDemo demo, bool open) => demo.UnitDetailsOpen = open;
    }
    public sealed partial class AdventureRuntimeDemo
    {
        internal bool UnitDetailsOpen { get; set; }
    }
}
