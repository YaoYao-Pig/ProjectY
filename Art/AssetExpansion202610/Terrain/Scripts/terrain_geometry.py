"""Pure geometry rules shared by initial construction and narrow art revisions."""
import math

def soil_patch(x,y,variant):
    angle=[.25,2.18,-1.04][variant]
    u=x*math.cos(angle)-y*math.sin(angle)
    v=x*math.sin(angle)+y*math.cos(angle)
    # One coherent off-centre deposit; no alternating radial face assignments.
    return u+.16*math.sin(v*3.2+variant*.7) > [.18,.02,-.12][variant]

def magma_rift_geometry():
    vertices=[];faces=[];colors=[]
    def slab(outline,z0,z1,top,side):
        off=len(vertices);n=len(outline)
        vertices.extend((x,y,z0) for x,y in outline)
        vertices.extend((x,y,z1) for x,y in outline)
        faces.append(tuple(off+i for i in reversed(range(n))));colors.append(side)
        faces.append(tuple(off+n+i for i in range(n)));colors.append(top)
        for i in range(n):faces.append((off+i,off+(i+1)%n,off+n+(i+1)%n,off+n+i));colors.append(side)
    # A real flat magma bed contained by four jagged plates, with branching negative space.
    slab([(-.74,-.22),(-.51,-.36),(-.23,-.31),(.0,-.49),(.24,-.42),(.51,-.15),(.76,.02),(.59,.22),(.26,.31),(-.02,.23),(-.31,.18),(-.59,.04)],0,.047,'Lava','LavaDark')
    slab([(-.72,-.18),(-.54,-.34),(-.27,-.3),(-.13,-.17),(-.28,-.08),(-.43,-.1),(-.53,-.04)],.025,.14,'BasaltLight','Basalt')
    slab([(-.66,.05),(-.47,-.01),(-.3,-.02),(-.17,-.08),(-.06,.015),(.15,.095),(.26,.3),(-.04,.34),(-.31,.26),(-.63,.22)],.025,.23,'Basalt','BasaltDark')
    slab([(.13,-.1),(.26,-.12),(.37,-.06),(.54,-.12),(.73,.02),(.61,.2),(.34,.21),(.23,.035)],.025,.18,'BasaltLight','Basalt')
    slab([(-.05,-.46),(.22,-.4),(.46,-.18),(.3,-.21),(.11,-.2),(-.03,-.09),(-.13,-.2)],.025,.115,'Basalt','BasaltDark')
    slab([(-.48,-.05),(-.28,-.07),(-.11,-.04),(.04,.04),(.21,.05),(.22,.075),(.04,.077),(-.12,-.013),(-.29,-.039)],.048,.051,'LavaHot','Lava')
    return vertices,faces,colors
