# Troubleshooting — symptom first

Every entry here is something that actually happened on this plant, with what it
turned out to be. For codes, see `FAULT_CODES.md`.

## The drive will not talk

| symptom | cause | fix |
|---|---|---|
| no reply at all | wrong baud | the baud is **per drive** (`BAUD_COM2`); this plant's well drive is **9600**. Tools scan it now and say so |
| a tool says "no drive ... silent at every baud" | the drive, not the PC | the port opened, so it is not the laptop. Powered? A/B on **COM2**, not COM1? Polarity? |
| no reply, port opens | the dashboard is running | it **holds the port** — close that window |
| `Access is denied` on the port | another tool still has it | close it; a killed shell can leave its Python child holding the port |
| port vanished entirely | the drive is unpowered | on a PV build the adapter dies with the bus. Check the array |
| reads work, numbers are nonsense | the PC map does not match the firmware | run `check_link_api.py`; re-run `UPDATE.bat` to refresh `tools/` |

## It runs, but not as well as it should

| symptom | cause | fix |
|---|---|---|
| frequency sits well below `FMAX` in good sun | the **slip cap** fed by a noisy rotor estimate | the rotor estimate swings ±3 Hz; if the cap's input is lightly filtered its noise minima clamp the setpoint. Fixed in firmware by filtering harder — make sure the drive has a current image |
| power seems capped at a round number and will not rise | the **DC current sensor is railing** | run `CHECK_SENSOR.bat`. See `MANUAL.md` — the offset pot |
| tracker parks low and will not climb | wrong MPPT margin | `F12` is the margin ×10. A stale EEPROM value of 35 means margin 3.5, which parks far short |
| climbs, collapses, climbs again, about once a minute | the margin is too aggressive for that irradiance | the MPP of a constant-power load is a **cliff**, not a hill — overshoot does not cost a little power, it costs the run. Raise `F12` |
| water stops at dusk but no fault | `LINGER` (13) | correct behaviour — it was below pump cut-in and stopped fighting |

**A useful cross-check:** compare `FOC_PEST` against `VDC × IDC`. Motor power
cannot exceed DC input power. If the ratio jumps above ~1.0, the DC current
reading is wrong — that is what exposed the railed sensor.

## Starting

| symptom | cause | fix |
|---|---|---|
| pre-start fails right after a stop | the motor is still coasting; back-EMF looks like a fault | wait ~2 s and start again |
| pre-start reports an open phase that is not open | relay or ADC-offset chain | cost a day on the grid board, 2026-09-19. Check the relay actually pulled in, and the offsets |
| asymmetry (31) that makes no sense | a probe vector aborted on over-current, leaving no measurement | check `PS_FLAGS` for `0x4000` first |
| ten UV trips in a row at dawn | not enough array to magnetise | expected on a weak morning. `START_DEFER` (12) now handles it |
| drive reads 25 V on a live 510 V bus and sits in `FAULT_UV_WAIT` | wrong `V_DC_SENSED_OFFSET` for that board variant | wrong image for the board. Check which variant it is |

## Tuning

| symptom | cause |
|---|---|
| fault 44, rotor did not turn | **check the plate first.** The gate is `566 / plate_I_rms` mH, so a plate current entered *too low raises* the gate |
| tune fails only on PV, passes on a stiff supply | not enough watts. Tune on the stiffest supply available |
| tune passes but disagrees with the plate (47) | it may not be the motor you think it is |
| sigma-Ls looks too high | dead time. It stays at the shared 188 — under-compensating inflates apparent sigma-Ls and turns a marginal tune into a reliable 44 |

## Flashing

| symptom | cause | fix |
|---|---|---|
| OTA stalls part way | an old bootloader (`CAB6EC2A`) cannot be repaired over serial | SWD recovery. Check which bootloader the drive runs before blaming the cable |
| every app "dies at boot" after a bootloader flash | a **Debug** bootloader was flashed — 4260 B into a 4096 B slot, overrunning the app region | flash the `-Os` Release bootloader, 3268 B, from `bootloader/` |
| new app refuses to boot after SWD | stale OTA metadata: it carries the *old* image's length and CRC | **mass erase** first; leave `0x0800F800` erased |
| random OTA corruption over RS485 | an auto-direction adapter clipping the last byte | fixed in bootloader `18274D72` with a pad byte, reply lead and per-chunk CRC. Check the bootloader version |
| `FLASH.bat` refuses the board | no STABLE image for it — nobody has proven one | ask the engineer. Do **not** flash `LATEST` on your own judgement |

## Settings that will not stick

The usual cause is no `SAVE_SETTINGS` — a write is RAM only and dies at the next
reset, and these boards reset often. One board showed 104 resets.

It looks exactly like the drive "reverting" a good write. It is not. Save, then
`RELOAD_EEPROM`, then read back.

## Things that look like faults and are not

- `STOP_REASON` **11** — somebody sent a stop over the link. Including a tool.
- `STOP_REASON` **12 / 13** — deliberate probes, not failures.
- `BUS_SHED` dipping on a cloud edge — the droop doing its job.
- `FOC_TUNE_STS` reading 33 — it is **packed**, not a plain flag:
  `tuned + 2×fail + 4×(state & 0xF) + 64×(failcode & 0xF)`. A healthy tune parked
  at the last stage reads `1 + 4×8 = 33`.
- `MEAS_*` registers reading 0 while `TEMP`, `VDC`, `IDC` are live — that mirror
  group is unpopulated. Cosmetic.
- `MOD_IDX` reading a flat 0.2000 — also unpopulated. Use `FOC_VDEM` against
  `Vdc/√3` instead.

## When to stop and ask

- `OC_INST` (23) — likely hardware, not load.
- `INSUL_LEAK` (30) — megger the motor and cable **before** restarting. There is
  a wet joint 70 m down until proven otherwise.
- An OTA that stalled part way.
- Anything where the fix would mean changing a protection limit.
