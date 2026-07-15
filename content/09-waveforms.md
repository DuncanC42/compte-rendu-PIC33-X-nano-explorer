# Sound Generation — Stage 2: Real Waveforms with a Timer

The first sound lab made a tone by alternating two levels with `__delay_us`. That works, but the timing is approximate and the CPU can do nothing else. To generate **clean, tunable waveforms**, the samples must be produced at a **fixed, precise rate** — the job of a **Timer interrupt**.

In this lab you feed the DAC from a **wave table** at a constant sample rate, and you get square, triangle and sine waves whose frequency you can set exactly.

## Goals

In this lab you will:

- Drive the DAC at a **fixed sample rate** using a Timer interrupt
- Understand the **phase accumulator** — how a fixed sample rate produces any frequency
- Store and play different **wave tables** (square, triangle, sine)

## Physical setup

Same as the previous sound lab — nothing changes.

## Part 1 — Your mission

### Step 1 — Why a Timer instead of `__delay`?

**Task.** With the `__delay_us` loop, what two problems appear when you want a precise frequency *and* want the program to do other things (read a potentiometer, update the screen)? What sample rate should you target, and why?

### Step 2 — Configure the Timer in MCC

**Task.** Add a Timer that fires at your sample rate (e.g. 20 kHz) and enable its interrupt. What do you configure, and how do you register the callback? (You did this once in the Timer lab.)

### Step 3 — The phase accumulator

**Task.** You have a fixed sample rate `Fs` and a wave table of `N` samples. You want to play a note of frequency `f`. How do you decide, on each timer tick, which table entry to output? (Hint: think about how far through one cycle you advance per sample. A 32-bit integer that overflows naturally is your friend.)

### Step 4 — Build the wave tables

**Task.** Create a 256-entry, 12-bit wave table (values 0–4095, centred on 2048) for a **square**, a **triangle**, and a **sine**. How do you fill each, and *where* in the program do you compute them — and where must you absolutely not?

### Step 5 — Output samples in the interrupt

**Task.** In the timer callback, advance the phase and send the current table sample to the DAC. Write the callback and the pieces it needs (`SetFrequency`, the shared variables). What qualifier do the shared variables need, and how short must the callback stay?

### Step 6 — Choose the waveform, hear the difference

**Task.** Switch between square, triangle and sine at run time and listen. Same frequency, different sound — what is the property that changes called, and how do you switch tables in the code?

## Part 2 — Guided correction

### Step 1 — Why a Timer?

Two problems with the delay loop: the timing is **approximate** (any code you add between writes changes the period, so the pitch drifts), and the CPU is **stuck** in the delay loop, unable to do anything else.

The fix is a **fixed sample rate**: output one sample every tick of a Timer interrupt. A rate of **~20 kHz** (one sample every 50 µs) is a good target — well above the audio band, so it reproduces tones cleanly. The main loop is then free for other work.

### Step 2 — Timer configuration

- Add a **Timer** (e.g. **TMR1**) in MCC.
- Set its **period to the sample rate**: 20 kHz → a period of **50 µs**.
- **Enable the timer interrupt**, so a callback runs on every period.
- Generate. MCC produces an init and a way to register a callback — the exact name depends on the version (often `TMR1_TimeoutCallbackRegister(...)` or `TMR1_SetInterruptHandler(...)`). Check the generated `tmr1.h` for the precise function.

`[CAPTURE: MCC Timer configuration window — Requested Period 50 µs, interrupt enabled]`

### Step 3 — The phase accumulator

Per sample you advance by a **fraction `f / Fs` of a full cycle**. The clean way to track this is a **phase accumulator**: a 32-bit counter where the whole 0…2³² range represents one full cycle.

- **Phase increment** per sample: `phaseInc = f × 2³² / Fs`
- On each tick: `phase += phaseInc;`
- The top bits of `phase` index the table. For an `N = 256` table, the index is `phase >> 24` (top 8 bits).

The accumulator wraps around naturally at the end of a cycle, and changing `f` just changes `phaseInc` — so you retune instantly without touching the table.

[DIAGRAM: "phase-accumulator" — Two parts. LEFT: a circle (dial) representing one full cycle, graduated 0 at the top and "2³²" just before it; an arrow from the centre pointing at the current phase, and 4–5 dots on the circumference spaced by an angle labelled "phaseInc = f·2³²/Fs" showing successive ticks hopping around the dial; annotate "wraps around naturally = new cycle". RIGHT: a 32-bit register drawn as a long box; its top 8 bits shaded and extracted by an arrow "phase >> 24" pointing into a small vertical table "wave table [256]", whose selected entry flows out via an arrow "12-bit sample" into a box "DAC_Write()". Caption: "One addition per tick: the top 8 bits pick the table entry, the wrap-around ends the cycle."]

### Step 4 — The wave tables

```c
#include <math.h>
#define TABLE_SIZE 256

uint16_t sine[TABLE_SIZE];
uint16_t triangle[TABLE_SIZE];
uint16_t square[TABLE_SIZE];

static void BuildTables(void)
{
    for (int i = 0; i < TABLE_SIZE; i++)
    {
        // sine: centred on 2048, amplitude 2047
        sine[i] = (uint16_t)(2048 + 2047.0 * sin(2.0 * M_PI * i / TABLE_SIZE));

        // triangle: up then down
        triangle[i] = (i < TABLE_SIZE/2)
                        ? (uint16_t)(i * 4095 / (TABLE_SIZE/2))
                        : (uint16_t)((TABLE_SIZE - i) * 4095 / (TABLE_SIZE/2));

        // square: first half high, second half low
        square[i] = (i < TABLE_SIZE/2) ? 4000 : 100;
    }
}
```

The tables are computed **once, at startup, in `main`** — never in the interrupt. The sine uses `sin()` once at boot, so the floating-point cost is paid outside the 20 kHz callback.

[DIAGRAM: "wave-tables" — Three small side-by-side plots, each 256 samples on X (0→255) and 0→4095 on Y with a dashed midline at 2048: (1) "square" — high plateau at 4000 for the first half, low plateau at 100 for the second; (2) "triangle" — rises linearly 0→4095 over the first half, falls back over the second; (3) "sine" — one full smooth period centred on 2048. Caption: "Three tables, same size, same amplitude range — only the shape differs."]

### Step 5 — The interrupt

```c
#define FS  20000UL            // sample rate (Hz), matches the timer

volatile uint32_t phase = 0;
volatile uint32_t phaseInc = 0;
volatile uint16_t *waveform = square;   // current table

static void SetFrequency(uint32_t f)
{
    phaseInc = (uint32_t)(((uint64_t)f << 32) / FS);
}

// called on every timer tick (register this with MCC's timer callback)
void SampleTick(void)
{
    phase += phaseInc;
    DAC_Write(waveform[phase >> 24]);   // top 8 bits -> 0..255
}

int main(void)
{
    SYSTEM_Initialize();
    SPKR_EN_SetHigh();
    BuildTables();
    SetFrequency(440);                  // A4
    TMR1_TimeoutCallbackRegister(SampleTick);  // name may differ — check tmr1.h

    while (1)
    {
        // free for other work: read a pot, update the OLED, change waveform...
    }
}
```

The variables shared between `main` and the interrupt are **`volatile`**, so the compiler always re-reads them. Keep the callback short — it runs 20 000 times per second, so it must only advance the phase and write one sample.

### Step 6 — Waveform and timbre

Point `waveform` at a different table:

```c
waveform = sine;       // smooth, mellow
waveform = triangle;   // softer than square, richer than sine
waveform = square;     // harsh, buzzy (lots of harmonics)
```

Same pitch, different **timbre**: the square wave is bright and buzzy (many harmonics), the sine is pure and mellow, the triangle sits in between.

`[CAPTURE: three oscilloscope screens side by side — the square, triangle and sine at the same frequency — the visual counterpart of the timbre difference]`

## Troubleshooting — not sounding right?

**Sound is very faint.** Check the **GAIN switch** in the Speaker Circuit (LOW/HIGH) — set it to HIGH. Also make sure your table uses a wide amplitude (near 0–4095), and consider the DAC gain bit ×2 for a larger output swing.

**Pitch is wrong or drifts.** The **timer period must exactly match `FS`** in your code — if the timer runs at a different rate than the `FS` you use in `SetFrequency`, every note is off. Recompute the timer period and confirm it against `FS`.

**Sound is distorted / crackly.** The interrupt may be **too slow or overloaded**. Make sure the callback only advances the phase and writes one sample — no `sin()`, no `sprintf`, no long work inside it. Building the tables must happen once in `main`, not in the interrupt.

## What you learned

- A fixed **sample rate from a Timer interrupt** gives exact, drift-free frequencies and leaves the CPU free.
- The **phase accumulator** turns one addition per tick into any output frequency, with natural wrap-around.
- Wave tables are computed **once at startup**; the interrupt only indexes them.
- Same pitch, different table = different **timbre**.

## Next

With clean, tunable tones you can now add **control and display**:

- **A potentiometer** (reuse the ADC brick) mapped to **frequency** — turn the knob, change the pitch — or to **volume** by scaling the samples.
- **The OLED** showing the current waveform shape, frequency, or note name.
- Later: a **joystick** for two-axis control, or the **microphone** as an input, and eventually the **WS2812B ring** reacting to the sound for the integrated final project.
