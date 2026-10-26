# คู่มือ dev (Godot prototype)

โปรเจกต์ Godot 4.4+ อยู่ที่ root ของ repo (`project.godot`) เปิดด้วย Godot 4.4 หรือใหม่กว่า (ทดสอบกับ 4.4.1, renderer GL Compatibility)
ตัวเลขเกมทั้งหมดอยู่ใน `data/*.csv` แก้ CSV แล้วรันใหม่ได้เลย ไม่ต้อง build

## รัน

```
godot --path .                       # เล่นปกติ (หน้าต่าง 1440x810 = 480x270 x3)
godot --path . -- --seed 42          # ใช้ seed เดิมซ้ำ (loop เดียวกัน การ์ดเดียวกัน)
godot --path . -- --speed 4 --bot 1  # ให้บอทเล่นแทนที่ x4
```

หลัง clone ครั้งแรกให้ import ก่อนหนึ่งรอบ เพื่อสร้าง class cache: `godot --headless --path . --import`

### ปุ่ม

| ปุ่ม | ทำอะไร |
| --- | --- |
| คลิกการ์ด แล้วคลิกช่อง (หรือลากการ์ดไปวาง) | วางการ์ด ช่องที่วางได้ไฮไลต์ ถ้าวางแล้ว merge/combo จะบอกในกล่องมุมขวาล่าง |
| คลิกขวา / Esc | ยกเลิกการ์ดที่ถืออยู่ ปิดหน้าต่าง |
| Space | หยุด / เล่นต่อ |
| 1 / 2 / 3 (หรือ 4) | ความเร็ว x1 / x2 / x4 |
| N | เปิดแจ้งเตือนถัดไป (แต้มสถานะ, การ์ดรอบ) |
| L | ดู log การต่อสู้ |
| Tab | สลับแท็บแผงขวา (ฮีโร่ / ต่อสู้ล่าสุด) |
| B | สลับสีพื้นหลัง (ทะเล / ทุ่งหญ้า / กระดาษเก่า / น้ำเงินเข้ม) เพื่อเทียบ art direction |
| R / Shift+R | เริ่ม run ใหม่ (seed ใหม่ / seed เดิม) |
| F1 | แสดงข้อมูล debug |
| F3 / F4 / F9 | debug: เลเวลอัป / แจกการ์ด 3 ใบ / เปิด-ปิดบอท |

### อาร์กิวเมนต์ (หลัง `--`)

`--seed N`, `--speed 0|1|2|4`, `--bot 1`, `--fast SEC` (จำลองไปข้างหน้า SEC วินาทีก่อนเริ่มวาด), `--open stat|card`, `--hold N` (ถือการ์ดช่อง N),
`--log`, `--bg N`, `--pause`, `--level-up`, `--debug`, `--mouse x,y`, `--shot out.png` (บันทึกภาพหน้าจอแล้วออก), `--shot-frames N`, `--quit-after SEC`

ตัวอย่างถ่ายภาพหน้าจอโดยไม่มีจอ: `xvfb-run -a godot --path . --rendering-driver opengl3 -- --seed 7 --fast 60 --shot /tmp/a.png`

## เทสต์

```
godot --headless --path . --import
godot --headless --path . --script tests/run_tests.gd              # ทุกชุด
godot --headless --path . --script tests/run_tests.gd -- battle    # เฉพาะชุดที่ชื่อมี "battle"
godot --headless --path . --script tests/ui_smoke.gd               # โหลดฉากหลักแล้วจำลองเมาส์/คีย์บอร์ด
godot --headless --path . --script tests/sweep.gd                  # ไม่ใช่เทสต์: บอทเล่นหลาย seed แล้วสรุปอัตราชนะ
```

- `test_loop` loop ที่สร้างต้องเป็นเส้นปิดเดียว ไม่มีช่องถนนติดกันที่ไม่ใช่ลำดับกัน ทุกช่องถนนมีช่องริมทางว่าง ฯลฯ ตรวจหลาย seed
- `test_battle` กลไกต่อสู้ (ดาเมจ, crit, สกิล, โล่มานา, boss)
- `test_parity` ผลต่อสู้ต้องใกล้เคียง `tools/balance_sim.py` (ต่างกันไม่เกิน ~1%)
- `test_run` ลำดับเกมจริง: เดิน, ชน, เลเวล, ครบรอบ, วางการ์ด, merge, combo, จบ run, ผลลัพธ์ไม่ขึ้นกับความเร็วเกม

## โครงสร้างโค้ด

```
src/core/   ตรรกะเกมล้วน ๆ (RefCounted, ไม่มี Node) เทสต์ได้โดยไม่ต้องมีจอ
  game_db.gd        โหลด CSV -> GameDb (EnemyDef, SkillDef, CardDef, ComboDef) + ค่าคงที่ constants.csv
  loop_generator.gd สร้าง loop ใหม่ทุก run จาก seed
  board.gd          ชนิดช่อง (ทะเล/ที่โล่ง/ริมทาง/ถนน/ค่าย), เพื่อนบ้าน, ช่องริมทางของถนน
  hero.gd           เลเวล, XP, แต้ม (STR/AGI/INT), สูตรสถานะ
  foe.gd            ศัตรูหนึ่งตัว (สเกลตามรอบ, elite, boss)
  battle.gd         เอนจินต่อสู้อัตโนมัติ step ละ 0.05 วินาที ให้ event และ log ภาษาไทย
  card_rules.gd     กติกาวางการ์ด, combo 4 แบบ, ผลของการ์ดภูมิประเทศ/อาคาร/จุดเกิดศัตรู
  run_state.gd      สถานะ run ทั้งหมด + advance(dt) + signal ให้ UI ฟัง
  bot.gd            บอทเล่นอัตโนมัติ (ใช้ในเทสต์และปรับบาลานซ์)
src/autoload/art.gd  แหล่งรูปทั้งหมด (PNG จริงถ้ามี ไม่มีก็วาด placeholder จากโค้ด)
src/ui/              วาดด้วยโค้ดบนกริด 480x270 (ui_theme.gd เก็บตำแหน่งและสี) game.gd คือ root ที่รับ input
tests/               ชุดเทสต์ (ดูด้านบน)
```

หลักการสำคัญ

- **ตรรกะแยกจาก UI** `RunState.advance(dt)` เดินเกมด้วย step คงที่ 0.05 วินาที ความเร็วเกมแค่เรียก advance หลายรอบ ผลลัพธ์จึงเหมือนกันทุกความเร็ว
- **สุ่มแบบ deterministic** seed เดียวต่อ run แยก stream ของ loop / การ์ด / การเกิดศัตรู / การต่อสู้ ใช้ `--seed` ทำซ้ำบั๊กได้
- **ข้อมูลอยู่ใน CSV** `data/constants.csv` (ขนาดกระดาน, ความยาว loop, ตัวคูณ, ขนาดมือ ฯลฯ), `skill_levels.csv`, `card_levels.csv`, `card_text.csv`, `combos.csv` ถูกเพิ่มจาก phase 0 เพราะตัวเลขในโค้ดไม่ควรมี
  ไฟล์ CSV ต้องมี `.csv.import` แบบ `importer="keep"` (มีใน repo แล้ว) ไม่งั้น Godot จะไม่รวมเข้าตอน export
- **จอ 480x270** ใช้ `stretch/mode=canvas_items` + `scale_mode=integer` (ไม่ใช้ `viewport` ตามที่ spec 07-ux เขียน) เพราะโหมด viewport เรนเดอร์ฟอนต์ไทยที่ 6-7 px
  ที่ความละเอียด 480x270 จริง ตัวอ่านไม่ออก โหมดนี้ sprite ยังเป็น pixel เป๊ะ (snap + nearest) แต่ตัวอักษรคมตามความละเอียดหน้าต่าง

## ข้อสมมติที่ทำไว้ (spec ยังไม่ระบุ)

เรื่องที่ตัดสินเองเพื่อให้เล่นได้ เปลี่ยนได้ในที่เดียว (ส่วนใหญ่อยู่ `data/constants.csv`):

1. **ฮีโร่ใช้ gear/สกิลเฉลี่ยแทน** ตั้งแต่ยังไม่มีไอเทมและ skill card ใช้ `gear_standin=1` ให้ gear และเลเวลสกิลโตตามรอบเหมือน `balance_sim.py`
   สกิลเริ่มต้นคือ fireball + cleave พอมีไอเทมและ skill card จริง ตั้ง `gear_standin=0` แล้วของจริงมาแทน
2. **ศัตรูป่า** (ไม่ได้มาจากการ์ด) เป็นกลุ่มละ 2 ตัว จำนวนกลุ่มต่อรอบ = 2 + floor(รอบ/3)
3. **อาคาร** (บ้าน ฯลฯ) นับว่า "ติดกัน" แบบ 4 ทิศ ส่วน combo ของการ์ดภูมิประเทศใช้ 8 ทิศตามตาราง combos.csv
4. **มือเริ่มต้น** = ภูมิประเทศ 1 + ศัตรู 1 + บ้าน 1 ใบ มือสูงสุด 10 ใบ ใบที่เกินทิ้งใบเก่าสุดแล้วได้ 5 XP
5. **ตัวเลือกการ์ดทุกรอบ** รับประกันอย่างน้อย 1 ใบจาก 3 เป็นใบที่มีอยู่แล้ว เพื่อให้ merge ได้ (merge-assist)
6. **ปัญหา spec**: สกิล heal ต้องใช้ mana 40 แต่ mana สูงสุดตอนเริ่ม 30 ต้องลง INT ก่อนถึงจะใช้ได้ ควรเลือกว่าจะลดราคา heal หรือเพิ่ม mana พื้นฐาน

## ยังไม่ได้ทำ (รอ playtest เฟส 2)

เมือง/perk, ไอเทม/สกิลการ์ด/เหตุการณ์, Rebirth tree และ meta ตามลำดับ build order ในเอกสารวิเคราะห์ (เฟส 3 ขึ้นไป) จะทำต่อหลัง playtest เฟส 2
