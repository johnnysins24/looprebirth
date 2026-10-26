# Loop Rebirth

roguelite แนว Loop Hero ที่ขยาย gameplay: loop เปลี่ยนทุก run, การ์ด tile และ skill card ที่ merge ได้,
เมืองที่โตไปพร้อม run, auto battle และ Rebirth tree สำหรับปลดล็อก utility กับการ์ดใหม่ สร้างด้วย Godot 4

## โครงสร้าง

| โฟลเดอร์ | มีอะไร |
| --- | --- |
| [docs/design](docs/design) | spec ของ MVP เริ่มที่ [README](docs/design/README.md) |
| [docs/dev](docs/dev) | คู่มือ dev: วิธีรัน, ปุ่ม, เทสต์, โครงสร้างโค้ด, ข้อสมมติ และ [art contract](docs/dev/art-contract.md) |
| [data](data) | ตารางการ์ด, skill, ศัตรู, ค่าคงที่, Rebirth tree, เป้าหมาย run, perk เมือง (CSV) เกมอ่านตารางพวกนี้ตอนเริ่ม |
| [src](src) | โค้ด Godot: `core` ตรรกะเกม, `ui` หน้าจอ, `autoload/art.gd` ภาพทั้งหมด |
| [tests](tests) | เทสต์ headless |
| [tools](tools) | `balance_sim.py` จำลองการต่อสู้เพื่อจูนตัวเลข |

## เล่น (prototype)

เปิดโฟลเดอร์นี้ด้วย Godot 4.4 ขึ้นไป (renderer GL Compatibility) แล้วกด Play หรือ

```
godot --headless --path . --import   # ครั้งแรกครั้งเดียว
godot --path .
```

ตอนนี้ทำถึงเฟส 2: loop สุ่มใหม่ทุก run, เดินและสู้อัตโนมัติ, เลเวลและแต้มสถานะ, บอสรอบ 10,
มือการ์ด วาง/รวมการ์ด, combo ของ tile 4 แบบ, เลือกการ์ดทุกรอบ ยังไม่มีเมือง ไอเทม และ Rebirth tree
ปุ่มและวิธีรันเทสต์อยู่ใน [docs/dev](docs/dev/README.md)

## เครื่องมือ balance

```
python3 tools/balance_sim.py            # บอสค่าเริ่มต้น 950 HP / 16 ATK
python3 tools/balance_sim.py 1000 18    # ลองค่าบอสอื่น
```
