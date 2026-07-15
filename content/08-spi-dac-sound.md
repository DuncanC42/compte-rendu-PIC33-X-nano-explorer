# Sound Generation Project (SPI + DAC) — First Tone

In this lab you make the board **play sound**. The on-board speaker is not driven directly by the microcontroller: it is fed by an **MCP4821 DAC** connected over **SPI**. So generating sound means learning SPI and driving a DAC — two objectives in one.

The project is built in stages: first get a signal out of the DAC, then make it audible. Shaping real waveforms is the next lab.

## Goals

In this lab you will:

- Configure the **SPI** peripheral as a host (master)
- Understand and build the **MCP4821 command frame**
- Output a voltage from the DAC and verify it on an oscilloscope
- Produce an audible tone through the speaker

The tools involved are the **MCP4821 DAC**, the **speaker circuit**, and an **oscilloscope** to observe the signal.

## Background — the audio chain

The microcontroller never touches the speaker. It sends 12-bit samples over SPI to the DAC, which converts them to a voltage; that voltage goes through the board's audio amplifier and finally reaches the speaker. Every arrow in that chain crosses a **jumper** — and any missing jumper means total silence.

[DIAGRAM: "audio-chain" — Horizontal block chain, left to right: [dsPIC33CK] with four labelled output pins stacked on its right edge: "SDO1 / MOSI (RC0)", "SCK1 (RC2)", "DAC CS (RB14)", "SPKR_EN (RC6)". The MOSI/SCK/CS lines each cross a small removable-bridge jumper symbol (two dots + bar), labelled "SPI MOSI", "SPI SCK", "DAC CS (IO26)". They enter [MCP4821 DAC] (note inside: "LDAC: tied low on board — not routed to the µC"). From the DAC, "DAC OUT" crosses another jumper "DAC OUT ↔ SPEAKER IN" into [Amplifier], which has two switch symbols drawn on it: "GAIN LOW/HIGH" and "ON/OFF", plus an enable input fed by the SPKR_EN line crossing its own jumper "SPEAKER ENABLE (IO12)". The amplifier output goes to a [Speaker] icon. Draw every jumper in a warning colour (orange) — they are the failure points. Caption: "Five jumpers and two switches sit between your code and the sound."]

## Part 1 — Your mission

Each step states a task and where to look. Solve them in order; the full correction is at the end of the document.

### Step 1 — Understand the DAC command frame

**Task.** Open the MCP4821 datasheet and find the *Write Command Register* figure (section 5.0, Serial Interface). The DAC receives a **16-bit word** over SPI. Work out the bits you must send to output a value on **channel A**, with **gain ×1** and the **output active**. What is the final 16-bit word for a 12-bit sample `value`? In which byte order is it transmitted?

### Step 2 — Identify the pins

**Task.** Using the *Curiosity Nano Explorer* pin mapping, find which dsPIC pin carries each of these signals: **SPI MOSI**, **SPI SCK**, **DAC CS**, **SPEAKER ENABLE**. Also check the **DAC LDAC** line — what do you notice about it? And one naming subtlety: the DAC's data pin is called **SDI** — which µC signal drives it, and why is that not a contradiction?

### Step 3 — Configure SPI and the GPIOs in MCC

**Task.** In MCC Melody, add and configure the SPI peripheral as a host, and add the two GPIO outputs you need. What settings do you choose for: mode, communication width, clock speed, and SPI mode (clock polarity / sampling edge)? Which pins do you assign, and which SPI signals do you deliberately leave unassigned?

### Step 4 — Physical setup (the part that bites)

**Task.** On this board, signals reach peripherals through **jumpers**. Using the Background diagram and the board itself, list *everything* that must be physically connected for the SPI to reach the DAC and for the DAC to reach the speaker — including anything outside the remapping area (switches count).

### Step 5 — Write the DAC output function

**Task.** Write a function `DAC_Write(uint16_t value)` that sends one sample to the DAC over SPI, using the frame from Step 1 and the API `SPI1_Exchange8bit(uint8_t)`. When exactly does the DAC output voltage actually update?

### Step 6 — Make a tone

**Task.** Using `DAC_Write`, produce an audible **square wave** at roughly 440 Hz by alternating between two levels. Remember to enable the amplifier first. What does `main` look like, and what peak-to-peak voltage do you expect at the DAC output?

### Step 7 — Verify on the oscilloscope

**Task.** Probe the DAC output with the analog oscilloscope and freeze a clean square wave on screen. Which settings matter (time base, volts/div, coupling, trigger)?

<div style='page-break-after: always;'></div>

## Part 2 — Guided correction

### Step 1 — The DAC command frame

The 16-bit word is **4 configuration bits** followed by **12 data bits**:

| Bit | Name | Value | Meaning |
|----|------|-------|---------|
| 15 | A/B  | 0 | channel A (the only one on the MCP4821) |
| 14 | —    | 0 | don't care |
| 13 | GA   | 1 | gain ×1 → output range 0–2.048 V |
| 12 | SHDN | 1 | output active (not shut down) |
| 11–0 | data | value | the 12-bit sample (0–4095) |

So the config nibble is `0b0011 = 0x3`, and:

```
word = 0x3000 | (value & 0x0FFF);
```

You send it **most-significant byte first**: high byte, then low byte, with **CS low** during the transfer and **CS high** afterwards to latch the output.

[DIAGRAM: "mcp4821-frame" — SPI chronogram with three aligned lines. Line 1 "CS": HIGH, falls LOW just before the first clock, stays LOW for the whole transfer, rises HIGH at the end with an arrow annotation on the rising edge: "output latched here". Line 2 "SCK": 16 clock pulses, grouped visually 8+8 with a light separator labelled "byte 1 (MSB) | byte 2 (LSB)". Line 3 "MOSI": 16 bit-cells labelled in order: 0, 0, 1, 1, D11, D10 … D0 — with the first four cells shaded and annotated "config: A/B=0, x, GA=1, SHDN=1 → 0x3", and the last twelve annotated "12-bit sample". Caption: "One sample = 16 bits, MSB first, CS low during the 16 clocks."]

### Step 2 — The pins

| Signal | dsPIC pin | Role |
|--------|-----------|------|
| SDO1 (MOSI) | **RC0** | data µC → DAC (the DAC's SDI input) |
| SCK1 | **RC2** | SPI clock |
| DAC CS | **RB14** | chip select (driven as GPIO) |
| SPEAKER ENABLE | **RC6** | enables the audio amplifier (GPIO) |
| DAC LDAC | *not connected* | no µC pin — tied low on the board |

**LDAC is not routed to the microcontroller** (it lands on a NC pin, like the OLED reset earlier). It is tied low on the board, which means the DAC output updates on the rising edge of CS. You have nothing to control there.

The naming subtlety: the DAC's input is called **SDI**, but from the microcontroller's side it is an **output** (SDO/MOSI). The µC talks (SDO) → the DAC listens (SDI). Same wire, two names, no contradiction.

### Step 3 — MCC configuration

**SPI1 module:**

- Mode: **Host / Master**
- Communication width: **8 bit**
- Clock: **~2 MHz** (the DAC accepts up to 20 MHz)
- SPI mode **0,0**: clock polarity *Idle Low*, data sampled in the *Middle*

`[CAPTURE: MCC SPI1 configuration window — Host, 8 bit, 2 MHz, Idle Low / sample Middle]`

**Pin assignments (Grid View):**

- `SDO1` → **RC0**
- `SCK1` → **RC2**
- leave `SDI1` and `SS1` unassigned (the DAC sends nothing back, and CS is handled by us as a GPIO)

**GPIO outputs (Pins), with custom names so the macros are readable:**

- `DAC_CS` → **RB14**, output
- `SPKR_EN` → **RC6**, output

`[CAPTURE: MCC Pin Grid View — SDO1 on RC0, SCK1 on RC2, and the two GPIO outputs DAC_CS (RB14) and SPKR_EN (RC6) with their custom names]`

Then **Generate**. Giving custom names produces `DAC_CS_SetLow()` etc.; without them MCC names the macros after the pin (`IO_RB14_SetLow()`).

### Step 4 — Physical setup

In the **COM / remapping** area:

- **SPI MOSI** jumper (RC0 → the bus)
- **SPI SCK** jumper (RC2 → the bus)

In the **IO** areas:

- **DAC CS** jumper (IO 26 → RB14)
- **SPEAKER ENABLE** jumper (IO 12 → RC6)

In the **Speaker Circuit** area:

- the **DAC OUT ↔ SPEAKER IN** jumper (routes the DAC output into the amplifier)
- the speaker **ON/OFF switch** must be on **ON**, and the **GAIN** switch set (LOW or HIGH — HIGH for a comfortable volume)

If any of these is missing, you get *no signal and no sound* — the most common cause of a silent board, and it costs nothing to check.

`[CAPTURE: board photo with all five jumpers and the two speaker switches circled/annotated]`

### Step 5 — The DAC output function

```c
static void DAC_Write(uint16_t value)
{
    uint16_t word = 0x3000u | (value & 0x0FFFu);   // DAC A, gain x1, active
    DAC_CS_SetLow();
    SPI1_Exchange8bit((uint8_t)(word >> 8));        // high byte (config + top 4 data bits)
    SPI1_Exchange8bit((uint8_t)(word & 0xFF));      // low byte (8 data bits)
    DAC_CS_SetHigh();                               // rising edge = output updates
}
```

The output voltage updates on the **rising edge of CS** (because LDAC is tied low on the board).

### Step 6 — Make a tone

```c
int main(void)
{
    SYSTEM_Initialize();
    SPKR_EN_SetHigh();       // enable the amplifier

    while (1)
    {
        DAC_Write(3500);     // high level  (~1.75 V)
        __delay_us(1136);    // half period → ~440 Hz
        DAC_Write(600);      // low level   (~0.30 V)
        __delay_us(1136);
    }
}
```

The output voltage in gain ×1 is `V = (code / 4095) × 2.048 V`, so this swings between ~0.30 V and ~1.75 V — about **1.45 V peak-to-peak** at the DAC output.

### Step 7 — On the oscilloscope

An analog oscilloscope needs a fast, repetitive signal and the right settings: **TIME/DIV ≈ 0.5 ms**, **VOLTS/DIV ≈ 0.5 V**, **COUPLING = DC** (AC coupling removes the DC level and mangles the trace), and turn the **TRIGGER LEVEL** until the image freezes. Make sure the channel's **GND** button is not pressed.

`[CAPTURE: oscilloscope screen showing the frozen ~440 Hz square wave, with the time/div and volts/div settings visible]`

## Troubleshooting — nothing works?

Work through these in order. Each symptom points at the thing to check.

**No sound at all, and no signal on the oscilloscope.** Almost always a **missing jumper** (Step 4) or the **speaker switch on OFF**. Check the four bus jumpers, the DAC OUT ↔ SPEAKER IN jumper, and the ON/OFF switch. Load a slow 1 Hz version (`DAC_Write(4095)` / `DAC_Write(0)` with `__delay_ms(500)`) and listen for a *tick… tick…*: each voltage step clicks in the speaker, which confirms the DAC and speaker path without needing the oscilloscope.

**The oscilloscope shows a still dot or garbage, not a square wave.** Use the 440 Hz code, set **TIME/DIV ≈ 0.5 ms**, **VOLTS/DIV ≈ 0.5 V**, **COUPLING = DC**, and turn **TRIGGER LEVEL** until the image freezes. Make sure the channel's **GND** button is not pressed.

**A signal is visible on the scope, but no sound.** The DAC and SPI are fine — the problem is only the audio path. Check the **SPEAKER ENABLE** jumper, try `SPKR_EN_SetLow()` instead of `SetHigh()` (the enable polarity), the **ON/OFF switch**, and the **DAC OUT ↔ SPEAKER IN** jumper.

**The output is flat at 0 V (DAC not responding).** The DAC is not receiving valid SPI. Check the **SPI mode**: the MCP4821 needs mode 0,0. If MCC left it on another mode, flip the **Clock Edge** setting, regenerate, and retest. Also confirm `SPI1_Initialize()` is called in `system.c`.

## What you learned

- SPI is a **synchronous** link: data (MOSI) is clocked by SCK, framed by a chip select the master drives itself.
- The MCP4821 takes **16-bit words, MSB first**: 4 config bits + 12 data bits; the output latches on the rising edge of CS.
- On this board, **jumpers are part of the design**: no jumper, no signal — check them before the code.
- If the sound is very faint, set the speaker **GAIN switch to HIGH**.

## Next

**Real waveforms** — replace the crude delay-based square wave with a Timer-driven wave table: square, triangle and sine at any frequency.
