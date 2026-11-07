namespace ProjectY.UI
{
    /// <summary>Reflection bridge; resource authority stays in SpellcastingState.</summary>
    public static class SpellcastingPresentation
    {
        public static void SetPoints(CastingPointRing ring, int current, int maximum) => ring.SetPoints(current, maximum);
    }
}
