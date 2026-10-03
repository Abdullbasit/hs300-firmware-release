# Fault and stop codes

Read `FAULT_DETAIL` and `STOP_REASON` from the dashboard (`DASHBOARD.bat`) or
with `foc_diag.py`. `STS` gives the coarse state; `FAULT_DETAIL` says *why*.

Codes come from `drive/hs300_drive.h`. If a code here disagrees with the
firmware, the firmware is right — say so and this file gets fixed.

## Drive state — `STS`

| value | state | meaning |
|---|---|---|
| 0 | `OFF` | stopped, gates off |
| 1 | `ON` | running |
| 2 | `FAULT` | stopped by a fault; read `FAULT_DETAIL` |
| 3 | `FAULT_OC` | over-current |
| 4 | `FAULT_OV` | over-voltage |
| 5 | `FAULT_UV` | under-voltage |
| 6 | `FAULT_UV_WAIT` | waiting for the bus to come back |
| 7 | `FAULT_OT` | over-temperature |

`MODE`: 0 = MANUAL, 1 = MPPT, 2 = DCBUS.

## Over-current — 20 to 23

All four mean current, but not the same current, and the action differs.

| code | name | what tripped | first thing to check |
|---|---|---|---|
| 20 | `OC_ENVELOPE` | id²+iq² over the envelope | a real overload — pump jammed, sand, a dry well |
| 21 | `OC_TRACKING` | the current loop lost authority | the motor is not following: wrong tune, a weak bus, a failing phase |
| 22 | `OC_RMS_TOC` | RMS time-overcurrent, the **thermal** one | sustained overload rather than a spike. Check `F01` against the plate |
| 23 | `OC_INST` | instantaneous per-phase | a short or a shoot-through. **Do not just restart** — look for a fault in the power stage or the motor leads |

**23 is the serious one.** 20 and 22 usually mean the load; 23 usually means hardware.

## Insulation and winding — 30 to 32

| code | name | meaning | action |
|---|---|---|---|
| 30 | `INSUL_LEAK` | zero-sequence current — current going to earth | **a wet joint or a damaged cable, 70 m down.** Megger the motor and the cable before restarting |
| 31 | `WINDING_ASYM` | the three line-to-line resistances disagree | see the warning below before believing it |
| 32 | `PHASE_OPEN` | one lead broken, the other two intact | `PS_FLAGS` names which phase. Check the joints at the head first |

### 31 is often not what it says

**Read `PS_FLAGS` before trusting a 31.** If bit `0x4000` (`PS_F_OVERCUR`) is
set, a probe vector aborted on over-current and left *no measurement behind* —
that is not asymmetry at all. Fix the over-current cause and re-run.

A relay or an ADC-offset problem can also fake an open phase. That exact chain
cost a day on the grid board on 2026-09-19.

## Failed auto-tune — 40 to 48

`40 + failcode`. The drive is stopped and **not tuned**; it will not run closed
loop until a tune succeeds.

| code | meaning | usual cause |
|---|---|---|
| 41 | `Rs` measurement failed | no motor, an open phase, or current sensing wrong |
| 42 | the 40 Hz injection failed | could not drive enough current — weak bus, or `F01` too low |
| 43 | leakage inductance out of band | wrong plate, or the measurement is being clipped |
| 44 | **the rotor did not turn** | the most common. See below |
| 45 | the rotor dragged | something mechanical, or far too little bus |
| 46 | could not hold current | the bus sagged during the tune — tune on a stiff supply |
| 47 | the result disagrees with the nameplate | the plate is wrong, or it is not the motor you think |
| 48 | current abort | hit the limit; `F01` or the plate is wrong |

### 44 — the rotor did not turn

The gate behind 44 is derived from the **plate**, as `566 / plate_I_rms` mH.
So a plate current entered **too low RAISES the gate** and refuses a perfectly
good spin. Check the plate before touching anything else.

On the 22 kW well machine `PLATE_I_RMS` is deliberately **45 A**, not the 39 A
nameplate — that is intentional and documented. Do not "correct" it.

Tune on the stiffest supply you have. On PV at dawn there is not enough power
and you will chase a fault that is really a lack of watts.

## Clean stops that are **not** faults — 11 to 13

| code | meaning |
|---|---|
| 11 | a STOP arrived over the serial link (a tool or the dashboard) |
| 12 | `START_DEFER` — the bus could not carry the start, so the drive did not fight it |
| 13 | `LINGER` — it was running below pump cut-in on a falling sun and gave up |

**12 and 13 are correct behaviour**, not failures. They replaced a dawn pattern
of ten UV trips in a row: the I-f start needs roughly 750 W of magnetising
current and the array had 50–800 W. Probing and deferring is the fix.

## Pre-start check — `PS_FLAGS` bits

Run before every start unless `PRESTART_EN` is 0.

| bit | name | severity |
|---|---|---|
| 0x01 | `SKIPPED` | disabled by `PRESTART_EN` |
| 0x02 | `NO_MOTOR` | warn — all three pairs open, nothing connected |
| 0x04 | `R_HIGH` | warn — symmetric but high against the stored Rs |
| 0x08 | `LEAK` | **fail** — zero-sequence current |
| 0x10 | `ASYM` | **fail** — spread over the limit |
| 0x20 | `OPEN` | **fail** — one or two pairs open |
| 0x40 / 0x80 / 0x100 | `PH_U` / `PH_V` / `PH_W` | which phase the open pairs share |
| 0x200 / 0x400 / 0x800 | `RAIL_UV` / `RAIL_VW` / `RAIL_WU` | that vector railed the ADC |
| 0x4000 | `OVERCUR` | a vector aborted on over-current — **no measurement was taken** |

`PS_STATE`: 7 = pass, 8 = failed. `PS_VCODE` packs four bits per line-to-line
vector; 5 means that vector hit over-current.

**A start within about 2 seconds of a stop fails the pre-start** on a coasting
motor — the back-EMF looks like a fault. Wait, then start.
