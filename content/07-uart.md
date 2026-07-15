# Serial Output Project (UART) — Streaming Values to the PC

In this lab you will send the live proximity value to a PC over the serial port, so you can read it in a terminal or plot it in real time with the MPLAB Data Visualizer.

This completes the sensor chain started in the previous lab: the proximity value now goes to the OLED **and** to the PC. The serial link also gives you something valuable for every project that follows: a **debug console**, a way to print values from the microcontroller straight to your computer.

## Goals

In this lab you will:

- Configure a **UART** and understand that it reaches the PC through the on-board debugger's **virtual COM port** (CDC)
- Get the **TX/RX crossover** right — the most common UART mistake
- Send the proximity value to the PC, one reading per line

The tools involved are the **VCNL4200 sensor**, the **OLED**, and the **on-board debugger** (which bridges the UART to USB).

## Physical setup

There is **nothing to wire**. On the Curiosity Nano, one UART of the dsPIC is hard-wired to the on-board debugger, which forwards it to the PC as a virtual COM port over the **same USB cable** you already use to program the board. The two pins involved (RC10, RC11) are fixed by the board design, not something you jumper.

## Background — how the serial link works

UART is a two-wire asynchronous link: one line to transmit (**TX**), one to receive (**RX**). The key rule is that the two devices are **crossed**: one device's TX must reach the other device's RX.

Each byte travels framed as **8N1**: the line idles HIGH, drops LOW for one *start bit*, then carries the 8 data bits (LSB first), then returns HIGH for one *stop bit*. At 115200 baud, each bit lasts about 8.7 µs. Both sides must agree on this rate in advance — there is no clock line.

[DIAGRAM: "uart-8n1-frame" — Chronogram of one UART byte on a single line. From left to right: a flat HIGH segment labelled "idle", a one-bit LOW segment labelled "START", eight bit-cells labelled "D0 (LSB)" to "D7 (MSB)" with example values drawn as highs/lows (e.g. the byte 0x35), a one-bit HIGH segment labelled "STOP", then flat HIGH "idle" again. Under the frame, a horizontal brace over one bit-cell annotated "1 bit = 1/115200 s ≈ 8.7 µs". Caption: "8N1: start bit + 8 data bits (LSB first) + stop bit, no clock line."]

## Part 1 — Your mission

### Step 1 — Add and configure the UART

**Task.** In MCC Melody, add **UART1** at **115200 baud, 8N1**, and assign its pins.

1. The board mapping labels the debugger lines **CDC RX** (pin RC10) and **CDC TX** (pin RC11) — named from the **PC's point of view**. Deduce which dsPIC signal (`U1TX` or `U1RX`) goes on which pin. Be careful: getting this backwards is the classic UART mistake, and nothing will tell you — it compiles and runs, but the PC receives nothing.
2. Generate, then list the functions in `uart1.h` you will need to send bytes.

### Step 2 — `printf` or not `printf`?

**Task.** MCC offers an option called **"Redirect STDIO to UART"**.

1. What does `printf()` do if this option is **not** enabled? Why is that failure mode particularly treacherous?
2. Without STDIO redirection, write a small `UART_Print(const char *s)` helper that sends a string byte by byte, without ever losing a byte when the transmit buffer is full.

### Step 3 — Putting it together

**Task.** Extend the proximity project: each loop iteration displays the value on the OLED **and** sends it to the PC, one value per line.

1. What must terminate each transmitted line for terminals and the Data Visualizer to separate the values correctly?

### Step 4 — Read it on the PC

**Task.** On your Linux machine:

1. Find which device file the virtual COM port appears as.
2. Open it at 115200 baud with the tool of your choice and watch the values react to your hand.
3. If you get *permission denied*, what is the standard fix?
4. Open the same port in the **MPLAB Data Visualizer** and plot the value as a live curve.

## Part 2 — Guided correction

### Step 1 — Add and configure the UART

Open MCC Melody and add the **UART1** module:

- **Baud rate**: `115200`
- **Data format**: `8N1` (8 data bits, no parity, 1 stop bit) — the defaults

The crossover reasoning: **CDC RX** is what the *PC receives* → it must be fed by the **dsPIC's TX** (`U1TX`). **CDC TX** is what the *PC sends* → it must arrive on the **dsPIC's RX** (`U1RX`). So in the **Pin Manager (Grid View)**:

- `U1TX` → **RC10** (CDC RX)
- `U1RX` → **RC11** (CDC TX)

Then **Generate**.

![](../assets/images/05_UART/01_uart_pins.png)
*Figure — UART1 outputs assigned in the Pin Grid View: U1TX on RC10, U1RX on RC11.*

![DIAGRAM: "uart-crossover" — Three boxes left to right. Box 1: "dsPIC33CK" with two labelled pins on its right edge: "U1TX (RC10)" and "U1RX (RC11)". Box 2: "On-board debugger" with two labelled pins on its left edge: "CDC RX" and "CDC TX", and on its right edge a single "USB" port. Box 3: "PC" with "/dev/ttyACM0, 115200 8N1". Draw the two UART wires CROSSING between box 1 and box 2: U1TX → CDC RX and CDC TX → U1RX, with the crossing point highlighted and annotated "labels are from the PC's point of view!". A single thick line "same USB cable as programming" between debugger and PC. Caption: "TX talks to RX: the crossover happens between the dsPIC and the debugger."](../assets/images/uart-crossover.png)

This generates `uart1.h` / `uart1.c`, exposing among others:

- `UART1_Write(uint8_t data)` — send one byte
- `UART1_IsTxReady()` — true when the transmit buffer can accept a byte
- `UART1_Read()` / `UART1_IsRxReady()` — for the receive side (not used here)

### Step 2 — `printf` vs `UART1_Write`

If **"Redirect STDIO to UART"** is not enabled — which is the default — `printf` compiles but sends its output **nowhere**, and the screen on the PC stays empty. That silent failure is treacherous because it looks exactly like a wiring problem: no error, no warning, no output.

Since STDIO redirection is not enabled here, we send bytes explicitly with `UART1_Write`, wrapped in a helper that waits for the transmitter to be free before each byte:

```c
// Send a string over the UART, byte by byte
static void UART_Print(const char *s)
{
    while (*s)
    {
        while (!UART1_IsTxReady()) { }   // wait until the TX buffer is free
        UART1_Write(*s++);
    }
}
```

### Step 3 — Putting it together

We reuse the proximity read and OLED display from the previous lab, and add one serial print per loop. The **`\r\n`** (carriage return + newline) at the end puts each value on its own line — required for the Data Visualizer to plot them and for terminals to display them cleanly.

```c
#include "mcc_generated_files/system/system.h"
#include "mcc_generated_files/system/pins.h"
#include "mcc_generated_files/i2c_host/i2c1.h"
#include "mcc_generated_files/uart/uart1.h"
#include "ssd1306.h"
#include <stdio.h>
#define FCY 100000000UL
#include <libpic30.h>

#define VCNL4200_ADDR     0x51
#define VCNL4200_PS_DATA  0x08
#define VCNL4200_PS_CONF  0x03

static void VCNL4200_Init(void)
{
    uint8_t cfg[3] = { VCNL4200_PS_CONF, 0x08, 0x00 };
    while (I2C1_IsBusy()) { }
    I2C1_Write(VCNL4200_ADDR, cfg, sizeof(cfg));
    while (I2C1_IsBusy()) { }
}

static uint16_t VCNL4200_ReadReg(uint8_t reg)
{
    uint8_t rx[2] = {0, 0};
    while (I2C1_IsBusy()) { }
    I2C1_WriteRead(VCNL4200_ADDR, &reg, 1, rx, 2);
    while (I2C1_IsBusy()) { }
    return (uint16_t)(rx[0] | (rx[1] << 8));
}

static void UART_Print(const char *s)
{
    while (*s)
    {
        while (!UART1_IsTxReady()) { }
        UART1_Write(*s++);
    }
}

uint16_t prox;
char buffer[16];

int main(void)
{
    SYSTEM_Initialize();
    SSD1306_Init();
    SSD1306_Clear();
    VCNL4200_Init();

    while (1)
    {
        prox = VCNL4200_ReadReg(VCNL4200_PS_DATA);

        sprintf(buffer, "PROX:%5u   ", prox);
        SSD1306_SelectPage(0);
        SSD1306_WriteString(buffer);

        sprintf(buffer, "%u\r\n", prox);   // one value per line
        UART_Print(buffer);

        __delay_ms(100);
    }
}
```

### Step 4 — Reading it on the PC

Build and program the board, then open the virtual COM port at **115200 baud**.

On **Linux**, find the port and read it:

```bash
ls /dev/ttyACM*            # usually /dev/ttyACM0
screen /dev/ttyACM0 115200 # quit with Ctrl+A then K then y
```

If `screen` is not installed, `minicom -D /dev/ttyACM0 -b 115200` works too, or simply `stty -F /dev/ttyACM0 115200 && cat /dev/ttyACM0` just to watch the stream. If you get a *permission denied*, add yourself to the `dialout` group (`sudo usermod -aG dialout $USER`, then log out and back in).

You should see the proximity values scroll by, rising when you move your hand toward the sensor. In the **MPLAB Data Visualizer**, select the same COM port and baud rate to plot the values as a live curve — the software oscilloscope you were missing.

`[CAPTURE: terminal showing the proximity values streaming and reacting to a hand]`
`[CAPTURE: MPLAB Data Visualizer plotting the same stream as a live curve]`

## What you learned

- A UART is **crossed**: the microcontroller's TX goes to the receiver's RX. On this board, labels are named from the PC's side (CDC RX = the dsPIC's TX).
- The Curiosity Nano bridges the UART to a **virtual COM port** over the debugger's USB — no extra cable or adapter.
- Ending each message with `\r\n` is what makes terminals and the Data Visualizer treat values as separate lines.
- Without **"Redirect STDIO to UART"**, `printf` sends nothing — send bytes with `UART1_Write` instead.

## Next

**SPI** — a faster, synchronous link, used on this board to reach the DAC (MCP4821) that drives the speaker, and later the addressable RGB ring.

> *Deferred refinement:* driving the on-board colour LED from the proximity value (three PWM channels) is left as a later addition — the LED is wired to pins the high-resolution PWM module cannot reach directly, so it needs either a different PWM peripheral routing or a software (bit-banged) PWM.
