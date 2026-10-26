# คู่มือ dev (Godot prototype)

โปรเจกต์ Godot 4.4+ อยู่ที่ root ของ repo (`project.godot`) เปิดด้วย Godot 4.4 หรือใหม่กว่า (ทดสอบกับ 4.4.1, renderer GL Compatibility)
ตัวเลขเกมทั้งหมดอยู่ใน `data/*.csv` แก้ CSV แล้วรันใหม่ได้เลย ไม่ต้อง build

## รัน

```
godot --path .                       # เล่นปกติ (หน้าต่าง 1440x810 = 480x270 x3) เริ่มที่หน้าหลัก (Rebirth tree)
godot --path . -- --seed 42          # ข้ามหน้าหลัก เริ่ม run ด้วย seed เดิมซ้ำ (loop เดียวกัน การ์ดเดียวกัน)
godot --path . -- --speed 4 --bot mix  # ให้บอทเล่นแทนที่ x4
```

เกมเก็บ Rebirth point และ Rebirth tree ไว้ที่ `user://profile.json` (ตั้งค่าอยู่ที่ `user://settings.cfg`) ลบไฟล์นี้เพื่อเริ่มใหม่
รันแบบ `--headless` (เทสต์) จะไม่อ่านหรือเขียนไฟล์ทั้งสอง

หลัง clone ครั้งแรกให้ import ก่อนหนึ่งรอบ เพื่อสร้าง class cache: `godot --headless --path . --import`

### หน้าจอ

- **หน้าหลัก (HOME)** Rebirth tree (คลิก node เพื่อซื้อ), รูป loop ตัวอย่างของ run หน้า พร้อมปุ่มสุ่มใหม่ (ต้องซื้อ node "แผนที่ร่าง" ก่อน), ปุ่มเริ่ม run (Enter / Space)
- **run (RUN)** แผนที่ซ้าย, แผงขวา 4 แท็บ, มือการ์ดล่าง, แจ้งเตือนเรียงที่แผงขวา ตอนจบ run มีปุ่ม Rebirth tree / เล่นใหม่ / seed เดิม
- **ตั้งค่า** ปุ่มเฟืองที่แผงขวา: เปิดแผงเองตอนครบรอบ, หยุดเกมตอนเปิดแผง, ใส่ของที่ดีกว่าอัตโนมัติ, พื้นหลัง, ออกจาก run ไปหน้าหลัก

### ปุ่ม

| ปุ่ม | ทำอะไร |
| --- | --- |
| คลิกการ์ด แล้วคลิกช่อง (หรือลากการ์ดไปวาง) | วางการ์ด ช่องที่วางได้ไฮไลต์ ถ้าวางแล้ว merge/combo จะบอกในกล่องมุมขวาล่าง |
| skill card: คลิก/ลากไปช่อง skill ที่แผงแท็บฮีโร่ | ใส่ / merge / เปลี่ยน skill (ใบเดิมกลับเข้ามือ) |
| คลิกแถวแจ้งเตือนที่แผงขวา | เปิดแผงเลือก (แต้ม stat, การ์ดรอบ, skill card, ไอเทม, perk เมือง, ร้านค้า, event) |
| คลิกขวา / Esc | ยกเลิกการ์ดที่ถืออยู่ ปิดหน้าต่าง |
| Space | หยุด / เล่นต่อ |
| 1 / 2 / 3 (หรือ 4) | ความเร็ว x1 / x2 / x4 |
| N | เปิดแจ้งเตือนถัดไป |
| L | ดู log การต่อสู้ |
| Tab | สลับแท็บแผงขวา (ฮีโร่ / เมือง / เป้าหมาย / สู้ล่าสุด) |
| B | สลับสีพื้นหลัง (ทะเล / ทุ่งหญ้า / กระดาษเก่า / น้ำเงินเข้ม) เพื่อเทียบ art direction |
| R / Shift+R | เริ่ม run ใหม่ (seed ใหม่ / seed เดิม) |
| F1 | แสดงข้อมูล debug |
| F3 / F4 / F9 | debug: เลเวลอัป / แจกการ์ด 3 ใบ / เปิด-ปิดบอท |

### อาร์กิวเมนต์ (หลัง `--`)

`--seed N`, `--speed 0|1|2|4`, `--bot str|agi|int|mix`, `--fast SEC` (จำลองไปข้างหน้า SEC วินาทีก่อนเริ่มวาด; `--fast-bot` ให้บอทเล่นระหว่างนั้น),
`--open stat|card|skill_card|item|shop|town_perk|event` (เปิดแผงแรกของชนิดนั้น), `--hold N` (ถือการ์ดช่อง N), `--demo` (เติมแจ้งเตือนทุกชนิดไว้ดู UI),
`--home` (เริ่มที่หน้าหลัก), `--rp N` (แจก Rebirth point ไว้ถ่ายภาพ), `--profile PATH|none` (ไฟล์ profile; `none` = ไม่เซฟ),
`--log`, `--bg N`, `--pause`, `--level-up`, `--debug`, `--mouse x,y`, `--shot out.png` (บันทึกภาพหน้าจอแล้วออก), `--shot-frames N`, `--quit-after SEC`

ตัวอย่างถ่ายภาพหน้าจอโดยไม่มีจอ: `xvfb-run -a godot --path . --rendering-driver opengl3 -- --seed 7 --fast 60 --shot /tmp/a.png`

## เทสต์

```
godot --headless --path . --import
godot --headless --path . --script tests/run_tests.gd              # ทุกชุด
godot --headless --path . --script tests/run_tests.gd -- battle    # เฉพาะชุดที่ชื่อมี "battle"
godot --headless --path . --script tests/ui_smoke.gd               # โหลดฉากหลักแล้วจำลองเมาส์/คีย์บอร์ด
godot --headless --path . --script tests/sweep.gd -- 30 str mix    # ไม่ใช่เทสต์: บอทเล่น 30 seed ต่อ build แล้วสรุปอัตราชนะ
```

- `test_loop` loop ที่สร้างต้องเป็นเส้นปิดเดียว ไม่มีช่องถนนติดกันที่ไม่ใช่ลำดับกัน ทุกช่องถนนมีช่องริมทางว่าง ฯลฯ ตรวจหลาย seed
- `test_battle` กลไกต่อสู้ (ดาเมจ, crit, สกิล, โล่มานา, boss)
- `test_parity` ผลต่อสู้ต้องใกล้เคียง `tools/balance_sim.py` (ต่างกันไม่เกิน ~1%) สร้างฮีโร่ในเทสต์เองให้เหมือน `balance_sim.make_hero` (gear และ skill เฉลี่ยตามรอบ)
- `test_run` ลำดับเกมจริง: เดิน, ชน, เลเวล, ครบรอบ, วางการ์ด, merge (รวม L1 สี่ใบ = L3), combo, จบ run, ผลลัพธ์ไม่ขึ้นกับความเร็วเกม
- `test_town` กลุ่มอาคาร ระดับหมู่บ้าน/เมือง perk 9 แบบ และโจรที่เมืองดึงมา
- `test_items` ไอเทม (rarity, stat รอง, ช่อง, ล้นแล้วแปลงเป็น XP), skill card (ใส่/merge/เปลี่ยน), event 5 แบบ
- `test_meta` เป้าหมายของ run, RP, Rebirth tree (ซื้อ/ล็อก/ปลดล็อกการ์ดและ skill), save/load profile
- `ui_smoke` เมาส์/คีย์จริงบนฉากหลัก: วางการ์ด, แต้ม stat, Tab, เลือก skill card แล้วใส่ช่อง skill, event, ตั้งค่า, หน้าหลัก แล้วให้บอทเล่นจนจบเพื่อให้ทุก view วาดสถานะจริง

## โครงสร้างโค้ด

```
src/core/   ตรรกะเกมล้วน ๆ (RefCounted, ไม่มี Node) เทสต์ได้โดยไม่ต้องมีจอ
  game_db.gd        โหลด CSV -> GameDb (EnemyDef, SkillDef, CardDef, ComboDef) + ค่าคงที่ constants.csv
  loop_generator.gd สร้าง loop ใหม่ทุก run จาก seed
  board.gd          ชนิดช่อง (ทะเล/ที่โล่ง/ริมทาง/ถนน/ค่าย), เพื่อนบ้าน, ช่องริมทางของถนน
  hero.gd           เลเวล, XP, แต้ม (STR/AGI/INT), สูตรสถานะ
  foe.gd            ศัตรูหนึ่งตัว (สเกลตามรอบ, elite, boss)
  battle.gd         เอนจินต่อสู้อัตโนมัติ step ละ 0.05 วินาที ให้ event และ log ภาษาไทย
  card_rules.gd     กติกาวางการ์ด, merge (นับครึ่งสำหรับ L1 ทับ L2), combo 4 แบบ, ผลของการ์ดภูมิประเทศ/อาคาร/จุดเกิดศัตรู
  card_inst.gd      การ์ดหนึ่งใบ (tile หรือ skill card, level, progress)
  town.gd           หากลุ่มอาคารติดกันใหญ่สุด -> ระดับ (หมู่บ้าน 3 / เมือง 6) และช่องที่เมืองคลุม
  item.gd           ไอเทม (ช่อง, rarity, stat หลัก/รอง) + สุ่มตาม luck
  run_events.gd     event "?" 5 แบบ: ตัวเลือก + ผล
  run_goals.gd      เป้าหมายของ run (สุ่ม 3 ข้อ จ่าย RP ทันทีที่ครบ)
  meta.gd           Rebirth point, Rebirth tree (rank, ปลดล็อก), สถิติ run, save/load profile
  run_state.gd      สถานะ run ทั้งหมด + advance(dt) + signal ให้ UI ฟัง (รอบ, ต่อสู้, เมือง/perk, ไอเทม, skill card, event, เป้าหมาย)
  notice.gd         แจ้งเตือนหนึ่งอัน (stat | lap_card | skill_card | item | shop | town_perk | event | info)
  bot.gd            บอทเล่นอัตโนมัติ (ใช้ในเทสต์และปรับบาลานซ์) ตอบแจ้งเตือนทุกชนิด
src/autoload/art.gd  แหล่งรูปทั้งหมด (PNG จริงถ้ามี ไม่มีก็วาด placeholder จากโค้ด)
src/ui/              วาดด้วยโค้ดบนกริด 480x270 (ui_theme.gd เก็บตำแหน่งและสี) game.gd คือ root ที่รับ input และสลับหน้าจอ
                     map_view / side_panel / hand_bar / top_bar / choice_panel (แผงเลือกทุกชนิด) / home_view / end_panel / settings_view
tests/               ชุดเทสต์ (ดูด้านบน)
```

หลักการสำคัญ

- **ตรรกะแยกจาก UI** `RunState.advance(dt)` เดินเกมด้วย step คงที่ 0.05 วินาที ความเร็วเกมแค่เรียก advance หลายรอบ ผลลัพธ์จึงเหมือนกันทุกความเร็ว
- **สุ่มแบบ deterministic** seed เดียวต่อ run แยก stream ของ loop / การ์ด / การเกิดศัตรู / การต่อสู้ ใช้ `--seed` ทำซ้ำบั๊กได้
- **ข้อมูลอยู่ใน CSV** `data/constants.csv` (ขนาดกระดาน, ความยาว loop, ตัวคูณ, ขนาดมือ, ค่าเมือง/ไอเทม/event ฯลฯ), `skill_levels.csv`, `card_levels.csv`, `card_text.csv`, `combos.csv`,
  `town_perks.csv`, `item_stats.csv`, `events.csv`, `run_goals.csv`, `rebirth_tree.csv` เพราะตัวเลขในโค้ดไม่ควรมี
  ไฟล์ CSV ต้องมี `.csv.import` แบบ `importer="keep"` (มีใน repo แล้ว) ไม่งั้น Godot จะไม่รวมเข้าตอน export
- **จอ 480x270** ใช้ `stretch/mode=canvas_items` + `scale_mode=integer` (ไม่ใช้ `viewport` ตามที่ spec 07-ux เขียน) เพราะโหมด viewport เรนเดอร์ฟอนต์ไทยที่ 6-7 px
  ที่ความละเอียด 480x270 จริง ตัวอ่านไม่ออก โหมดนี้ sprite ยังเป็น pixel เป๊ะ (snap + nearest) แต่ตัวอักษรคมตามความละเอียดหน้าต่าง

## ข้อสมมติที่ทำไว้ (spec ยังไม่ระบุ)

เรื่องที่ตัดสินเองเพื่อให้เล่นได้ เปลี่ยนได้ในที่เดียว (ส่วนใหญ่อยู่ `data/constants.csv`):

1. **ศัตรูป่า** (ไม่ได้มาจากการ์ด) เป็นกลุ่มละ 2 ตัว จำนวนกลุ่มต่อรอบ = 2 + floor(รอบ/3)
2. **อาคาร** นับว่า "ติดกัน" แบบ 4 ทิศ (บ้านผีสิงนับ 0 หลังแต่ยังต่อกลุ่มได้) ส่วน combo ของการ์ดภูมิประเทศใช้ 8 ทิศตามตาราง combos.csv
3. **มือเริ่มต้น** = ภูมิประเทศ 1 + ศัตรู 1 + บ้าน 1 ใบ มือสูงสุด 10 ใบ ใบที่เกินทิ้งใบเก่าสุดแล้วได้ 5 XP
4. **ตัวเลือกการ์ดทุกรอบ** รับประกันอย่างน้อย 1 ใบจาก 3 เป็นใบที่มีอยู่แล้ว เพื่อให้ merge ได้ (merge-assist)
5. **merge L3** L1 ทับ L2 นับครึ่ง (ใบที่สองถึงขึ้น L3) ใช้กับทั้ง tile และ skill card ตาม "L3 = L1 สี่ใบ" ใน spec; L2 ทับ L2 ขึ้น L3 ทันที
6. **RP ไม่หายเมื่อตาย** RP จากเป้าหมายที่ครบแล้วเก็บไว้แม้ run จบด้วยการตาย; ฆ่าบอสได้ +2 RP
7. **gear_standin ถูกเอาออก** ฮีโร่ไม่มี gear เฉลี่ยแล้ว พลังมาจากไอเทมที่ดรอป (สุ่มตามรอบ/luck) และ skill card จริง ความยากจึงขึ้นกับดรอป
8. **โจรจากเมือง** เมืองแต่ละระดับที่ถึงแล้วเรียกโจร 1 กลุ่ม (2 ตัว) ลงช่องถนนว่างที่ใกล้ที่สุดทุกรอบ
9. **perk เมือง** ถึงระดับ 1 และ 2 แต่ละครั้งเลือก 1 จาก 3 (ไม่ซ้ำ) perk ทำงานเฉพาะตอนเมืองยังไม่ต่ำกว่าระดับที่เลือกมา
10. **ไอเทม** rarity 70/25/5 ขยับตาม luck และโรงตีเหล็ก; ค้างรอตัดสินใจได้ไม่เกิน 5 ชิ้น ที่เกินแปลงเป็น XP (3 × เลเวล); ค่าเริ่มต้น "ใส่ของดีกว่าอัตโนมัติ" ปิดอยู่
11. **event "?"** เกิดบนช่องถนนว่าง 25% ต่อรอบ ไม่ปล่อยให้การ์ด encounter วางทับ; จ่ายด้วย HP ไม่ทำให้ตาย
12. **ปัญหา spec**: สกิล heal ต้องใช้ mana 40 แต่ mana สูงสุดตอนเริ่ม 30 ต้องลง INT ก่อนถึงจะใช้ได้ ควรเลือกว่าจะลดราคา heal หรือเพิ่ม mana พื้นฐาน
13. **จังหวะเกม** run ที่บอทชนะใช้เวลาราว 7 นาทีที่ x1 ส่วน spec ตั้งเป้า 12-18 นาที ปรับได้ที่ `walk_seconds_per_tile` / ความยาว loop หลัง playtest

## สถานะ

ระบบตาม build order ของเอกสารวิเคราะห์ครบทุกเฟส (loop, การ์ด, ต่อสู้, เมือง/perk, ไอเทม/skill card/event, เป้าหมาย run และ Rebirth tree) รอ playtest เพื่อปรับบาลานซ์และจังหวะ
