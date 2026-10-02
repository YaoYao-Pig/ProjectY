"""Original weapon design catalogue and a reproducible reference archive."""
from pathlib import Path
import json, re, urllib.request, concurrent.futures
ROOT=Path(__file__).resolve().parent
REFS=[
('souls_blades','Dark Souls: Design Works / Astora, Quelaag, Zweihander','https://www.pinterest.com/pin/423690277438927740/','https://i.pinimg.com/736x/ed/ec/2b/edec2b9592f53a53348815af07fc2517.jpg','直剑的收束刃型、十字护手；有机刃与常规钢刃形成剪影对比。'),
('souls_gwyn','Dark Souls: Design Works / Gwyn greatsword','https://www.pinterest.com/pin/dark-souls-concept-art-gwyns-greatsword-concept-art--392376186282148317/','https://i.pinimg.com/1200x/fb/e0/d9/fbe0d9e4d89582488a72e02a70234752.jpg','宽刃、窄柄、末端配重的质量分配；不复制原作徽记。'),
('elden_daggers','Elden Ring Official Art Book Vol. 2 / daggers','https://jumpichiban.com/es/products/elden-ring-official-art-book-volume-2','https://jumpichiban.com/cdn/shop/files/EldenRingOfficialArtBook-Volume2_14.png?v=1768355397&width=1524','匕首的短小刃体、骨质与矿物材质分区。'),
('souls_knives','Dark Souls III / weapon concept collection','https://www.pinterest.com/pin/512777107563079038/','https://s-media-cache-ak0.pinimg.com/originals/2d/ed/95/2ded95b68b7a638aa5e2a945cf3b36f8.jpg','不对称刀身、弯护手和旧金属比例。'),
('hornbow','Elden Ring / Horn Bow','https://www.vgbaike.com/elden_ring/baike14959','https://media.vgbaike.com/database/2022/0620/20/33203_oqnzfv.png','兽角反曲弓梢、握把与弦线的净空关系。'),
('shortbow','Elden Ring / Longbow item card','https://www.gamersky.com/handbook/202401/1694907_252.shtml','https://img1.gamersky.com/image2024/01/20240110_apl_435_24/13920_S.jpg','传统木长弓的长臂比例、弦距与包握区。'),
('arbalest','Elden Ring / heavy crossbow screenshot','https://note.com/pyon_pyoko/n/n660826ddbece','https://assets.st-note.com/img/1665331647999-N3RZHQW5Ug.jpg','横弓臂、纵向箭槽和肩托分层。'),
('avelyn','Dark Souls / Avelyn','https://darksouls.wikidot.com/avelyn','https://i.imgur.com/Bs79j4D.jpg','装饰性重复弓臂与木托，保持箭路连续。'),
('bloodborne_guns','Bloodborne Official Design Art Works / firearms spread','https://www.animebooks.com/blofartwoart.html','https://sep.turbifycdn.com/ay/animebooks-com/bloodborne-official-art-works-art-book-12.gif','哥特长枪、钟口枪管和手枪木握把；取比例而不复制机构。'),
('hunter_pistol','Bloodborne / Hunter blunderbuss screenshot','https://www.gamedeveloper.com/design/hunter-s-pistol','https://eu-images.contentstack.com/v3/assets/blt740a130ae3c5d529/blt3ab1d9a2f9486e31/650e86df0d64cd4b7ab4a325/shot4.png','长枪管、深色木柄与旧银结构的视觉层次。'),
('metro_rifle','Metro Exodus / Valve promotional render','https://shazoo.ru/2019/01/22/75076/postapokalipticheskoe-oruzhie-v-novom-trejlere-metro-exodus','https://cdn.shazoo.ru/315240_0RLeaKXvKl_metro_exodus_the_valve_nologo.jpg','镜体与安装脚分离、包布握点；仅借鉴配件结构可读性。'),
('metro_optics','Metro Exodus / workbench scope view','https://www.gamepressure.com/metro-exodus/beginners-guide/zcbe4a','https://www.gamepressure.com/metro-exodus/gfx/word/27742296.jpg','大物镜、小目镜、宽调节轮与两只安装脚的结构层次。'),
('metro_silenced','Metro Exodus / customized revolver','https://www.gamersyde.com/news_the_weaponry_in_metro_exodus-20648_en.html','https://images.gamersyde.com/image_metro_exodus-39825-3881_0001.jpg','可拆筒体的安装端、外壳节段与旧皮革。'),
('metro_silenced_two','Bloodborne / Ludwig rifle and repeating pistol concept','https://www.pinterest.com/pin/507217976789031338/','https://i.pinimg.com/736x/22/de/c6/22dec66be832e00d5544fd867d5804ae.jpg','细窄接口和渐变枪口外壳的层次；借鉴哥特工业外观而非现实消声机构。'),
('kite','Elden Ring / Kite Shield','https://www.vgbaike.com/elden_ring/item33098','https://media.vgbaike.com/database/2022/0620/20/33098_n5ydyd.png','盾缘厚度、肩宽与下尖比例。'),
('twinbird','Elden Ring / Twinbird Kite Shield','https://note.com/pyon_pyoko/n/n528fd7e9bae7','https://assets.st-note.com/img/1668699018303-D1tFh4ZJlL.jpg','有限双色纹章分区和连续金属包边。'),
('academy','Elden Ring / Academy Glintstone Staff','https://www.vgbaike.com/elden_ring/baike14925','https://media.vgbaike.com/database/2022/0620/20/33169_sggr7w.png','细长木杆与嵌套晶石，头部支撑结构。'),
('lusat','Elden Ring / Lusat Glintstone Staff','https://www.vgbaike.com/elden_ring/baike14928','https://media.vgbaike.com/database/2022/0620/20/33172_o0lknt.png','粗晶簇与扭曲杖杆，集中视觉焦点。')]
FAMILY_REFS={'Sword':['souls_blades','souls_gwyn'],'Greatsword':['souls_gwyn','souls_blades'],'Bow':['hornbow','shortbow'],'Crossbow':['arbalest','avelyn'],'Longgun':['bloodborne_guns','metro_rifle'],'Pistol':['bloodborne_guns','hunter_pistol'],'Shield':['kite','twinbird'],'Dagger':['elden_daggers','souls_knives'],'Staff':['academy','lusat'],'Scope':['metro_rifle','metro_optics'],'Suppressor':['metro_silenced','metro_silenced_two']}
LITERATURE=[dict(id='elfland',title="Lord Dunsany, The King of Elfland's Daughter, chapters II–III",url='https://www.gutenberg.org/cache/epub/61077/pg61077-images.html',note='小说中以天外金属、歌与符文铸剑，抵御凡间兵刃无法抵挡之物；仅参考材料与魔法之间的因果关系，下面故事全部原创。'),dict(id='beowulf',title='Beowulf, dragon battle',url='https://www.gutenberg.org/files/981/981-h/981-h.htm',note='中世纪史诗而非小说：屠龙用铁盾、战斗中断裂的剑，为烧痕、修复与代价提供叙事参考。')]
DESIGNS={
'Sword':[
('DragonTithe','龙税','赤铜龙角护手、单侧齿状鳞脊、灰钢刃','赤崖村每年要向盘踞铜矿的幼龙献出一炉好铁。铁匠的女儿终于随猎队夺回矿井，却拒绝把龙首悬在城门上。她把脱落的角磨成护手，用背鳞加固剑根，让红铜色的锻缝留在灰刃之间。剑柄仍缠着父亲的旧围裙，尾端那枚不对称铜钉是最后一年的贡税。村民说它只属于肯为他人守住炉火的人，任何拿它征税的领主都握不稳。'),
('VeteranRemnant','归营残锋','断尖、修补横夹、皮条握把','白桥守军撤退时，老兵赫辛用佩剑卡住吊桥绞盘，替难民争得最后一炷香。绞齿咬去剑尖，也在剑身留下三道斜缺口。他没有换剑，只请村匠铆上两片铁夹，把失去的尖端磨成偏斜的短锋。每次回营，他都会在护手上系一小段旧绷带，提醒新兵先抬走伤者。如今皮革已被掌心磨亮，剑的分量却恰好适合一个不再追赶勋章的人。'),
('MarshHeron','泽鹭','细长叶形剑、弯喙护手、青铜叶饰','盐沼的摆渡人不向迷途者索钱，只收一根能浮在水上的羽毛。渡口被沉尸围困的那年，一位无名旅客留下这柄狭长的叶形剑，护手向两侧弯成鹭喙，青铜在潮气中生出浅绿斑纹。守渡人用它割断沉船的缆绳，放走所有被困灵魂。剑脊保留水草般的浅沟，柄尾悬着空铜环；潮涨时铜环轻响，像在数尚未归岸的客人。'),
('EclipseVow','蚀誓','黑钢菱刃、圆环护手、金色截面','群星修院曾要求每个守门骑士发誓，日蚀之时绝不离岗。年轻的伊萝却在黑昼中开门救回山下的孩子，因此被抹去名字。她的仪剑被熏成乌黑，只有磨开的刃线仍露出银色，断开的圆环护手象征那道不完整的誓约。孩子们后来把门闩上的铜片钉在剑根，刻上新名字。剑不再为修院站岗，而为任何在黑暗里敲门的人守夜。'),
('PilgrimFlame','朝灯','火焰曲刃、短直护手、象牙配重','西行巡礼路没有永不熄灭的圣火，只有驿站间互相传递的一盏小灯。末任护灯者把灯台熔进剑脊，铸成温和起伏的火焰刃，避免长途步行时挂住衣袍。象牙色柄头取自早已倒塌的路碑，并不属于任何圣兽。剑根的旧金套箍磨得发暗，仍能看见换手留下的凹痕。巡礼者相信，真正的祝福不是烈焰，而是有人愿意把余光留给后来者。')],
'Greatsword':[
('KilnBreaker','裂窑','宽截头巨刃、铜箍、煤黑剑脊','矮人窑城被岩浆封住出口时，守炉人把铸模尚未冷透的闸刀扛上肩头，砸开通往旧风井的石墙。获救工匠为他磨出双刃，却保留宽大的截头和厚重铜箍，因为那些焦黑色斑块记着每一次撞击。长柄足够双手换握，配重由废炉锤铸成。它从未受过国王的册封；在窑城，谁能用这柄巨剑为别人打开一条路，谁便有资格坐在长桌首席。'),
('GraveBell','墓钟','长尖巨剑、宽叉护手、暗铜钟形柄尾','北陵的钟楼倒在冬夜，埋住了替亡者守灯的敲钟人。徒弟从碎钟里挑出最沉的一块，锻成宽叉护手，把师傅的墓碑铁钉封进长剑柄尾。银灰剑刃没有华丽铭文，只有沿中脊逐渐收束的暗色沟槽。每逢送葬，徒弟将剑竖在墓旁，让风穿过叉间。人们听见的并非钟声，却总能在那一瞬想起逝者说过的一句平常话。'),
('DragonRib','山龙肋','不对称骨脊、厚叶形黑刃','猎王宣称自己斩杀了山龙，实际上是龙在雪崩中护住了他的军队。幸存的侍从把一截龙肋锻接到黑钢剑背，以巨大而不对称的轮廓揭露这段被改写的历史。骨白的支棱只长在钝脊，锋口仍是连续钢刃，长柄包覆深红旧皮。侍从带着它离开王城，遇见歌者便讲出真相。巨剑沉重，恰如一个人不得不替许多人背负的羞愧。'),
('TideAnchor','潮锚','弧肩巨剑、锚形护手、青灰宽刃','海堤守卫最后一次出航时，船上没有余粮，只有一座即将沉没的修道院送来的铁锚。风暴过后，幸存者把锚重新锻成宽刃巨剑，护手依然保留向下弯曲的双爪。剑面青灰，铜铆钉被盐水咬出深色轮廓；两手握住长柄时，仍能感觉到旧锚链的刻纹。它被传给负责最后撤离的守卫，提醒持有者，能把人留在岸上的力量比征服海洋更值得敬畏。'),
('ThornCrown','荆王','折线双刃、枝刺护手、深紫织带','荆棘王国选出第一位平民女王时，贵族拒绝交出加冕宝剑。园丁们便以拆下的铁栅栏铸成新剑，把门顶的枝刺做成护手，将紫色围裙裁成握带。锻造不够均匀，宽刃上仍有节奏分明的折线，却能让远处的人一眼认出这件朴素王器。女王后来把它留在议事厅门外，任何申诉者都可以触摸。荆棘没有消失，只是终于转向了欺压他人的手。')],
'Bow':[
('YewWarden','紫杉守望','高挑长弓、素木弓臂、铜弦槽','山口的守林家族从不砍伐活着的紫杉，只等雷雨替他们选择枝干。这张长弓出自同一棵被雷击开的老树，弓臂从厚握把平缓收细，浅铜弦槽护住两端易裂的木纹。第一任弓手曾在暴雪里守了三日，只为让羊群顺利越岭。他没有留下战绩，弓把上却刻着小小的羊角记号。后来的守望者每年更换弓弦，始终保留那层被雨水磨亮的旧木色。'),
('MoonAntler','月鹿','象牙反曲弓梢、暗木中段','月井旁的白鹿每隔七年落一次角，守井人把落角分给七座村庄。失去猎场的少女用其中两截与黑桦胶合，制成短而有力的反曲弓，尖梢像半轮新月。她曾以没有箭头的木矢赶走偷井贼，因此弓身从未染血。骨白与深木色的接缝由旧银箍保护，握把上留着儿童打出的结。传说满月时拉弦，会看见自己最想保护之人的影子。'),
('FenReed','苇泽','非对称短弓、苇绿包片','芦苇海的信使必须在狭窄小舟上射出系着绳结的讯箭，因此弓的下臂特意短于上臂。她将轻木弓腹包以干苇和鱼胶，外侧只留几道绿灰色护片，潮湿时也容易握稳。一次大雾中，她凭沿岸三声回应救出整支采药队。此后弓梢各系一段浅色绳结，用来记住已经消失的码头。它的弦声很轻，却曾让所有以为被遗忘的人知道岸上仍有人等待。'),
('AshRecurve','烬羽','黑红层压反曲弓、赤铜端片','火山林被烧成黑炭后，制弓师在灰烬里发现一株仍流着红色树脂的小树。他只取下已经折断的枝条，反复层压成紧凑的双反曲弓，外黑内红的弓臂像收拢的鸟翼。赤铜弦槽以旧炊锅修补，握把留着烟熏布带。弓师用它为重建村庄猎来第一顿肉，却禁止后人把火当成威名。每一道红色接缝都提醒弓手，能够重生的森林也曾真实地疼痛。'),
('BellHunt','巡铃','宽弓臂、黄铜中架、深蓝缠把','雾镇猎团习惯在出门前摇铃，好让住在林边的人收回牲畜。领弓人失去听力之后，工匠为她打造宽臂长弓，将黄铜中架做成能传递弦振的桥形。深蓝握带下藏着不同方向的凸纹，她凭掌心便能判断松紧。弓梢没有累赘挂饰，只有一枚不会发声的小铃刻痕。猎团散去多年，这张弓仍教导继承者，缺少一种感官并不等于失去与世界交谈的方法。')],
'Crossbow':[
('GateArbalest','门垒','重木肩托、钢弓臂、前蹬环','石门镇的守卫多是年长的磨坊工，难以整日拉开长弓，便把磨架的钢片改成一张厚重弩。宽木肩托能够抵在城垛上，前端蹬环让人借体重上弦，箭槽与铜护片一直延伸到弓臂中央。第一次围城结束后，守卫在枪托下钉了五枚平头钉，记下五次打开城门接回难民的决定。它看起来笨拙，却从未让缺乏臂力的人失去守护家园的位置。'),
('ClockAbbey','钟院','双层弓臂、铜制桥架、横向绞轮','钟院的抄经士厌倦了用钟声预告劫掠，拆下一座坏钟的传动架，设计出双层弓臂的连弩。两道横臂由暗铜桥架隔开，中央箭道清楚可见，木托上的小轮保留着钟表匠的刻度。它第一次发射的不是铁矢，而是一封系着白布的停战信。后来虽被守军采用，弩身仍嵌着那块白色木片，提醒使用者，精密工艺也可以争取让弦不必再次绷紧的时刻。'),
('BriarScout','棘径','轻型短托、骨梢横臂、皮握','穿行黑森林的侦察者发现，宽大的军弩总被枝蔓扯住，于是将旧弩缩成短托，以光滑兽角包住弓梢。灰绿弓臂向后收拢，箭槽只够容纳短矢，皮握把上留下不断穿越泥水的深色痕迹。首任主人曾射断吊桥锁链，让追来的猎犬留在安全岸边。她把那截链环挂在家中，弩上只留一道淡色修痕。轻巧不等于轻慢，每次抬弩之前仍须知道箭会停在哪里。'),
('SaltWinch','盐港','海蓝木托、外露双绞轮、弩首铜箍','盐港灯塔的守塔人用这张绞盘弩把引导绳送到触礁船上。潮水洗淡了海蓝木托，双侧绞轮却一直被他擦得干净，铜箍护住最容易被盐蚀的弩首。箭道比军用弩宽，便于容纳结着救生细绳的短箭。一次风暴后，获救水手送来银币，他只取两枚钉在肩托上作为垫片。它因此显得古怪而不华丽，却让所有见过它的人想起黑海上那根通向灯光的细线。'),
('Reliquary','小圣匣','拱形机匣、深红木托、单层短弓','旅修会将一页烧剩的祈祷书封在木匣里，由最年轻的护送者背往边城。途中木匣裂开，她请工匠把残片嵌进弩托，做成拱形护壳，既挡雨也护住扳机。暗金包边和深红木色使这张短弩看起来像微缩礼拜堂，中央箭槽仍保持朴素直线。残页写的并非胜利，而是为饥饿者留下一把椅子。护送者后来开了客店，把弩挂在门旁，只用来驱赶夜里的野兽。')],
'Longgun':[
('PilgrimMusket','行旅铳','长八角管、弯木托、黄铜机匣','铳匠托兰原本替钟楼修钟，直到巡礼队请求他造一件能在暴雨里示警的器具。他用旧钟铜包住黑铁机匣，保留细长的八角管与弯曲木托，让徒步者能够平稳背负。护木上的浅色木补丁来自沿途不同驿站，记录的都是修理与赠予。它最响亮的一次并非对着敌人，而是在雪山口唤醒迷失的商队。如今人们仍称它行旅铳，因为回家的方向比枪口更重要。'),
('CinderMouth','烬口','扩张钟口、粗木托、铜散热圈','熔岩矿井的工人常被地下巨虫围困，他们把报废炉嘴改成一支短粗长铳，用开阔的钟口发射驱虫的盐石。粗重木托包着煤色铁皮，三道铜圈隔开灼热管身与前手，侧面的红铜片留下多次修补痕迹。矿长曾想将它镀金献给领主，工人却坚持保留烟灰色。对他们而言，这件古怪器具的价值不在杀伤，而在每次响过以后，井口能够多走出一个活人。'),
('AntlerWatch','角哨','骨护木、细长管、开放瞄具','北岭瞭望站没有足够木料，守望者用自然脱落的鹿角做出枪托侧板，将一支旧猎铳修得比原来更轻。骨白护木沿着黑铁长管铺开，开放瞄具只有两片短短的铜叶，不会遮住雪地里的身影。她曾故意打偏一枪，为误闯边境的牧童争取逃离时间，因此被扣去军饷。枪托上的空钉孔就是被摘下的军徽。那片空白至今比任何奖章更醒目。'),
('AlchemistCarbine','炼潮','蓝晶侧舱、短肩托、铜管桥架','潮汐学会相信声音可以装进晶体，年轻研究员便造出一支以蓝晶舱调和震响的卡宾铳。铜色桥架把晶舱固定在机匣外侧，短肩托和厚护木保持实用形态，没有遮住装配接缝。试验失败时，整条街的钟一起响起，研究员被罚修了半年钟楼。她后来把枪交给海防队，只保留一枚裂晶。侧舱的浅色修补线使这件武器像一个承认过错误的人。'),
('GraveWarden','墓卫','黑铁重管、银色机匣、破旗布托','荒原墓园的守卫不愿惊醒沉睡者，却必须在每年幽潮到来时驱走掘墓兽。他把旧军旗裁成细带缠在肩托上，用沉重黑铁管降低前端跳动，银灰机匣只留下守墓人的简朴十字钉。一次守夜，他发现敌兽只是寻找死去幼崽，便放下枪替它挖开冻土。此后枪托多了一道温柔的爪痕。墓卫仍保持警惕，但不再把每一个越过围墙的影子都当成敌人。')],
'Pistol':[
('DuelOath','决斗誓','修长单管、象牙柄片、铜护弓','旧城决斗官把这支象牙柄短铳交给每个执意雪恨的人，却只给一枚没有弹头的药筒。他们必须先听见响声，再决定是否愿意真正伤害对方。修长黑管与弯铜护弓因此几乎没有战斗损伤，只有握片边缘被无数犹疑的手指磨圆。最后一位决斗官失踪后，枪柄上被刻下一道未闭合的圆。传说那是留给后悔的位置，也是最难瞄准、却最值得保留的一条退路。'),
('DockScatter','码头喇叭','短钟口、粗弯柄、青铜枪箍','码头搬运工遇见雾盗时，没有钱购买军械，便请修锅匠把破铜喇叭接到旧短铳上。宽钟口与厚木柄形成滑稽轮廓，却能在浓雾里发出谁也不会听错的警报。枪箍上有一道明显的锡色焊缝，柄尾还嵌着工会的平钉。第一任主人靠它吓退盗船后仍去搬了一整天货，没有接受酒馆的免费酒。他说这东西不属于英雄，只属于需要平安领到工钱的人。'),
('TwinVigil','双守','并列双管、深红柄、旧银框','夜巡姐妹原本各持一支短铳，妹妹失踪后，姐姐把两支枪的管身装进同一副旧银框架。并列双管下方仍有两套不同的修补痕迹，深红握片却被重新磨成适合一只手的形状。她从不同时装填两管，总给归来的人留一个位置。多年以后，巡逻路线上的孩子都知道这支古怪手枪，也知道守夜人会绕远路检查每一扇没关紧的门。金属保存记忆，习惯则替人守住希望。'),
('MothSpark','蛾火','小型晶舱、紧凑短管、绿柄','药铺学徒为了赶走啃食药草的夜蛾，制造出能发出微弱蓝光与响声的小铳。紧凑枪管旁嵌着一枚多面晶舱，绿木柄用黄铜细框保护，握在手里像一只收翅的昆虫。后来山村遭袭，学徒用它引开闯入者，将老人藏进药柜。晶舱因此裂出一条暗线，她也没有再把裂痕磨掉。蛾火不承诺照亮整个夜晚，却会在最需要时为身边的人留下一点光。'),
('GallowsKey','绞门钥','宽扁机匣、钩柄、黑铜枪管','城堡看守曾把钥匙挂在这支黑铜短铳的钩形柄尾，以便一只手开牢门，另一只手守住囚犯。战乱来临时，他却用同一串钥匙放走所有被遗忘的人，随后折断徽章，把残片铆在宽扁机匣侧面。枪管短而沉，旧木握把有一道指甲刻出的深痕。没人知道看守后来去了哪里，只有空牢房的门仍在风中摆动。继承这支武器的人必须先明白，守门与阻止离开并不是同一种责任。')],
'Shield':[
('HearthKite','炉乡','赤陶鸢盾、旧金包边、炉火纹','炉乡的妇女在围城前拆下旧谷仓门，做成五面尖底木盾。这一面由面包师携带，她把炉火的形状画在赤陶色盾面上，让饥饿的孩子在城墙下也能认出她。金属包边来自被熔掉的秤砣，背面的两条皮带不等长，正好适合她受过伤的左臂。城门重开后，盾牌没有进入武库，而是挂回面包房。只要火纹仍在，村里便承诺不让最后一块面包只属于最有钱的人。'),
('SunkenRound','沉日','绿铜圆盾、中央鼓包、破色扇区','湖底神殿露出水面那年，渔民拾到一面覆满淤泥的圆盾。盾面原本的太阳纹只剩几块暗金扇区，中央鼓包却完好无损，背部握柄被水磨成温润的木色。渔民带它挡住坠石，救回试图搬走神像的孩子，随后将神像留在原处。盾上的绿铜色从此被视为退潮的记号。它提醒后人，有些沉入水中的东西值得保存，有些则只需要被安静地尊重。'),
('AshPavise','灰垒','矩形高盾、中脊、黑铁脚包','边境弩手退伍后在盐路护送商队，他用旧车板做成一面几乎齐肩的高盾。中间凸起的脊梁引开箭矢，底端黑铁包脚可以稳在碎石上，灰蓝盾面只涂了一道浅色路标。最深的裂痕来自一次山崩，而不是战斗；他当时把盾横在两个孩子头上撑住落木。如今背带旁多钉着一小片车铃铜，走路时轻轻作响，仿佛仍在告诉落后的旅人不要急，队伍还等着你。'),
('DragonScale','龙眠','骨边叶盾、重叠深红鳞片','守山修士在死去赤龙身旁住了整个冬天，等饥饿的幼兽离开后才取下一片松动背甲。他将背甲分成层叠的深红鳞片，装在叶形木胎上，骨白边框保留自然弯曲。盾牌因此像一片坚硬的叶子，中央没有炫耀战利品的龙首。修士说他没有战胜龙，只是替龙守完最后一夜。每当它挡住攻击，持盾者都该记得，强大的遗骸也曾属于一个想活下去的生命。'),
('BrokenHalo','缺环','白金五角盾、断环纹、宽皮背带','圣城的医护队曾被要求举着金盾冲在军阵前，最后只有一位担架员回到城门。她把光亮镀层磨去，露出象牙色木胎，并在盾面钉上一个故意缺口的铜环。五角轮廓与宽皮背带让盾能够临时充当担架侧板，后缘保留搬运时磨出的凹痕。此后她只为救人而举盾，不再接受任何冲锋命令。缺掉的那一段光环没有等待修复，它是留给伤者进入的门。')],
'Dagger':[
('Ratcatcher','捕鼠人','短宽缺口刀、黑皮柄、铁环尾','旧王城的捕鼠人总把这柄短刀藏在工具袋最底下，宽刃用于割麻袋，钝背用于撬开污水沟盖。瘟疫来临时，他带着医生穿过地下水道，在门闩上崩出一个明显缺口。城民后来为他铸了勋章，他却把铜片磨成柄尾的小环，免得再弄丢刀。黑皮握把几乎看不出原色，仍然贴手。没有吟游诗人为捕鼠人写长歌，这把日用短刀却记得城里许多人第二次见到太阳的那一天。'),
('GlassThorn','琉刺','细晶体刃、金属包根、青色柄芯','玻璃荒原的旅人发现，风暴过后会生出能割断皮带的透明晶刺。女商人阿玛把一根青色晶刺带回城里，请银匠用双层金属套护住脆弱根部，制成纤细的匕首。她用它割开绑住奴隶的绳索，却在最后一次施救时磕掉尖端。重新磨出的锋尖略偏一侧，晶体中仍可看见浅白裂线。阿玛不许工匠把它磨得完美，因为那些不均匀的地方才说明自由并不是毫无代价地到来。'),
('RavenBill','鸦喙','向前弯曲黑刃、骨柄、短叉护手','送信人饲养的乌鸦在战火中失去一只翅膀，他便改为徒步送信，将掉落的黑羽压在刀鞘里。为穿过茂密灌木，他把旧短刀磨成向前弯曲的喙形，骨柄与短叉护手保持结实简洁。刀刃从不用于裁开别人的信，只会割去挡路的细枝。那只不能飞的乌鸦后来一直栖在他的肩上。刀的名字既不是威胁，也不是诅咒，而是对一位仍然陪伴旅途的老朋友的纪念。'),
('CopperMercy','铜赦','圆头外科短刃、赤铜柄、白布握','军医从刑场收回一枚被折断的刃片，将尖端磨圆、边缘收窄，做成便于割开护甲绑带的短刀。赤铜柄有足够重量，白布缠握可以拆下清洗；刀根保留一处原先的黑色锻痕。她给伤兵取出碎甲时从不询问旗号，因此同时受到两支军队怀疑。停战后，这柄不起眼的刀被放在公共药房门边。人们摸着光滑圆头，才明白锋利也可以以克制而不是伤口证明自己。'),
('OathShiver','寒约','三棱窄刃、冰蓝沟线、圆盘尾','北境两个家族曾用一对短刀交换人质，保证冬季停战。其中一柄遗失在雪崩里，被多年后经过的猎人找到。三棱窄刃仍直，冰蓝色矿物嵌线却在刀根断了一小截，圆盘柄尾只剩半个被磨平的家徽。猎人把它送回已经合并的村庄，没有索取报酬。如今这把刀用于婚礼上切开系住两块面包的绳结，提醒新人，承诺若能熬过寒冬，便应当为后来的人留下温暖。')],
'Staff':[
('LanternRoot','根灯','分叉木杖、悬挂铜灯、暗绿晶核','迷林守灯者从倒伏老树上取下一根分叉树根，把祖母的铜灯挂在弯曲杖首。灯里没有油，只有一粒在夜晚微亮的绿晶，必须握住树皮才肯发光。她用这根杖带迷路的伐木工回家，也曾带一头受伤野兽离开猎人的火堆。杖身保留自然瘤节，铜灯有一扇朝内的小窗。守灯者相信，光的价值在于照见脚边的路，而不是把别人眼中的黑暗全部赶走。'),
('TideCrook','潮牧','弧形牧杖头、青蓝晶体、铜脚套','潮牧师负责在退潮时点清滩涂上的孩子，把最不听话的那个送到家门口。她的长杖顶端向内弯曲，像能轻轻勾住披风的牧钩，青蓝晶体嵌在弧心，铜脚套经海砂磨得发暗。一次异常大潮吞没堤坝，她用杖身撑住木门直到最后一人通过。木头因此弯得不再对称，晶体也少了一角。村民要给她新杖，她只请他们把回家的路修得更宽一些。'),
('FungalCenser','菌香','伞盖杖冠、孢囊吊饰、淡骨杖身','蘑菇林的药师发现，有些孢子只在听到人的低语时释放，于是将干燥菌盖安在长杖顶端，做成可以轻摇的香炉。淡骨色杖身以藤条加固，赭红伞盖下面悬着三个封闭孢囊，结构像一座古怪的小屋。药师走过瘟疫村庄时，先把自己的名字告诉病人，才举起菌香杖。后来她忘记许多药方，却仍记得那些名字。杖上的深浅斑点是菌林留下的纹路，也是漫长照护的年轮。'),
('StarCage','星囚','八角铜笼、紫晶核心、暗木长杆','观星塔的学徒曾试图把一颗坠落的星光关进铜笼，好证明导师的旧理论有错。星光真的留下来，却不再闪烁，直到他打开一道笼缝才重新亮起。于是他将八角铜笼安在暗木杖顶，保留那道明显的缺口，紫色晶核由三条弯臂支撑，既稳固又不显封闭。学徒后来成为教师，每次授课都先讲这次失败。知识可以为未知搭建框架，却不该把好奇心牢牢锁在里面。'),
('StormFork','雷枝','双叉铁杖冠、琥珀核、麻绳握','山村的避雷匠失去右手后，仍坚持修复被风暴击坏的钟塔。他把旧避雷叉装到长木杆上，在叉间嵌入一块琥珀色焦晶，用粗麻绳缠出适合单手的宽握。铁叉上方的两枝高低不同，正是那次雷击留下的轮廓。村里的孩子把它叫作法杖，匠人却说只是提醒天空别再找错落点。后来它确实能引导微弱电光，但最常做的事仍是替老人拨开湿滑山路上的荆棘。')],
'Scope':[
('SurveyorGlass','测岭镜','长铜镜筒、大物镜、小目镜','测岭师曾用这支铜镜寻找雪崩后的失踪者，镜筒两端的口径不同，前端包边保护着淡蓝玻璃。后来边军请求将它装上长铳，她坚持在安装脚上留下可拆的铜栓，让镜子随时能够重新用于观察道路。筒身刻度已被风沙磨浅，目镜附近有一圈旧皮。它最珍贵的记录不是命中多远的靶子，而是一次在白茫茫山坡上发现了仍在挥手的人，从此远处也不再只是抽象的距离。'),
('MoonPrism','月棱镜','短方壳、斜棱顶、圆目镜','月井工匠认为长镜筒容易让使用者只盯住一点，于是用棱镜折出紧凑的观察器。方形旧银外壳顶端向一侧倾斜，圆目镜藏在短铜环里，底部安装脚像一座小桥。它最初供夜间摆渡人判断岸边灯号，后来才被侦察队采用。壳侧保留被船篙撞出的浅凹，玻璃仍泛着安静的蓝色。工匠留下的唯一叮嘱是，看清远方之后，别忘了抬头确认身旁是否还有同行的人。'),
('OwlEye','鸮眼','宽双层物镜、深铁筒、骨白护圈','守夜猎人救下一只被捕兽夹伤到的猫头鹰，从此把它收拢翅膀时的轮廓刻在镜体护圈上。宽大的双层物镜适合收集昏暗光线，深铁镜筒以骨白边圈区分调节位置，摸索时也不易弄错。镜架的一只脚曾折断，后来用铜片补齐，因此左右并不完全相同。猎人说夜色并没有偏袒任何一方，只是要求人放慢判断。鸮眼的第一课是辨认影子，第二课才是决定是否举枪。'),
('AmberDial','琥珀刻','中长筒、侧调节轮、红铜接环','王城报时员喜欢观察城外最早亮起的窗户，便把修钟剩下的调节轮装到观测镜上。琥珀色镜片夹在红铜接环之间，侧轮很大，戴着冬手套也能够转动。城防队借走它以后，仍须每天替报时员记录晨光出现的时刻。镜筒外侧有一道没有擦净的墨迹，是他第一次把时间写错留下的。这个小小失误让继任者记住，最精巧的刻度也需要人的耐心，而不是盲目的相信。'),
('PilgrimMonocle','行僧独眼','极短单筒、开放护架、白陶圈','独眼行僧在雪地里看不清路标，玻璃匠便为他做了一支极短的观察筒，白陶环能够隔开冰冷金属，开放铜架便于绑在杖或器械上。行僧后来将它赠给视力受损的城门守卫，自己继续凭熟悉的钟声旅行。筒身没有复杂纹章，只有一枚斜钉和换过数次的皮圈。它提醒使用者，工具的意义是补足人的局限，让曾经看不见的路径重新出现，而不是让人忘记自己的局限。')],
'Suppressor':[
('QuietBell','静钟','钟形外壳、收束尾端、青铜环','静语修会禁止在疗养院附近制造巨响，守门工匠便给示警铳加上一只刻着吸声符的钟形罩。宽壳和细尾之间由青铜环连接，外壁保留铸钟砂模留下的平整折面。它不会让声音消失，只把刺耳回声化成低沉短响，好让病人继续安睡。第一只罩子被盗后，修士没有诅咒窃贼，而是重新铸了一只。对他们而言，宁静从来不是无人回应，而是每个人都愿意替别人的疲惫留一点余地。'),
('AshSleeve','灰衣','长筒布套、铁端盖、外露缝带','穿过火山山道的信使常被铳声引来的石翼兽追赶，便请灰衣巫婆把吸声布缠在长筒外壳上。深灰织物由三条浅色缝带固定，两端铁盖露在外面，烧坏的部分可以单独更换。巫婆没有收钱，只让信使在每封家书上多等一刻钟。后来布套换了许多次，等候的习惯却没有改变。它承载的魔法不算强大，却让匆忙世界中的一些声音得以变轻，让尚未说完的话有机会被听见。'),
('ReedWhisper','苇语','分节绿铜筒、窄尾箍、浅色隔环','芦苇海的守渡人发现，空苇束能把回声分散到水面，于是用绿铜仿制分节外壳，在节间嵌入浅色陶环。细长筒体装到守船铳前端，远看像一截被晒干的水草。它最初用于赶走咬断缆绳的水兽，避免惊吓船上的病人。每次进港，守渡人都会卸下它清理盐泥，动作如同照料一支旧笛。苇语不以无声为荣，它只是让一次必要的警告不再伤害更多无关的耳朵。'),
('GraveHush','墓息','短宽黑筒、骨色侧板、封闭端面','墓园守卫把哀歌符刻在短宽铁筒上，希望守夜时的警告不打断亡者家属的祈祷。骨色侧板由普通白陶制成，不来自任何遗骸，边缘以暗铜钉固定，端面保留清楚的中央孔。一次寒夜，守卫将它卸下暖在怀里，才发现自己已经多年没有认真听过风声。此后他总会先走近辨认来者，再考虑举枪。墓息真正压低的也许不是铳响，而是人面对陌生影子时仓促升起的恐惧。'),
('StarBaffle','星隔','八角长壳、紫晶缝、铜安装端','观星塔的工匠试着用极细晶片吸收器械震动，把八角外壳做成便于拆开的两半。紫色晶缝沿一侧延伸，铜安装端与暗银筒身之间留着明确的接合圈，看起来像封住星光的小匣。试验中它曾把钟声变成轻微颤动，令一名失聪学徒第一次用掌心感到报时。工匠因此放弃为它取威武名字，只叫星隔。它隔开的是令人畏惧的尖响，留下的却是仍能被身体理解的温柔节拍。')]
}

def write_catalog():
    ROOT.mkdir(parents=True,exist_ok=True)
    refs={r[0]:dict(id=r[0],title=r[1],page_url=r[2],image_url=r[3],takeaway=r[4],source_kind='game artwork / screenshot; reference only',viewed=False) for r in REFS}
    rows=[]
    for family,designs in DESIGNS.items():
        for variant,(slug,title,features,lore) in enumerate(designs):
            count=len(re.findall('[\u4e00-\u9fff]',lore));assert count>=100,(title,count)
            rows.append(dict(id=f'AEW_{family}_{slug}',display_name=title,category=family,variant=variant,design_features=features,lore_zh=lore,lore_han_characters=count,references=[refs[r] for r in FAMILY_REFS[family]],literature_references=['elfland','beowulf'],integration_status='staging only; gameplay, sockets, grip config and Unity rendering unverified',origin_contract='metres; Blender +Z up / -Y front; grip origin at zero except accessories origin is mounting axis; guns shoot -Y, blades extend +Z; no configured grip rows created'))
    assert len(rows)==55
    (ROOT/'catalog.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
    (ROOT/'References').mkdir(exist_ok=True)
    (ROOT/'References/references.json').write_text(json.dumps(dict(images=list(refs.values()),literature=LITERATURE),ensure_ascii=False,indent=2),encoding='utf8')
    (ROOT/'Backgrounds.md').write_text('# 武器与配件背景档案\n\n原创设定；引用图像用于造型研究，未作为模型纹理。\n\n'+'\n\n'.join(f'## {x["id"]} · {x["display_name"]}\n\n{x["lore_zh"]}\n\n造型落实：{x["design_features"]}。汉字：{x["lore_han_characters"]}。' for x in rows),encoding='utf8')
    print(json.dumps(dict(count=len(rows),min_han=min(x['lore_han_characters'] for x in rows))))

def download_references():
    from PIL import Image,ImageDraw,ImageOps
    refs=json.loads((ROOT/'References/references.json').read_text(encoding='utf8'))
    def one(r):
        p=ROOT/'References'/(r['id']+'.png')
        if not p.exists():
            request=urllib.request.Request(r['image_url'],headers={'User-Agent':'Mozilla/5.0'})
            with urllib.request.urlopen(request,timeout=35) as response: data=response.read()
            import io
            image=Image.open(io.BytesIO(data)).convert('RGBA');image.save(p)
        return r['id'],str(p)
    results=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
        futures={pool.submit(one,r):r for r in refs['images']}
        for f,r in futures.items():
            try: results.append(f.result())
            except Exception as e: print('DOWNLOAD_FAILED',r['id'],str(e))
    for start in range(0,len(results),6):
        sheet=Image.new('RGB',(1500,1100),'#d0c8b7');draw=ImageDraw.Draw(sheet)
        for k,(key,path) in enumerate(results[start:start+6]):
            im=Image.open(path).convert('RGBA');im.thumbnail((485,490))
            x=(k%3)*500+(500-im.width)//2;y=(k//3)*550+35
            sheet.paste(im,(x,y),im);draw.text(((k%3)*500+12,(k//3)*550+8),key,fill='black')
        sheet.save(ROOT/'References'/f'contact_{start//6+1}.jpg')
    print('REFERENCES',len(results))

if __name__=='__main__':
    write_catalog();download_references()
