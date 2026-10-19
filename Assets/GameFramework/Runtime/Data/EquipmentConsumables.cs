using System;

namespace ProjectY.Data
{
    public sealed partial class EquipmentData
    {
        public void ConsumeStack(int itemId, int count)
        {
            ConsumeStackRows(itemId,count);
            Revision++;
        }
    }
}
