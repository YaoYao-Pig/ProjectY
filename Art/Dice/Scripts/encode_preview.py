"""Encode the unmodified Unity UI captures as an animated review artifact."""
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[1]
for folder,still,output in [('Overlay','success.png','DiceRoll.gif'),('Handful','settled.png','DiceHandful.gif')]:
    paths=sorted((root/'UnityPreview'/folder).glob('roll-*.png'))
    assert len(paths)==60, 'Run Tools/Tests/dice_overlay.cs first'
    frames=[Image.open(path).convert('RGB') for path in paths]
    frames.append(Image.open(root/'UnityPreview'/folder/still).convert('RGB'))
    frames[0].save(root/output,save_all=True,append_images=frames[1:],duration=[50]*60+[1400],loop=0,disposal=2)
    print(root/output)
