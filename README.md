# Loop Rebirth

roguelite แนว Loop Hero ที่ขยาย gameplay: loop เปลี่ยนทุก run, การ์ด tile และ skill card ที่ merge ได้,
เมืองที่โตไปพร้อม run, auto battle และ Rebirth tree สำหรับปลดล็อก utility กับการ์ดใหม่ สร้างด้วย Godot 4

## โครงสร้าง

| โฟลเดอร์ | มีอะไร |
| --- | --- |
| [docs/design](docs/design) | spec ของ MVP เริ่มที่ [README](docs/design/README.md) |
| [data](data) | ตารางการ์ด, skill, ศัตรู, Rebirth tree, เป้าหมาย run, perk เมือง (CSV) |
| [tools](tools) | `balance_sim.py` จำลองการต่อสู้เพื่อจูนตัวเลข |

```
python3 tools/balance_sim.py            # บอสค่าเริ่มต้น 950 HP / 16 ATK
python3 tools/balance_sim.py 1000 18    # ลองค่าบอสอื่น
```
