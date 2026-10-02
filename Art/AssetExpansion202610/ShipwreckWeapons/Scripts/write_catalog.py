from pathlib import Path
import json,re
BASE=Path(__file__).resolve().parents[1]
refpath=BASE/'References/reference_index.json'
refs=json.loads(refpath.read_text(encoding='utf8'))
for r in refs:r['reviewed']=True
refpath.write_text(json.dumps(refs,ensure_ascii=False,indent=2),encoding='utf8')
refmap={r['id']:r for r in refs}
rows=[
('SWW_TidewornCutlass','潮痕短弯刀','Cutlass',['sot_cutlasses','sot_notable'],
'雾礁号的领航员从不肯把这把短刀擦得发亮。刀身偏向一侧的弧度原是为了在狭窄舱道里割开纠缠的缆索，铜护拳则取自她父亲留下的旧罗盘。船沉之夜，她用刀背在桅杆上划下三道潮位刻痕，让困在下层的水手轮流爬出。第三道刻痕完成时海水已经漫过舷窗，短刀也折去一点锋尖。后来打捞者在刀面发现浅青色盐痕，却始终磨不掉那三条深色伤线。幸存船员相信它还记得最后一次退潮的方向，因而宁愿保留缺口，也不愿换上全新的刀刃。',
'侧弯短刀、铜护拳、青色旧罗盘圆护片、三条贴合刀面的深色潮痕。'),
('SWW_SawtoothBoarder','齿浪登船刀','BoardingBlade',['bb_cleaver','sot_cutlasses'],
'这把厚背登船刀属于雾礁号的断缆手，一名在暴风里也能听出绳股将断的老水手。它的锯齿不是工坊装饰，而是他每次换掉崩口后重新锉出的不等长齿峰；外弯的刀头曾经卡住敌船栏杆，为同伴撑住摇晃的跳板。握柄外缠着从救生索上拆下的旧帆布，末端留下半枚船匠钉。海难之后，铁刃一度埋在舱底焦油里，只有铜制锁箍仍露在外面。如今刃背呈现深浅两层颜色，像退潮后湿石上的界线，而那几枚并不整齐的齿仍足以让人认出断缆手的手艺。',
'不等长粗齿、钩状厚刀头、绑帆布短柄、偏置铜锁箍，明确区别弯刀。'),
('SWW_DrownedBellMaul','沉钟战锤','Warhammer',['bb_boom','er_anchor'],
'沉钟战锤的锤头原本挂在雾礁号的艏楼，每到浓雾就由守夜人敲响。一次亡灵登船之后，钟壁留下裂口，钟声也变得沙哑，船匠便把它铸进一副结实的横向铁架，交给失去长枪的守夜人。宽口钟罩仍保留旧钟的内腔，短小钟舌被铜销固定，因此挥舞时不会胡乱碰撞。锤柄上四道浅铜环纪念四次成功救援，最下方的青绿锈斑则来自最后一次浸海。传说它击中幽影时不会发出金铁声，反而像从很深的水下传来一记报平安的钟鸣，提醒持有者仍有人等待归航。',
'横向中空钟罩、内嵌钟舌、另一侧平锤砧、四道纪念铜箍。'),
('SWW_ChainbreakAnchorAxe','断链船锚斧','TwoHandedAxe',['er_anchor','bb_cleaver'],
'雾礁号在黑潮中搁浅时，最后一副小艇锚被拖进船腹，压断了通向下舱的木梯。船匠用备用桅木给它装上双手长柄，又将一侧锚爪磨成宽刃，另一侧残缺的爪尖则原样留下。它既是破开堵门的重斧，也是那夜众人共同搬动锚链的凭证。握位上有两段不同颜色的绑绳，分别来自船长和厨子的腰带；柄尾只剩两环断链，长度不会妨碍行走。打捞者为它起名断链，却发现斧上最顽固的锈总在旧断口处重生，仿佛海底仍有某种力量试图把逃离的人重新拴住。',
'双手长柄、非对称双锚爪、一侧缺爪、两段绑带及短断链。'),
('SWW_TidecatchHarpoon','捕潮鱼叉','Harpoon',['sot_harpoon','sot_trident'],
'捕潮鱼叉曾属于一名拒绝猎杀幼鲸的海猎人。他把旧叉的两枚外齿锻成朝后的短钩，只留下中间一根修长的尖刃，用来挑开黑潮里缠住小艇的怪藻。叉颈上缠着粗救生索，但绳尾已经剪短并收入铜箍，以免登船时牵绊同伴。一次航程中，海猎人用这根长叉把落水的学徒拉回船边，木杆因此留下浅色修补节。雾礁号沉没后，叉尖的铜绿蔓延成潮线一样的层次。新的持有者仍能看见握柄两侧被双手磨暗的地方，知道它最值得传说的功绩曾是救人，而非猎物的大小。',
'修长中刃、后勾双倒刺、叉颈收束索圈、浅色木杆修补节。'),
('SWW_OysterheartDagger','牡蛎剖心匕首','Dagger',['sot_faraway','sot_knife'],
'牡蛎剖心匕首是港口修女送给随船厨娘的礼物，最初只是一把开壳小刀。厨娘在无人岛找到一种会在月光下闭合的灰白巨贝，便请船匠把珍珠层和短钢芯合铸，留下扇贝般略不规则的宽刃。护手像半枚打开的贝壳，能挡住湿滑的手指，柄尾那颗暗淡圆珠据说来自她救活的一只幼贝。风暴来临时，她用这把刀切开绑死伤员的帆布，刀面因此有一道细而永久的暗纹。如今它的尺寸仍像厨房小刀，却在阴冷船舱里保持温润的乳白色，被水手们视作不应轻易拿来争斗的护身物。',
'短而宽的珍珠层刃、扇贝护手、暗绿小握柄、圆珠柄尾与贴面暗纹。'),
('SWW_RopewindArbalest','绞索重弩','Crossbow',['sk_crossbow','sot_harpoon'],
'绞索重弩由雾礁号的木匠和掌帆手共同改制，弩托取自一块已经开裂的舵木，两个铜轮则来自废弃的缆绞盘。掌帆手坚持保留粗绳的外观，说水手在黑暗中摸到熟悉的绳结才不会慌张；木匠则把宽厚弩臂做成略向后掠的船翼，防止它在舱门里磕坏。沉船那夜，这件武器一直守在通往储物舱的转角，直到最后一批粮袋被搬上救生艇。弩身蓝漆被盐水磨得很薄，铜轮边缘仍带着浅绿沉积。故事里它射出的不是诅咒，而是提醒深海掠夺者：船上的东西并不全都属于海底。',
'宽舵木弩托、后掠弩臂、双铜绞盘、粗索连接和前端开口踏环。'),
('SWW_SeaserpentRecurve','海蛇反曲弓','Bow',['er_serpent','sk_glass'],
'海蛇反曲弓的上下两端并不是杀死海蛇后取下的骨头，而是老舵手依照救过他性命的海兽亲手雕成。上梢的蛇首向外张口，下梢则低伏回望，中间的木纹故意保留成游动的弧线。弓背包着几片磨薄的浅色鲸骨，既加固受力处，也让它在昏暗甲板上能被认出。雾礁号曾在无星之夜跟随那条海蛇穿过礁群，舵手因此发誓不把弓对准海中温顺的生命。沉没后，弓弦已经重新接续，旧柄仍被深绿布条紧紧缠住，像一段不愿松开的约定，等待新的船员把它带回有风的地方。',
'S形反曲木臂、上下朝向不同的蛇首、贴合骨背、深绿中心握位。'),
('SWW_LighthouseStaff','守灯人法杖','Staff',['sot_faraway','sot_trident'],
'守灯人法杖来自海边一座已经熄灭的旧灯塔。守塔者随雾礁号出海时，把最后一枚暖黄色灯晶装进六角铜笼，固定在被潮风磨弯的木杖顶端，以便在浓雾中为甲板上的人照明。铜笼每一根支柱都真实承托着尖顶小屋般的罩盖，底座刻痕记录失踪船只的名字，却没有夸耀胜利的纹章。沉船后，灯晶不再耀眼，只留下像炉火余温一样的颜色。拾到它的人据说会梦见潮声中的台阶，沿着光走到尚未淹没的舱门，因此水手把它称为带路的杖，而不是召来风暴的权柄。',
'六角灯塔笼罩、暖黄灯晶、明确承托的铜柱与尖顶，弯木长杖和旧布握位。'),
('SWW_SaltmistHandgun','盐雾短铳','Pistol',['bb_pistol','sot_pistol'],
'盐雾短铳曾是雾礁号信号手的私人物件，宽口铜管和浅木掌柄都比军港制式短铳更加朴素。信号手在柄侧嵌了一块母亲送来的扇贝片，又用蓝灰帆布缠住被海水泡裂的握位；枪口边缘留下的暗色缺痕来自一次跌落甲板的意外。船队在大雾里失散时，他宁愿节省最后的火药，也要让同伴听见归队的方向。后来打捞者只找回这把没有装药的旧短铳，铜面长出浅绿色盐蚀，贝片却仍完整。人们将它作为失散船员的纪念品随身携带，相信它的故事关于回航，而不是关于谁倒在了枪口前。',
'短而宽的喇叭铜口、朴素木掌柄、侧嵌贝片、蓝灰缠带；仅静态幻想外形。')]
catalog=[]
for id,name,cat,rids,lore,design in rows:
    count=len(re.findall(r'[\u4e00-\u9fff]',lore));assert count>=100,(id,count)
    catalog.append(dict(id=id,display_name_zh=name,category=cat,lore_zh=lore,lore_han_count=count,design_zh=design,
      references=[dict(refmap[rid]) for rid in rids],reference_ids=rids,
      literature_reference={'author':'William Morris','title':'The Water of the Wondrous Isles','url':'https://www.gutenberg.org/cache/epub/8778/pg8778-images.html','location':'Part I, Chapter XX; Part II, Chapter I','influence_zh':'魔法舟离岸、孤身渡水和不明岛屿的中古奇幻航行意象；武器与雾礁号故事完全原创。'},
      units='metres',origin_contract='Primary grip center at local zero; Blender Z up, -Y display front; bow aims -X, crossbow and pistol aim -Y; no motion or socket configuration supplied.',
      target_unity_directory='Assets/DynamicAsset/AssetExpansion202610/ShipwreckWeapons/Models'))
(BASE/'catalog.json').write_text(json.dumps(catalog,ensure_ascii=False,indent=2),encoding='utf8')
(BASE/'lore.md').write_text('# 雾礁号武器遗物\n\n'+ '\n\n'.join('## '+r['display_name_zh']+' · '+r['id']+'\n\n'+r['lore_zh']+'\n\n造型对应：'+r['design_zh'] for r in catalog),encoding='utf8')
print(json.dumps({'count':len(catalog),'min_han':min(r['lore_han_count'] for r in catalog),'references_per_weapon':2}))
