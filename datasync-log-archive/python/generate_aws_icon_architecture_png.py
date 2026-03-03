from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
 

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "diagrams" / "architecture.png"
ICON_DIR = ROOT / "diagrams" / "aws-icons"

WIDTH, HEIGHT = 3600, 1800
CANVAS_BG = (255, 255, 255)
BOX_BORDER = (175, 190, 220)
BOX_BG = (246, 250, 255)
TEXT_COLOR = (30, 42, 68)
LINE_COLOR = (56, 88, 140)


def load_font(size: int):
    for candidate in ["arial.ttf", "segoeui.ttf", "calibri.ttf"]:
        try:
            return ImageFont.truetype(candidate, size)
        except OSError:
            continue
    return ImageFont.load_default()


def icon_path(icon_filename: str) -> Path:
    return ICON_DIR / icon_filename


def rounded_box(draw: ImageDraw.ImageDraw, xy, title: str, font):
    draw.rounded_rectangle(xy, radius=24, fill=BOX_BG, outline=BOX_BORDER, width=3)
    draw.text((xy[0] + 18, xy[1] + 12), title, fill=TEXT_COLOR, font=font)


def draw_node(canvas: Image.Image, draw: ImageDraw.ImageDraw, x, y, icon_filename, label, icon_size=(128, 128), label_font=None):
    p = icon_path(icon_filename)
    icon = Image.open(p).convert("RGBA").resize(icon_size, Image.Resampling.LANCZOS)
    canvas.alpha_composite(icon, (x, y))

    if label_font is None:
        label_font = load_font(24)

    tw = draw.multiline_textbbox((0, 0), label, font=label_font, spacing=4)
    label_w = tw[2] - tw[0]
    draw.multiline_text((x + icon_size[0] // 2 - label_w // 2, y + icon_size[1] + 10), label, fill=TEXT_COLOR, font=label_font, align="center", spacing=4)


def arrow(draw: ImageDraw.ImageDraw, start, end, width=6):
    draw.line([start, end], fill=LINE_COLOR, width=width)
    ex, ey = end
    sx, sy = start
    if abs(ex - sx) >= abs(ey - sy):
        direction = 1 if ex > sx else -1
        tip = (ex, ey)
        p1 = (ex - 20 * direction, ey - 10)
        p2 = (ex - 20 * direction, ey + 10)
    else:
        direction = 1 if ey > sy else -1
        tip = (ex, ey)
        p1 = (ex - 10, ey - 20 * direction)
        p2 = (ex + 10, ey - 20 * direction)
    draw.polygon([tip, p1, p2], fill=LINE_COLOR)


img = Image.new("RGBA", (WIDTH, HEIGHT), CANVAS_BG + (255,))
draw = ImageDraw.Draw(img)

title_font = load_font(52)
section_font = load_font(30)
label_font = load_font(22)
small_font = load_font(20)

# Title
main_title = "AWS DataSync Log Archive Architecture (DEV)"
draw.text((60, 26), main_title, fill=TEXT_COLOR, font=title_font)

draw.text((60, 95), "Encrypted transfer, least-privilege IAM, lifecycle tiering, monitoring and alerting", fill=(70, 84, 115), font=small_font)

# Cluster boxes
source_box = (40, 150, 720, 1700)
conn_box = (760, 150, 1520, 1700)
aws_box = (1560, 150, 3560, 1700)

rounded_box(draw, source_box, "Source Environment", section_font)
rounded_box(draw, conn_box, "Secure Connectivity", section_font)
rounded_box(draw, aws_box, "AWS Account", section_font)

# Source nodes
draw_node(img, draw, 290, 380, "ec2.png", "WAS Servers\n/logs/*.gz", icon_size=(150, 150), label_font=label_font)
draw.rounded_rectangle((150, 700, 610, 840), radius=18, fill=(255, 255, 255), outline=BOX_BORDER, width=2)
draw.multiline_text((178, 735), "Daily Rotation\n~42 GB/day", fill=TEXT_COLOR, font=label_font, spacing=6)

# Connectivity
draw_node(img, draw, 1060, 360, "datasync-agent.png", "DataSync Agent\nEC2 Private / On-Prem", icon_size=(150, 150), label_font=label_font)
draw.rounded_rectangle((910, 720, 1390, 860), radius=18, fill=(255, 255, 255), outline=BOX_BORDER, width=2)
draw.multiline_text((945, 748), "TLS 1.2\nEncrypted Transfer", fill=TEXT_COLOR, font=label_font, spacing=6)

# AWS nodes
draw_node(img, draw, 1760, 290, "datasync.png", "DataSync Task\nDaily 01:00 UTC\nChanged Files", icon_size=(150, 150), label_font=small_font)
draw_node(img, draw, 2280, 290, "identity-and-access-management-iam.png", "Least-Privilege\nIAM Role", icon_size=(150, 150), label_font=small_font)

draw_node(img, draw, 1760, 760, "simple-storage-service-s3.png", "S3 Bucket\ndev-was-log-archive", icon_size=(150, 150), label_font=small_font)
draw_node(img, draw, 2280, 760, "key-management-service.png", "SSE-KMS\nCMK + Rotation", icon_size=(150, 150), label_font=small_font)
draw_node(img, draw, 2800, 760, "s3-glacier.png", "Lifecycle\n30d IR / 180d DA / 365d Expire", icon_size=(150, 150), label_font=small_font)

draw_node(img, draw, 1760, 1230, "cloudwatch-logs.png", "CloudWatch Logs", icon_size=(150, 150), label_font=small_font)
draw_node(img, draw, 2150, 1230, "cloudwatch.png", "CloudWatch Metrics", icon_size=(150, 150), label_font=small_font)
draw_node(img, draw, 2540, 1230, "cloudwatch-alarm.png", "Alarms\nFailure/Low Bytes/Offline", icon_size=(150, 150), label_font=small_font)
draw_node(img, draw, 2930, 1230, "simple-notification-service-sns.png", "SNS Alerts\nEmail", icon_size=(150, 150), label_font=small_font)
draw_node(img, draw, 3320, 1230, "cloudtrail.png", "CloudTrail", icon_size=(150, 150), label_font=small_font)

# Arrows
arrow(draw, (440, 620), (1060, 430))
arrow(draw, (1140, 700), (1140, 720))
arrow(draw, (1390, 790), (1760, 370))
arrow(draw, (2360, 370), (1910, 370))
arrow(draw, (1910, 520), (1910, 760))
arrow(draw, (2360, 910), (1910, 910))
arrow(draw, (2430, 840), (2800, 840))
arrow(draw, (1910, 910), (1910, 1230))
arrow(draw, (1910, 1380), (2150, 1380))
arrow(draw, (2300, 1380), (2540, 1380))
arrow(draw, (2690, 1380), (2930, 1380))
arrow(draw, (3320, 1380), (2950, 980))

OUT.parent.mkdir(parents=True, exist_ok=True)
img.convert("RGB").save(OUT, format="PNG", optimize=True)
print(f"Generated: {OUT}")
