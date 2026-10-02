"""Archive visual references for this original asset batch; never import them into Unity."""
from pathlib import Path
import urllib.request, json
ROOT=Path(__file__).resolve().parent
REFS=[
dict(id='ds3_catacombs',work='Dark Souls III — Catacombs of Carthus',page='https://www.cheatcc.com/guides/dark-souls-iii-guide-walkthrough/walkthrough-15/catacombs-of-carthus/',image='https://cdn.cheatcc.com/guide_screens/dark_souls_3/ds3_8.26.jpg',notes='Vaulted burial architecture, coherent urn silhouettes, worn stone and restrained earth palette.'),
dict(id='ds3_dungeon',work='Dark Souls III — Irithyll Dungeon',page='https://www.cheatcc.com/guides/dark-souls-iii-guide-walkthrough/walkthrough-15/irithyll-dungeon/',image='https://cdn.cheatcc.com/guide_screens/dark_souls_3/ds3_12.12.jpg',notes='Damp masonry, low candles, aged timber and edge clutter; retain clear central passage.'),
dict(id='skyrim_altar',work='The Elder Scrolls V: Skyrim — Ustengrav',page='https://www.nexusmods.com/skyrim/images/420366/',image='https://staticdelivery.nexusmods.com/images/110/4335198-1399525741.jpg',notes='Broad ritual altar, paired tapered urns, warm desaturated earthenware and candle groupings.'),
dict(id='skyrim_ruunvald',work='The Elder Scrolls V: Skyrim — Ruunvald',page='https://www.nexusmods.com/skyrim/images/282639',image='https://staticdelivery.nexusmods.com/images/110/264238-1376652221.jpg',notes='Chunky worn stone, warm wax, broad urn shoulder and subtle low contrast surface wear.'),
dict(id='skyrim_moss',work='The Elder Scrolls V: Skyrim Special Edition — cavern',page='https://www.rpgsite.net/news/5038-skyrim-special-edition-pc-comparison',image='https://images.rpgsite.net/image/da49c9a1/49949/original/SSE_2016OCT27_06.png',notes='Cold damp rock, muted moss and dry readable walking surface; roots kept near walls.'),
dict(id='ds3_storage',work='Dark Souls III — Undead Settlement',page='https://www.cheatcc.com/guides/dark-souls-iii-guide-walkthrough/walkthrough-15/undead-settlement/',image='https://cdn.cheatcc.com/guide_screens/dark_souls_3/ds3_4.101.jpg',notes='Functional timber bracing, barrel/crate storage and clear navigation through clutter.'),
dict(id='ds3_wood',work='Dark Souls — the Depths',page='https://www.svg.com/842336/tragic-details-you-missed-in-dark-souls/',image='https://www.svg.com/img/gallery/tragic-details-you-missed-in-dark-souls/laurentius-hallowing-1650652881.jpg',notes='Curved barrel staves, iron hoop bands and discarded timber planks.'),
dict(id='skyrim_lectern',work='The Elder Scrolls V: Skyrim — Dragonborn',page='https://en.m.uesp.net/wiki/Skyrim%3ABlack_Book%3A_The_Sallow_Regent_%28quest%29',image='https://images.uesp.net/a/a5/SR-quest-Black_Book_The_Sallow_Regent.jpg',notes='Book pedestal has a supported tilted reading surface, readable book thickness and restrained candle groupings.'),
dict(id='skyrim_library',work='The Elder Scrolls V: Skyrim — Arcanaeum',page='https://www.confrerie-des-traducteurs.fr/skyrim/mods/3867',image='https://mods.confrerie-des-traducteurs.fr/skyrim/3867/images/big/the_elder_scrolls_v__skyrim_special_edition_screenshot_2023.04.09___15.43.17.64.jpg',notes='Library archive shelving, thick leather bindings, warm neutral timber and visible working surfaces.'),
]
(ROOT/'References').mkdir(parents=True,exist_ok=True)
for ref in REFS:
    path=ROOT/'References'/(ref['id']+'.jpg')
    try:
        if path.exists():
            ref['local']=str(path.relative_to(ROOT));ref['download_bytes']=path.stat().st_size
            continue
        req=urllib.request.Request(ref['image'],headers={'User-Agent':'Mozilla/5.0'})
        with urllib.request.urlopen(req,timeout=30) as response: data=response.read()
        path.write_bytes(data)
        ref['local']=str(path.relative_to(ROOT));ref['download_bytes']=len(data)
        print(ref['id'],len(data))
    except Exception as exc:
        ref['download_error']=str(exc);print(ref['id'],str(exc))
(ROOT/'references.json').write_text(json.dumps(REFS,ensure_ascii=False,indent=2),encoding='utf-8')
