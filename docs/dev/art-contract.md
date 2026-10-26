# Art contract (ไฟล์ภาพที่เกมโหลด)

เกมหาภาพจาก `res://assets/art/<category>/<id>.png` ถ้ามีไฟล์ก็ใช้ไฟล์ ถ้าไม่มีก็วาด placeholder จากโค้ด (`src/autoload/art.gd`) ในขนาดและเลย์เอาต์ที่เกมคาดไว้
ดังนั้นใส่ภาพจริงทีละไฟล์ได้ โดยไม่ต้องแก้โค้ด

**แหล่งความจริงของเลย์เอาต์ภาพจริงคือ `assets/art/manifest.json`** (สร้างโดย `tools/art/build.py` ในงาน art) เอกสารนี้บอกเฉพาะว่าโค้ดฝั่งเกมอ่านอะไรและอ่านอย่างไร

- palette Endesga 32, ไม่มี anti-alias, พื้นหลังโปร่งใส, import เป็น filter Nearest และไม่มี mipmap (ตั้งเป็น default ของ project แล้ว)
- ช่องบนแผนที่ 16x16 px บนกริด 480x270 (แผนที่ 22x13 ช่อง)
- ไม่ commit ไฟล์ `.import` ของ PNG Godot สร้างเองตอน `--import`

## ที่เกมใช้อยู่ตอนนี้

| หมวด | ไฟล์ | ใช้อย่างไร |
| --- | --- | --- |
| tiles | `land.png`, `land_grass.png`, `land_parchment.png`, `land_navy.png` | atlas dual-grid 256x96 ปุ่ม B สลับไฟล์ตามพื้นหลัง ดูด้านล่าง |
| tiles | `road.png` | 16 เฟรม 16x16, เฟรม = mask ทิศถนน N=1 E=2 S=4 W=8 |
| tiles | `camp.png` | 4 เฟรม 16x16 ไฟกระพริบ 6 fps |
| map | `<card id>.png` (รวม `clear`) | 3 เฟรม 16x24 = การ์ดเลเวล 1-3, จุดยึดกึ่งกลางล่าง, `clear` ไม่เคยวางลงแผนที่ |
| units | `hero.png` 64x160 | แถว 0-3 เดิน (ล่าง ซ้าย ขวา ขึ้น) 4 เฟรม 8 fps, แถว 4-7 ตี (คอลัมน์ 0-2, 10 fps) และเจ็บ (คอลัมน์ 3), แถว 8 ร่ายสกิล (คอลัมน์ละทิศ), แถว 9 ล้ม (0-1) และชนะ (2) |
| units | `slime wolf skeleton bandit.png` 32x48 | แถว 0 ยืน 2 เฟรม 3 fps, แถว 1 โจมตี 2 เฟรม 8 fps, แถว 2 เจ็บ |
| units | `<id>_elite.png`, `crown.png` 7x4 | elite ใช้แผ่น `_elite` และมงกุฎเหนือหัว (ถ้าไม่มีไฟล์ใช้ตัวธรรมดาและดาว ★) |
| units | `boss_warden.png` 96x96 | เฟรม 32x32: ยืน 2 เฟรม 2 fps, ตี 3 เฟรม 6 fps, เจ็บ |
| units | `shadow.png` 16x16 | วาดใต้ทุกตัวละคร (ขยาย 2 เท่าใต้บอส) |
| cards | `<card id>.png` 96x44 | หน้าการ์ดสำเร็จรูป 3 เลเวล (กรอบ, ภาพ, ป้ายเลเวล, ไอคอนประเภท) เกมเขียนชื่อไทย (ตัวหนา 6 px) ลงป้าย (4,31,24,9) สี `#3e2731` ย่อตัวอักษรถ้าชื่อยาว (ค่าอยู่ใน `CardView.PLATE` ตรงกับ manifest) |
| icons | `stat_str/agi/int.png`, `skill_<id>.png` | 16x16 ใช้ในแผงแต้ม stat, ช่อง skill, หน้า skill card และ Rebirth tree |
| icons | `item_weapon/armor/ring/amulet/charm.png`, `perk_<id>.png` | 16x16 ไอเทมในแผงไอเทม/ร้านค้า/ช่อง gear, perk เมืองในแผง perk และแท็บเมือง |
| icons | `notif_<kind>.png`, `node_<id>.png` | 16x16 ไอคอนแถวแจ้งเตือนข้างจอ (`UiTheme.notice_icon`), ปุ่ม utility บน Rebirth tree |
| icons | `small/rp.png`, `small/check.png` | 8x8 ใช้ที่ RP บนแถบบนและหน้าจบ/หน้าหลัก, เครื่องหมายเป้าหมายที่ทำแล้ว |
| tiles | `town_ground.png`, `town_fence.png`, `town_wall.png` | พื้น/รั้ว/กำแพงของเมืองตามระดับ (หมู่บ้าน/เมือง) วาดใต้การ์ดอาคารที่ต่อกันเป็นกลุ่มใหญ่สุด |
| map | `house_town.png`, `event.png` | บ้านในระดับเมือง (การ์ด house ที่อยู่ในกลุ่มเมือง) และจุด "?" ของ event 4 เฟรม |

placeholder ที่เกมวาดเองมีเลย์เอาต์เล็กกว่า (ฮีโร่ 32x64, ศัตรู 32x16, atlas land 64x64 ฯลฯ) ท่าที่ไม่มีใน placeholder จะถอยกลับไปใช้ท่ายืน/เดิน

### land atlas (256x96)

เฟรมน้ำ f อยู่ที่คอลัมน์ `4f .. 4f+3` (tile index อยู่คอลัมน์ `index % 4`, แถว `index / 4`), 4 เฟรม 3 fps
แถว 4 = หญ้า 4 แบบของ tile 15 (ทุกมุมเป็นแผ่นดิน), แถว 5 = น้ำเปิด 4 แบบของ tile 0 (ทุกมุมเป็นทะเล) เลือกแบบด้วย hash ของพิกัด ไม่เปลี่ยนระหว่างเล่น
index = TL*1 + TR*2 + BL*4 + BR*8 (บิตเปิด = มุมนั้นเป็นแผ่นดิน) tile วางที่จุดตัดของ 4 ช่อง (ขยับ -8,-8) และเกมวาด tile 0 ด้วยเมื่อเป็นไฟล์จริง

## ยังไม่ได้ใช้ (มีไฟล์แล้ว รอฟีเจอร์ที่ใช้)

`ui/` ทั้งโฟลเดอร์ (9-slice panel/button/slot, bar, ตัวเลข `digits`, `portrait_hero`, cursor), `fx/` (เอฟเฟกต์ตี/ฮีล/เลเวลอัป/merge),
`icons/small/` ที่เหลือ (atk, hp, ap ฯลฯ) และกรอบการ์ดแยก (`cards/frame_*.png`, `back`, `badge`) ตอนนี้ UI ยังวาดกรอบ/ปุ่ม/ตัวเลขด้วยโค้ดทั้งหมด
การเปลี่ยนไปใช้ 9-slice ของ `ui/` เป็นงานตกแต่งที่ทำทีหลังได้โดยไม่กระทบระบบ (จุดเดียวคือ `UiTheme.box` และ `UiTheme.text`)

## fonts

`assets/art/fonts/Sarabun-Regular.ttf` และ `Sarabun-Bold.ttf` (OFL, อ่านภาษาไทยได้ที่ 6-9 px) ถ้าจะเปลี่ยนฟอนต์ต้องทดสอบที่ 6 px ก่อน ตัวอักษรไทยสูงประมาณ 9 px รวมวรรณยุกต์

## ตรวจว่าภาพเข้ากับเกม

```
godot --headless --path . --import
xvfb-run -a godot --path . --rendering-driver opengl3 -- --seed 7 --fast 60 --bg 1 --shot /tmp/a.png
```

`--bg 0..3` เลือกพื้นหลัง (ทะเล / ทุ่งหญ้า / กระดาษเก่า / น้ำเงินเข้ม), `--hold 0` ถือการ์ดช่องแรกเพื่อดูไฮไลต์ช่องที่วางได้ ดู [README](README.md) สำหรับอาร์กิวเมนต์อื่น
