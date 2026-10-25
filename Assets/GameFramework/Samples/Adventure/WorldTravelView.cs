using UnityEngine;

namespace ProjectY.Samples
{
    /// <summary>World-map picking and route overlays; no gameplay position or clock ownership.</summary>
    internal static class WorldTravelView
    {
        internal static int Pick(MapPreviewData map,Ray ray)
        {
            int selected=-1;float nearest=float.PositiveInfinity;
            for(int i=0;i<map.Cells.Length;i++)
            {
                if(map.Cells[i].SurfaceCorners!=null)
                {
                    if(MapMountainSurface.TryRaycastCell(map.Cells[i],map.Radius,ray,out var hit) && hit<nearest){selected=i;nearest=hit;}
                    continue;
                }
                var center=map.Cells[i].Position;
                if(map.Cells[i].HasWater)center.y=map.Cells[i].WaterLevel;
                if(!new Plane(Vector3.up,center).Raycast(ray,out float distance) || distance>=nearest)continue;
                var point=ray.GetPoint(distance)-center;float x=Mathf.Abs(point.x),z=Mathf.Abs(point.z),radius=map.Radius;
                if(x<=.866026f*radius && z<=radius && x+1.732051f*z<=1.732051f*radius)
                { selected=i;nearest=distance; }
            }
            return selected;
        }
        private static Vector2 Screen(Camera camera,Vector3 position)
        {var p=camera.WorldToScreenPoint(position+Vector3.up*.4f);return new Vector2(p.x,UnityEngine.Screen.height-p.y);}
        internal static void Draw(Camera camera,AdventureViewData.TravelState travel,Vector3 displayed,GUIStyle label)
        {
            var color=GUI.color;var matrix=GUI.matrix;var from=Screen(camera,displayed);
            GUI.color=travel.Paused?new Color(.73f,.67f,.45f,.75f):new Color(.96f,.77f,.38f,.9f);
            foreach(var point in travel.Route)
            {
                var to=Screen(camera,point);var direction=to-from;
                if(direction.sqrMagnitude>1)
                {
                    GUIUtility.RotateAroundPivot(Mathf.Atan2(direction.y,direction.x)*Mathf.Rad2Deg,from);
                    GUI.DrawTexture(new Rect(from.x,from.y-1.5f,direction.magnitude,3),Texture2D.whiteTexture);GUI.matrix=matrix;
                }
                from=to;
            }
            GUI.color=color;GUI.matrix=matrix;
        }
    }
}
