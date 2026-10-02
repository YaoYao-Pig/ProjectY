"""Bounded asset-pack checks; no Editor launch, project build, or gameplay tests."""
from pathlib import Path
from collections import Counter
import json,re,hashlib
from PIL import Image
base=Path(__file__).parent
project=base.parent.parent
expected={'Terrain':36,'Dungeon':20,'Items':35,'Weapons':55,'Shipwreck':19,'ShipwreckV2':16,'ShipwreckProps':20,'ShipwreckWeapons':10}
audit={'groups':{},'limitations':['Initial four groups remain standalone; Shipwreck is registered and integrated.','Static armor and rings have no character-fit/animation validation.','Dungeon textures retain nonzero periodic-edge residuals.']}
names=set();unique_refs=set();lore_counts=[]
for group,count in expected.items():
    root=base/group;rows=json.loads((root/'manifest.json').read_text(encoding='utf8'))
    assert len(rows)==count,(group,len(rows))
    unity=json.loads((root/'unity_validation.json').read_text(encoding='utf8'))
    umap={r['name']:r for r in unity};assert len(umap)==count
    review=json.loads((root/'review.json').read_text(encoding='utf8'))
    if isinstance(review,list): review_count=len(review)
    elif 'reviews' in review: review_count=len(review['reviews'])
    else:
        assert isinstance(review['assets'],int) and review['manual_review']
        review_count=review['assets']
    assert review_count==count,(group,'review count',review_count)
    for r in rows:
        name=r['name'];assert name not in names;names.add(name)
        assert 2<=len(r['references'])<=5,(name,'references')
        for ref in r['references']:
            url=ref.get('image',ref.get('image_url'));page=ref.get('page',ref.get('page_url'))
            assert url and page,(name,'source links')
            unique_refs.add(url)
            local=ref.get('local_file',ref.get('local_path',ref.get('local')))
            if local is None:local='References/'+ref['id']+'.png'
            local=Path(local);local=local if local.is_absolute() else root/local
            assert local.is_file(),(name,'reference missing',str(local))
            assert Image.open(local).width>=256,(name,'reference width')
        for view in ['front','side','back','hero']:
            path=root/'Previews'/(name+'_'+view+'.png')
            assert path.is_file() and Image.open(path).size==(512,512),(name,view)
        assert (root/'Staging'/(name+'.fbx')).stat().st_size>1024
        assert r['triangles']>0 and r['degenerate_faces']==0 and r['nonmanifold_edges']==0,(name,'mesh')
        assert r['uv_layers']>=1
        assert umap[name]['pass'],(name,'Unity importer',umap[name])
        up=project/'Assets/DynamicAsset/AssetExpansion202610'/group
        assert (up/'Prefabs'/(name+'.prefab')).is_file()
        assert (up/'Models'/(name+'.fbx')).is_file()
        assert (root/'UnityPreviews'/(name+'.png')).is_file()
        if group in ['Items','Weapons','ShipwreckProps','ShipwreckWeapons']:
            assert (up/'Icons'/(name+'.png')).is_file()
            if group!='ShipwreckProps' and r['category']!='food':
                lore=r.get('lore',r.get('lore_zh',''));size=len(re.findall('[\u4e00-\u9fff]',lore))
                assert size>=100,(name,'short lore',size);lore_counts.append(size)
    assert (root/'Source'/(group+'.blend')).stat().st_size>1024
    audit['groups'][group]={'models':count,'categories':dict(Counter(r['category'] for r in rows)),
        'triangles':sum(r['triangles'] for r in rows),'unity_checks_passed':len(unity),
        'three_view_sets':count,'hero_views':count,'model_files':count,'reference_links_per_asset':sorted(set(len(r['references']) for r in rows))}
textures=json.loads((base/'Dungeon/texture_manifest.json').read_text(encoding='utf8'))
assert len(textures)==6
for t in textures:
    assert 2<=len(t['references'])<=5
    assert (base/'Dungeon'/t['file']).is_file()
    assert 'pending' not in t['seam_status']
    for r in t['references']:unique_refs.add(r['image'])
    assert (project/'Assets/DynamicAsset/AssetExpansion202610/Dungeon/Materials'/(t['id']+'.mat')).is_file()
assert len(names)==sum(expected.values())
audit.update(models=len(names),textures=6,icons=120,model_review_images=len(names)*4,
             archived_reference_images=len(unique_refs),long_background_count=len(lore_counts),
             shortest_long_background_han_characters=min(lore_counts),result='passed_asset_pack_checks',
             validation_scope='Files, per-model geometry reports, visual review records, Unity importer bounds/transforms/material checks; no gameplay test suite.')
(base/'audit.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(audit,ensure_ascii=False,indent=2))
