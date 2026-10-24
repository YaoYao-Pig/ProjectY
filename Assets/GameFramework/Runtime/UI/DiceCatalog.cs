using System;
using UnityEngine;

namespace ProjectY.UI
{
    [CreateAssetMenu(menuName = "Project Y/Dice Catalog")]
    public sealed class DiceCatalog : ScriptableObject
    {
        [Serializable] public sealed class Face
        {
            public int Value;
            public Vector3 Normal, Up, Axis;
            public Quaternion Frame => Quaternion.LookRotation(Normal, Up);
        }
        [Serializable] public sealed class Die
        {
            public string Name;
            public Mesh Visual, Hull;
            public Material[] Materials;
            public Face[] Faces;
            public Face GetFace(int value)
            {
                foreach (var face in Faces) if (face.Value == value) return face;
                throw new ArgumentOutOfRangeException(nameof(value), Name + " has no face " + value);
            }
        }
        public Die[] Dice;
        public Material Aura;
        public Die Get(string name)
        {
            foreach (var die in Dice) if (die.Name == name) return die;
            throw new ArgumentException("Unknown die: " + name);
        }
    }
}
