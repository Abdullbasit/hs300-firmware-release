# HS300 drive firmware — released images

Ready-to-flash firmware for the HS300 solar pump drive (STM32F334R8), one proven
image per board, plus the tools to put it on a drive.

**The firmware is inside `hs300-release.7z`, which is encrypted.** You need the
password from the engineer. Everything else is automatic.

## Read these — no password needed

They are here in [`docs/`](docs/), readable right now in this browser, on a
phone, at the wellhead:

| | |
|---|---|
| [MANUAL.md](docs/MANUAL.md) | start here — ports, dashboard, settings, flashing |
| [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | **symptom first.** Everything in it really happened |
| [FAULT_CODES.md](docs/FAULT_CODES.md) | every fault and stop code, what caused it, what to do |
| [COMMS.md](docs/COMMS.md) | the serial protocol, the register banks, the capture ring |

**As PDF**, if you would rather print one or read it off a phone:
[MANUAL](docs/pdf/MANUAL.pdf) ·
[TROUBLESHOOTING](docs/pdf/TROUBLESHOOTING.pdf) ·
[FAULT_CODES](docs/pdf/FAULT_CODES.pdf) ·
[COMMS](docs/pdf/COMMS.pdf) ·
**[the complete manual, all four in one](docs/pdf/HS300_COMPLETE_MANUAL.pdf)**.

All of it is inside the archive too, so it is on the laptop offline once
`SETUP.bat` has run - `docs\` beside the boards, with `docs\pdf\` in it.

## First time on a laptop

Download **`SETUP.bat`** on its own and double-click it. It installs git, Python,
pyserial and 7-Zip if they are missing, downloads this repository, asks for the
password, unpacks the firmware, and checks the flashing tool actually runs.

## Later

**`UPDATE.bat`** — run it where there is internet, before going to site. It
fetches new firmware and asks for the same password. Afterwards everything works
offline; flashing needs only the serial cable.

## Then

```
CHECK_SENSOR.bat COM5          check the drive's DC current sensor first
FLASH.bat <BOARD> COM5         put the firmware on the drive
```

`FLASH.bat` with no arguments lists the boards it has. Change `COM5` to your
USB-RS485 adapter's port.

### Always run CHECK_SENSOR on a board you have not flashed before

New boards leave the factory with the DC current offset pot at 2.5 V; it must be
turned down to about 0.5 V. A board left at 2.5 V does **not** fault — it reports
a flat maximum current, the tracker parks on that false ceiling believing it is
the array's limit, and roughly a tenth of the array goes unused with nothing
complaining. One board ran that way for a whole morning.

## What you get

    <BOARD>/STABLE/   the image to flash, and a full_*.hex for a virgin board
    <BOARD>/LATEST/   the newest build - engineer only, do not flash it
    bootloader/       the bootloader alone, for recovering a damaged one
    tools/            the Python tools the .bat files call

Each `STABLE` folder has a **`FLASH_ME.txt`** with the exact command, the CRC,
and the two lines that must appear for the flash to have worked:

    verified and marked bootable
    NEW app is up

If you do not see **both**, the drive did not take it.

## Rules

- A board with **no STABLE** has never been proven. Ask the engineer; do not
  flash `LATEST` on your own judgement.
- An OTA that stalls part way needs SWD recovery, not another attempt. Stop and
  ask.
- A **brand new board cannot be flashed over serial at all** — there is no
  bootloader yet. Use the `full_<BOARD>_<CRC>.hex` with an ST-Link, and **mass
  erase the chip first**.
- Do not edit this folder. It is published output; `UPDATE.bat` replaces it
  wholesale with a clean copy, so anything you leave in it is lost. Your port
  marker file is the one thing kept — keep notes and logs somewhere else.
