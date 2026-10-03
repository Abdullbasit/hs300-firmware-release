# HS300 drive — maintenance manual

A 22 kW IGBT inverter driving a submersible pump from a PV array, from a
battery bus, or from a weak grid, depending on the build. Sensorless
field-oriented control with its own auto-tune; no encoder, nothing down the well but
the motor.

What you need in front of you: a laptop with this folder, a USB-RS485 adapter
(or the ST-Link's USB serial), and a multimeter.

## Tell the scripts where the drive is — once

```
PORT.bat
```

Double-click it. It lists the serial ports it can see, asks which one the drive
is on and which cable you are using, and makes the setting for you. Run it again
to check or change it.

`FLASH.bat`, `CHECK_SENSOR.bat`, `ZERO_ADC.bat` and `DASHBOARD.bat` then all
find the drive on their own and each says which setting it obeyed. If you start
one before setting a port, it asks you there and then - you are never left
stuck. A port typed on the command line always wins.

The setting is an empty file whose **name** is the whole thing:

```
tty4.485        COM4 over the USB-RS485 adapter
tty5.ttl        COM5 over the ST-Link USB serial / direct TTL
```

Keep one, not two - `PORT.bat` replaces the old one when you change it, because
whichever is found first would otherwise win and the other is a trap. Put it
here or one level up; both are searched.

**It is `tty`, not `com`.** Windows reserves COM1..COM9 as device names, over
the whole name before the first dot, so File Explorer refuses `com5.ttl` as an
invalid name. Some other tools create it anyway, which is worse rather than
better - the file exists but Explorer may then refuse to rename or delete it.
`port5.ttl` and `ccom5.ttl` also work, as does `.rs485` for `.485`.

A setting whose name cannot be read as a port is **reported**, not ignored, and
you are offered a replacement. One that cannot be understood must not look the
same as none at all.

## The dashboard

```
DASHBOARD.bat
```

Starts the agent and opens `http://localhost:8080`. Live telemetry, settings you
can edit, and the commands. This is the easiest way to see what the drive is
doing.

**It holds the serial port while it runs.** Nothing else can talk to the drive
at the same time — close that window before `FLASH.bat`, `CHECK_SENSOR.bat` or
`ZERO_ADC.bat`.

## In order, on a drive you have not met before

1. **`CHECK_SENSOR.bat`** — the DC current sensor's range. Do this first, every
   time, on any board you have not personally checked. Reason in the next
   section.
2. **`ZERO_ADC.bat`** — only with the **DC bus at zero volts**. It measures the
   offsets as they sit, so whatever is present becomes "zero" for ever.
3. **`FLASH.bat <BOARD> <COM>`** — the proven image for that board.
4. **`DASHBOARD.bat`** — check the plate, then run a tune, then a test run.

## Why CHECK_SENSOR comes first

New boards leave the factory with the DC current **offset pot at 2.5 V** and it
must be turned down to about **0.5 V**. On a 3.3 V ADC a 2.5 V rest point leaves
only about **27 A** of measurable current, and the sensor then simply **reports a
flat maximum** — no fault, no warning.

Because the MPPT verdict is `Vdc × Idc`, once the current rails the tracker sees
power *fall* whenever it loads harder, so it parks on that false ceiling and
reports it as the array's limit. One board ran that way for a whole morning with
roughly a tenth of the array unused and nothing complaining.

`CHECK_SENSOR.bat` catches it in two minutes. If it says FAIL, turn the pot down
until the rest point is near the bottom of the range, then `ZERO_ADC.bat`.

## Settings worth knowing

Edit from the dashboard, or by name with the tools. **Over the wire they are in
real units** — the panel's F-number and its ×10 scaling are a different thing.

| setting | what it is | watch out |
|---|---|---|
| `PLATE_KW`, `PLATE_V_LL`, `PLATE_F_HZ`, `PLATE_I_RMS`, `PLATE_PP`, `PLATE_RPM` | the motor nameplate | **everything** derives from this: the tune's current levels, the stall gate, `i_open`. A wrong plate is the most common cause of a tune that will not pass |
| `F01 OVER_CURRENT` | the trip | must be above what the pre-start itself draws, or the check trips |
| `F03 OVER_VOLTAGE` | bus OV trip | check it is **reachable** — on one board it sat above what the sensor could report |
| `F05 OVER_TEMP` | heatsink trip, 90 °C | 59 °C at full load on the 37K is normal |
| `F08 FMIN` / `F09 FMAX` | frequency limits | `FMAX` is the plate frequency. Going past it over-speeds the pump |
| `F10 ACC_FACTOR` | ramp rate | |
| `MODE` | 0 manual, 1 MPPT, 2 DC bus | **change it on the fly.** Stopping and restarting to change mode makes the tracker re-enter from the floor and the drive dives to minimum frequency |
| `AUTOSTART_EN` | starts on its own when the bus comes up | **leave 0 unless you mean it.** On a battery bus this once drained the pack flat overnight |

### Settings do not persist unless you save them

A write changes the live value only. **Without `SAVE_SETTINGS` it is lost at the
next reset**, and these boards reset often. The dashboard's save button sends it;
by hand it is `CMD_SAVE_SETTINGS`.

To *prove* a value is stored: save, then `CMD_RELOAD_EEPROM`, then read it back.
A plain read-back straight after a write tells you nothing.

## Normal readings, 22 kW well machine at full sun

```
f        48-50 Hz          Vdc     650-680 V
Idc      30-34 A           Pdc     20-22 kW
psi_r    0.985-0.99        iq      45-53 A peak
temp     55-60 C           BUS_SHED 1.000
```

`BUS_SHED` below 1.0 means the bus sagged and the drive softened the load. Brief
dips on a cloud edge are the design working. Sitting at 0.2 is not.

## Flashing

`FLASH.bat <BOARD> <COM>` uses the **STABLE** image for that board. It must print
**both** of these:

```
verified and marked bootable
NEW app is up
```

If you do not see both, the drive did not take it.

- **An OTA that stalls part way needs SWD recovery, not another attempt.** Stop
  and ask the engineer.
- A **virgin board cannot be flashed over serial at all** — there is no
  bootloader yet. Use `full_<BOARD>_<CRC>.hex` with an ST-Link and **mass erase
  the chip first**, or stale metadata will make the bootloader refuse the app.
- A board with **no STABLE** has never been proven. Ask; do not flash `LATEST`.

## Keep a record

`drive_backup.py` saves the EEPROM settings and the firmware CRC before you
change anything. Do it before a tune or a flash — it is the only way to get a
drive back to how it was.
