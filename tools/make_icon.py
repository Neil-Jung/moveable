"""windows/moveable.ico 생성: 파란 둥근 사각형 위에 흰색 4방향 화살표."""
from pathlib import Path
from PIL import Image, ImageDraw

S = 1024  # 크게 그린 뒤 축소해 부드러운 가장자리를 얻는다
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle([40, 40, S - 40, S - 40], radius=220, fill=(37, 99, 235, 255))

c, w, head, reach = S / 2, 70, 170, 360
white = (255, 255, 255, 255)
d.rectangle([c - w / 2, c - reach + head * 0.8, c + w / 2, c + reach - head * 0.8], fill=white)
d.rectangle([c - reach + head * 0.8, c - w / 2, c + reach - head * 0.8, c + w / 2], fill=white)
for sx, sy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
    tip = (c + sx * reach, c + sy * reach)
    base = (c + sx * (reach - head), c + sy * (reach - head))
    px, py = -sy, sx  # 수직 방향
    d.polygon([tip, (base[0] + px * head * 0.75, base[1] + py * head * 0.75),
               (base[0] - px * head * 0.75, base[1] - py * head * 0.75)], fill=white)

out = Path(__file__).resolve().parent.parent / "windows" / "moveable.ico"
img.save(out, sizes=[(16, 16), (20, 20), (24, 24), (32, 32), (48, 48), (64, 64), (256, 256)])

print(out)
