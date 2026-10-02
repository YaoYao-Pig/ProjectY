"""Read-only texture seam statistics; does not modify any generated pixel."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parent
rows=json.loads((ROOT/'texture_manifest.json').read_text(encoding='utf8'))
refs={x['id']:x for x in json.loads((ROOT/'references.json').read_text(encoding='utf8'))}
for row in rows:
    image=Image.open(ROOT/row['file']).convert('RGB');a=np.asarray(image,dtype=np.float32)
    sx=np.abs(a[:,0]-a[:,-1]).mean();sy=np.abs(a[0]-a[-1]).mean()
    ix=np.abs(a[:,1:]-a[:,:-1]).mean();iy=np.abs(a[1:]-a[:-1]).mean()
    row.update(dimensions=list(image.size),color_space='sRGB',unity_texture_type='Default',wrap_mode='Repeat',filter_mode='Trilinear',mipmaps=True,physical_tile_metres=2,
               shader='Universal Render Pipeline/Lit',metallic=0,smoothness=.12,base_color=[1,1,1,1],
               edge_difference_rgb255=dict(horizontal=float(sx),vertical=float(sy),interior_horizontal=float(ix),interior_vertical=float(iy)),
               seam_status='numeric_checked_visual_pending',references=[refs[x] if isinstance(x,str) else x for x in row['references']])
    print(row['id'],image.size,'edge',round(float(sx),2),round(float(sy),2),'interior',round(float(ix),2),round(float(iy),2))
(ROOT/'texture_manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
