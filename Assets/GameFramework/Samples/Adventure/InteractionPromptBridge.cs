using UnityEngine;
using ProjectY.UI;

namespace ProjectY.Samples
{
    public static class InteractionPromptBridge
    {
        public static void Track(MainHudView style,UIFollower follower,AdventureRuntimeDemo demo,int kind,int id,int cellIndex)
        {
            if(demo.TryInteractionPoint(kind,id,cellIndex,out var point))style.TrackPoint(follower,demo.WorldCamera,point);
            else style.Untrack(follower);
        }
    }
}
