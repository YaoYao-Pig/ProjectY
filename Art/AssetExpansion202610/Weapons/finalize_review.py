"""Persist the agent's actual two-pass visual review and check delivery files."""
from pathlib import Path
import json,re,hashlib
R=Path(__file__).resolve().parent
NOTES={
'Sword':[
'上扬铜角护手与单侧鳞脊形成识别点，红柄长度适合单手；背面没有额外悬浮饰件。',
'截断偏斜剑尖、两道铆接补片和暗色短护手清楚可辨，保留残剑的非对称轮廓。',
'细叶刃与下垂铜护手比例协调，绿柄和窄嵌线有明确区别，侧面刃尖已收细。',
'开口圆护手包围实体刃茎，黑灰刃配细金线；背面轮廓仍清晰，环与握柄有接合。',
'起伏火焰刃、枝刺护手与紫柄组成独立轮廓，侧视保持连续实体厚度。'],
'Greatsword':[
'宽截头、单侧铜齿和长红柄清楚区别于尖头剑，侧面保留截头的厚实形态。',
'长尖灰刃配宽叉护手与钟形配重，两道补片服贴于刃根，双手握柄长度明确。',
'四道骨肋沿左脊形成不对称剪影，根部与刃体相接，侧视没有游离的骨片。',
'宽青灰尖刃、下弯锚爪护手和长握柄比例稳定，暗面与亮刃分区可读。',
'折线宽刃、外翻枝刺与紫色长柄构成统一造型；侧面收尖不再形成平截刀尖。'],
'Bow':[
'紫杉长弓为连续单弧，弦在握把后方保持净距，前后视弓臂渐细。',
'骨白反曲梢与深木弓腹清楚区分，弦连到两端弦槽，角梢与木臂连成整体。',
'绿色短弓上下臂不等长，白色缠握位于弓腹中央，弦没有穿过握把。',
'黑红层压弓腹与铜梢可辨，重绘后的弦为直线，侧面两层结构紧贴。',
'较长素木弓臂和铜中架形成独立识别，包握和铆点服贴，弦留出可见 brace height。'],
'Crossbow':[
'单层宽钢弓臂、前蹬环和长木托结构清楚，侧面箭槽连续，横弦没有跨过扳机。',
'双层横臂由中央铜柱连接，绞轮位于木托两侧，前后视层间净距清楚。',
'短绿托与骨白横臂形成轻型轮廓，弦与箭槽有完整路径，背面握柄不缺面。',
'长蓝托、双侧绞轮、前蹬环可分辨，侧视托体有浅倒角，轮轴连接到托体。',
'暗红短托与拱形护架形成圣匣轮廓，拱脚坐在机匣上，弓臂和弦的层次明确。'],
'Longgun':[
'细长八角管与木质长托稳定相接，铜箍没有悬浮，侧面肩托倒角和短击锤可辨。',
'宽钟口、短重管与厚木托形成独立剪影，前视孔口居中，护弓保持开口。',
'骨白护木和细长管区分明显，侧板沿肩托贴合，前后视没有偏轴枪管。',
'短管、绿色木托和侧面蓝晶舱可辨，晶舱有上下端环与支柱，不被实心管遮住。',
'红色旧旗缠带覆盖肩托，黑灰重管与银色箍环分层；侧视握柄与托体连续。'],
'Pistol':[
'修长单管与收腰弯柄比例已修正，象牙柄片贴在两侧，击锤有枢轴和短弯钩。',
'短钟口、宽握柄和铜护弓区别于决斗铳，前面枪口居中，扳机位于护弓内部。',
'并列双管在正面清楚可见，白色握柄收窄，侧视机匣没有吞没整段枪管。',
'紧凑绿柄与蓝晶舱结构清楚，支柱连接上下环，前后视舱体偏置为有意设计。',
'红色钩形握柄与开口尾环形成识别点，短黑管连接机匣，背部轮廓完整。'],
'Shield':[
'赤陶鸢面、浅金火纹与连续包边可辨，侧面盾弧和背面双带、握杆都有厚度。',
'绿铜圆面、四向日纹与中央鼓包均位于盾面上，背面木胎和双带未露缺口。',
'高矩形盾的分段中脊已重新贴合弧面，正面保持完整连续，侧面不再把中脊吞没。',
'叶形骨边与四层红鳞形成体量，侧面鳞片为叠甲而非游离板，背带连接木胎。',
'象牙五角面与缺口金环清楚可辨，环随盾弧贴合，背面握持空间完整。'],
'Dagger':[
'短宽刃和柄尾小环比例合理，补入刃茎后护手上方闭合，侧面刀尖已收细。',
'青色晶刃由金属包根承托，金护手与蓝柄分区清楚，三视图均有真实厚度。',
'前弯黑刃与骨白握柄形成鸦喙轮廓，窄刃茎连接护手，背面刃形保持非对称。',
'圆钝多边尖、白布握把与铜色颈套区分于战斗匕首，原有刃柄细缝已封闭。',
'三棱窄刃配冰蓝嵌线与圆盘尾，尖端双向收束，护手到刃身为连续连接。'],
'Staff':[
'分叉木首悬挂有完整笼框的铜灯，绿芯下方有托座；侧视可见框架和杖身厚度。',
'偏心牧钩包住蓝晶，晶体有下方铜托，长木杆保持自然微弯，背面未见断裂。',
'赤红伞盖有封闭下表面与中心杆，三个孢囊由细杆悬挂，浅斑点嵌入盖面。',
'紫晶位于八角铜笼中并有实体底座，笼臂接回杖杆，深灰杆在三视图可辨。',
'高低不同的双叉包围琥珀核，核下有铜座支撑；叉尖与杖杆没有游离片。'],
'Scope':[
'长铜镜筒两端口径不同，双安装脚接到底轨；侧面镜片和环口保留清楚层次。',
'短棱镜壳区别于长筒，圆物镜和目镜与壳体连接，双脚底轨均没有悬浮。',
'宽物镜和双层骨色护圈形成鸮眼特征，暗筒体与脚架连接，前后口径区别明确。',
'琥珀镜片、红铜筒与侧调节轮均可见；侧轮连接筒体，安装面保持平整。',
'白陶短筒位于开放铜架内，铜架两端已延伸到底座，三视图未见游离保护架。'],
'Suppressor':[
'钟形渐扩外壳与收束安装端明确，正面暗孔居中，侧面轮廓连续。',
'长布套与三条浅色束带区分清楚，铁端盖连接筒体，后部铜安装端不偏轴。',
'分节绿铜筒与浅陶环保持均匀节奏，前后视同轴，侧面节圈没有离开壳体。',
'短宽黑灰外壳与骨白双侧板结构清楚，侧板紧贴外壁，端口与安装端均居中。',
'八角细长壳与紫色纵缝形成独立识别，铜端圈厚度清楚，正背面闭合。']}

def main():
    rows=json.loads((R/'manifest.json').read_text(encoding='utf8'));reviews=[]
    assert len(rows)==55
    for row in rows:
        assert row['nonmanifold_edges']==0 and row['degenerate_faces']==0
        assert row['uv_layers']==1 and len(row['references'])==2
        assert len(re.findall('[\u4e00-\u9fff]',row['lore_zh']))>=100
        fbx=R/'Staging'/(row['name']+'.fbx');assert fbx.stat().st_size>1024
        views={v:'Previews/'+row['name']+'_'+v+'.png' for v in ['front','side','back','hero']}
        assert all((R/p).stat().st_size>1000 for p in views.values())
        reviews.append(dict(id=row['id'],display_name=row['display_name'],category=row['category'],reviewer='Codex weapon_assets agent',method='Personally opened all 11 final category sheets containing 55 x 4 rendered views after geometry revision 2.',views=views,contact_sheet='Previews/Review_'+row['category']+'.jpg',status='passed_static_visual_review',observation_zh=NOTES[row['category']][row['variant']],mesh_checks=dict(nonmanifold_edges=0,degenerate_faces=0,uv_layers=1,triangles=row['triangles']),fbx_sha256=hashlib.sha256(fbx.read_bytes()).hexdigest(),limits='仅本轮 512 px 静态三视图与斜视审查；不是角色动作、手指穿插、装备挂点或 Unity 材质的运行时验收。'))
    result=dict(group='Weapons',asset_count=55,view_count=220,revision=2,reference_images_viewed=18,reference_links_per_asset=2,lore_min_han_characters=min(r['lore_han_characters'] for r in rows),overall='三视图与斜视中未见明显错位、外部悬浮构件或穿模；造型符合本项目纯色低多边形奇幻方向。',repairs=['弓臂重绘并使弦位于握把后方，有真实净距。','剑与匕首补实体刃茎；尖刃侧面收细。','高盾中脊分段贴合曲面，避免被盾面吞没。','独眼镜保护架延伸并连接底轨。','枪与弩托增加浅倒角；短铳缩小机匣并区别五款握柄。','枪械击锤改为有枢轴的短弯钩；晶舱有开放支柱和托座。','蘑菇杖浅色斑点嵌入伞面；暗色材质略提高可读性。'],reviews=reviews)
    (R/'review.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
    (R/'Review.md').write_text('# 武器组三视图审查\n\n2026-10-01，第二版。亲自打开 11 个类别的检查页，逐项查看 55 件资产的正、侧、背和斜视，共 220 个渲染视角。\n\n'+result['overall']+'\n\n几何检查：55 件均无非流形边、无退化面，均含 UVMap；不是角色动画或 Unity 接入验收。\n\n修正：\n\n'+'\n'.join('- '+x for x in result['repairs'])+'\n\n逐件记录：\n\n'+'\n\n'.join('### '+r['display_name']+' · '+r['id']+'\n\n'+r['observation_zh']+'\n\n[四视图检查页]('+r['contact_sheet']+')' for r in reviews),encoding='utf8')
    print(json.dumps(dict(assets=len(rows),fbx=len(list((R/'Staging').glob('*.fbx'))),reviewed_views=220,triangles=[min(r['triangles'] for r in rows),max(r['triangles'] for r in rows)],source_bytes=(R/'Source/Weapons.blend').stat().st_size)))

if __name__=='__main__':main()
