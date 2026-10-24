using System;
using ProjectY.Samples;
using UnityEngine;
using UnityEngine.UI;
using XLua;

namespace ProjectY.UI
{
    /// <summary>Shared inventory artwork for small item cards outside the inventory.</summary>
    [LuaCallCSharp, DisallowMultipleComponent]
    public sealed class ItemIconView : MonoBehaviour
    {
        [SerializeField] private EquipmentAssetCatalog catalog;
        [SerializeField] private Image image;

        public bool Show(int itemId, string path)
        {
            if (catalog == null || image == null)
                throw new InvalidOperationException("Item icon requires its catalog and Image bindings.");
            image.sprite = catalog.ItemIcon(itemId, path);
            image.enabled = image.sprite != null;
            return image.enabled;
        }
    }
}
