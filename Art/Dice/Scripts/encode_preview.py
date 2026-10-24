"""Encode the unmodified Unity UI captures as an animated review artifact."""
from pathlib import Path
from PIL import Image

root=Path(__file__).resolve().parents[1]
paths=sorted((root/'UnityPreview/Overlay').glob('roll-*.png'))
assert len(paths)==20, 'Run Tools/Tests/dice_overlay.cs first'
frames=[Image.open(path).convert('RGB') for path in paths]
frames.append(Image.open(root/'UnityPreview/Overlay/success.png').convert('RGB'))
frames[0].save(root/'DiceRoll.gif',save_all=True,append_images=frames[1:],duration=[150]*20+[1400],loop=0,disposal=2)
print(root/'DiceRoll.gif')
