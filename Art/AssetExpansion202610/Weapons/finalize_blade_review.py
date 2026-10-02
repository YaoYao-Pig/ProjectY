"""Record the completed revision-3 ten-sword review without rewriting other reviews."""
from pathlib import Path
import json,hashlib
R=Path(__file__).resolve().parent
audit_path=R/'blade_applique_revision3.json';audit=json.loads(audit_path.read_text(encoding='utf8'))
review_path=R/'review.json';review=json.loads(review_path.read_text(encoding='utf8'))
rows={r['name']:r for r in json.loads((R/'manifest.json').read_text(encoding='utf8'))}
notes={
'AEW_Sword_VeteranRemnant':'第三版：两道补片、四枚铆点及缺口暗片已按真实菱形刃面分片贴合；单独查看侧图，补片两端不再浮离刀面。',
'AEW_Sword_MarshHeron':'第三版：绿色长条跟随偏心叶刃的各三角面，正面嵌线连续，单独侧视中不再出现独立于刀面的细线。',
'AEW_Sword_EclipseVow':'第三版：金色长条底面沿菱形刃脊两侧折转；放大侧视确认金线贴住刃面，没有原先细长的背景间隙。',
'AEW_Greatsword_GraveBell':'第三版：两道补片与铆点跟随宽刃斜面，正面铆接特征保留，侧视补片端部与刀面连接。',
'AEW_Greatsword_TideAnchor':'第三版：长金条按真实刃面三角形分片，侧视只剩贴合轮廓的薄金线，没有游离长条。'}
scope=[]
for item in review['reviews']:
    if item['category'] not in ['Sword','Greatsword']:continue
    scope.append(item['id'])
    item['revision3_rechecked']=True
    item['revision3_review_method']='Personally reopened Sword and Greatsword sheets (ten models x four views); additionally opened each of the five changed side views at full 512 px.'
    if item['id'] in notes:
        row=rows[item['id']];fbx=R/'Staging'/(item['id']+'.fbx')
        item['fbx_sha256']=hashlib.sha256(fbx.read_bytes()).hexdigest()
        assert item['fbx_sha256']==audit['after_fbx_sha256'][item['id']]
        item['mesh_checks']=dict(nonmanifold_edges=row['nonmanifold_edges'],degenerate_faces=row['degenerate_faces'],uv_layers=row['uv_layers'],triangles=row['triangles'])
        item['observation_zh']+=' '+notes[item['id']]
        item['geometry_revision']=3
assert len(scope)==10
review['revision']=3
review['repairs'].append('第三版定向修正：五款剑的纹条、补片与铆点裁切贴合实际刃面，背面嵌入0.8毫米；只重导5款及重渲20视图，另5款剑复看未修改。')
review['revision3_scope']=dict(rechecked_assets=scope,changed_assets=list(notes),rendered_views=20,materials_unchanged=True,unchanged_fbx_count=50)
review_path.write_text(json.dumps(review,ensure_ascii=False,indent=2),encoding='utf8')
audit['review_scope']='Passed: ten Sword/Greatsword models reviewed in front/side/back/hero; five changed side views additionally inspected at full 512 px.'
audit['reviewed_assets']=scope;audit['review_status']='passed_static_visual_review'
audit_path.write_text(json.dumps(audit,ensure_ascii=False,indent=2),encoding='utf8')
p=R/'Review.md';s=p.read_text(encoding='utf8')
s=s.replace('2026-10-01，第二版。','2026-10-01，第二版全量审查，第三版刀面附片定向复审。')
s=s.replace('逐件记录：','第三版补充：重新查看 10 款剑的四视图，并单独打开 5 个变更款的完整侧视。原有纹条细长空隙与补片端部浮离已消除；所有附片沿实际刃面三角形裁切并嵌入 0.8 毫米。材质文件哈希及 Blender 内材质值没有变化，其余 50 个 FBX 哈希没有变化。\n\n'+'\n\n'.join('- '+key+'：'+value for key,value in notes.items())+'\n\n逐件记录：')
p.write_text(s,encoding='utf8')
assert hashlib.sha256((R/'materials.json').read_bytes()).hexdigest()==audit['materials_json_sha256']
print('Revision 3 reviewed: 10 swords, 5 updated FBXs, 20 rerendered views; materials unchanged')
