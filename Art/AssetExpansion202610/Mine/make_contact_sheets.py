"""Contact sheets of actual Blender and Unity captures, kept at native aspect."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).parent
rows = json.loads((root / 'manifest.json').read_text(encoding='utf-8'))
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 18)
for folder, suffix in [('Previews', '_hero'), ('UnityPreviews', '')]:
    sheet = Image.new('RGB', (1200, 856), (20, 24, 31))
    draw = ImageDraw.Draw(sheet)
    for index, row in enumerate(rows):
        image = Image.open(root / folder / (row['name'] + suffix + '.png')).convert('RGB')
        image.thumbnail((400, 400))
        x, y = (index % 3) * 400, (index // 3) * 428
        sheet.paste(image, (x, y))
        draw.text((x + 12, y + 402), row['name'], font=font, fill='white')
    sheet.save(root / folder / 'mine-kit.jpg', quality=94)
