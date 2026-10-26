# tools/art

เครื่องมือวาด sprite ทั้งหมดของเกม ภาพทุกชิ้นเขียนเป็นตารางตัวอักษร (1 ตัว = 1 สีใน Endesga 32 ดู `pal.py`)
แล้ว `build.py` แปลงเป็น PNG ใน `assets/art/` พร้อม `assets/art/manifest.json` และภาพตัวอย่างใน `docs/art/`

```
python3 tools/art/build.py              # ต้องมี Pillow
python3 tools/art/build.py --no-preview # ไม่สร้างภาพตัวอย่างใน docs/art/
```

build จะ fail ถ้ามี pixel ที่ไม่ใช่สีใน palette หรือโปร่งแสงครึ่งๆ และไม่แตะ `assets/art/fonts/`

| ไฟล์ | ทำอะไร |
| --- | --- |
| `pal.py` | palette Endesga 32 และตัวอักษรแทนสี |
| `px.py` | เครื่องมือวาด: แปลงตารางเป็นภาพ, วาง, outline, ตัด, ต่อ sheet, ตรวจสี |
| `board.py` | ตัวสร้าง loop และเกาะแบบเดียวกับเกม ใช้ทำภาพตัวอย่าง |
| `ground.py` | พื้นแบบ dual-grid 4 แบบ (ทะเล, ทุ่งหญ้า, กระดาษเก่า, น้ำเงินเข้ม) |
| `road.py` | ถนน 16 แบบตาม mask N=1 E=2 S=4 W=8 |
| `objects.py` | วัตถุบนแผนที่ของการ์ดทุกใบ 3 เลเวล, บ้านในเมือง, แคมป์, จุด ? |
| `town.py` | พื้นหิน รั้ว และกำแพงเมือง แบบ dual-grid ตามกลุ่มอาคาร |
| `units.py` | ฮีโร่, ศัตรู 4 แบบ + elite, บอส, เงา |
| `icons.py` | ไอคอน 8x8 และ 16x16 |
| `ui.py` | การ์ด, แผง, ปุ่ม, ช่องของ, แถบค่า, ไฮไลต์ช่อง, เคอร์เซอร์, ตัวเลข 3x5 |
| `fx.py` | เอฟเฟกต์ต่อสู้และบนแผนที่ |
| `build.py` | export ทุกอย่าง + manifest + ภาพตัวอย่าง |

กติกาการวาดและวิธีใช้ใน Godot อยู่ที่ [docs/art/README.md](../../docs/art/README.md)
