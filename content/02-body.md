<div style='page-break-after: always;'></div>

# Document body

## How to create a project on MPLAB

## GPIO Project

In this section you will implement everything to setup a GPIO communication with input and output tools.

### Goals

In this project you will:

- Make a LED blink

- Turn the LED on while you hold a switch

- Use the switch to turn the LED on and off

The tools involved are LED1 and SW2.

### Physical setup

![](../assets/images/Curiosity-mapper.png)
*Figure 1 — Pin mapping of the dsPIC33CK64MC105 on the Curiosity Nano Explorer board. The left side shows the microcontroller's physical pins; the right side shows how they are exposed on the Explorer board connectors. To follow this tutorial, place a jumper linking the **LED1** pin to **IO11**, and another linking **SW2** to **IO20**.*

Once the jumpers are in place, you can move on to the software setup.

### Setting up on MPLAB

#### 1. Make a LED blink

First, we want to control LED1, which you can find on the board here:

![](../assets/images/01_GPIO/00_led_location.png)

To drive this LED you need to configure pin **RC5** as a digital output. Open the MCC Melody interface by clicking the blue MCC icon, then apply the following configuration:

![](../assets/images/01_GPIO/01_led_configuration.png)

You can either click on the pin directly in the chip view (top-left corner) and select `GPIO_OUTPUT`, or use the pin table at the bottom of the screen and enable output on RC5. Either way, rename the pin to `LED1` to keep your code readable — select *Project Resources* on the left, then click **Generate**.

This modifies two files — `pins.h` and `pins.c` — by declaring and implementing a set of macros you will use in `main.c`.

Each macro maps the human-readable name `LED1` to one of three hardware registers that control pin RC5:

- `_LATC5` (**LAT**ch register) — the value the PIC *drives* on the output pin (0 or 1).

- `_TRISC5` (**TRIS**tate register) — pin direction: `0` = output, `1` = input.

- `_RC5` (**PORT** register) — the *actual* logic level present on the pin.


The generated macros in `pins.h` wrap these registers:

```c
// pins.h — macros for LED1 (mapped to pin RC5)

// drive pin HIGH
#define LED1_SetHigh()          (_LATC5 = 1)   

// drive pin LOW
#define LED1_SetLow()           (_LATC5 = 0)   

// invert current output level
#define LED1_Toggle()           (_LATC5 ^= 1)  

// read actual pin level
#define LED1_GetValue()         _RC5            

// set pin as input
#define LED1_SetDigitalInput()  (_TRISC5 = 1)  

// set pin as output
#define LED1_SetDigitalOutput() (_TRISC5 = 0)  

// applies the full pin configuration from MCC
void PINS_Initialize(void);  
```

Back in `main.c`, making the LED blink is straightforward:

```c
#include "mcc_generated_files/system/system.h"
#include "mcc_generated_files/system/pins.h"

// Fosc / 2 — required by libpic30 delay macros
#define FCY 100000000UL 
#include <libpic30.h>

int main(void)
{
    SYSTEM_Initialize();
    while(1)
    {
        // wait half a second
        __delay_ms(500); 

        // turn LED on  (active low)
        LED1_SetLow();   
        __delay_ms(500);

        // turn LED off
        LED1_SetHigh();  
    }
}
```

Now that you understand what each macro does, you can simplify this with `Toggle`:

```c
int main(void)
{
    SYSTEM_Initialize();
    while(1)
    {
        __delay_ms(500);
        LED1_Toggle();
    }
}
```

The LED should now blink every half second.

---

#### 2. Hold a switch to turn the LED on

Go back to the MCC Melody pin manager and add **RD1** as a digital input — this is where SW2 is connected (refer to the mapping diagram if needed). Name it `SW2`, tick *Weak Pullup*, then click **Generate**.

![](../assets/images/01_GPIO/02_switch_configuration.png)

The weak pull-up keeps the pin at a logic HIGH when the button is not pressed. When you press the button, it connects the pin to ground, pulling it LOW. This is why the condition below checks for `== 0`.

```c
int main(void)
{
    SYSTEM_Initialize();
    while(1)
    {
        // button pressed → pin pulled LOW
        if(SW2_GetValue() == 0) { 
            // turn LED on
            LED1_SetLow();        
        }
        else {
            // turn LED off
            LED1_SetHigh();       
        }
    }
}
```

---

#### 3. Toggle the LED with a switch press

You now have all the building blocks. The idea is to combine the delay from step 1 with the button read from step 2: every loop iteration, wait a short time, then check the button and toggle if it is pressed.

```c
int main(void)
{
    SYSTEM_Initialize();
    while(1)
    {
        if(SW2_GetValue() == 0) {
            LED1_Toggle();
        }
    }
}
```

This works — but not reliably. The issue is a **timing mismatch** between the loop and the human finger.

The loop runs every 50 ms. A typical button press lasts 200–400 ms. During that window, the loop executes the `Toggle` call **4 to 8 times**, so the LED flickers unpredictably instead of cleanly switching state.

The diagram below illustrates this: a single press lasting ~240 ms is seen as four separate LOW readings by the loop, producing four unwanted toggles.

![](../assets/images/01_GPIO/chronogramme_sans_delai.svg)

This is called a **debouncing problem**. It can be solved properly using:

* a **hardware timer** to sample the button at a fixed rate and require a stable state before acting, or

* **interrupts**, which let the MCU react the instant the pin changes rather than polling it in a loop.

Both approaches are covered in the next sections.

<div style='page-break-after: always;'></div>

# Timer Project

In this section you will use a hardware timer to generate precise, **non-blocking** timing. You will then use that same timer to fix the button-**debouncing** problem left open at the end of the GPIO project.

## Goals

In this project you will:

- Blink LED1 **without blocking** the CPU (no more `__delay_ms`)
- Configure a timer to raise an **interrupt** at a fixed rate, and run your code from a **callback**
- Use that fixed-rate sampling to **debounce** SW2 and toggle the LED cleanly — exactly one toggle per press

The tools involved are **LED1** and **SW2**, same as the GPIO project.

## Physical setup

No new wiring. Keep the same jumpers as in the GPIO project: **LED1 → IO11** and **SW2 → IO20**.

`[CAPTURE: board with the LED1 and SW2 jumpers in place]`

## Why a timer?

In the GPIO project you used `__delay_ms(500)`. That macro is a **busy wait**: the CPU spins in a loop doing nothing useful for the whole half-second, so it cannot react to anything else during that time.

A hardware timer is a counter that runs **in parallel** with your program. It increments on its own from the system clock and, when it reaches a value you choose (its *period*), it raises a flag — and optionally triggers an **interrupt**. The CPU stays free; it only stops briefly to run a short *callback* when the timer fires, then carries on.

On this board the instruction clock is `FCY = 100 MHz` (`FOSC / 2`). The timer counts at a rate derived from `FCY`, and MCC computes the right reload value for the period you ask for — you do not have to do the register math by hand.

## Setting up on MPLAB

### 1. Add and configure the timer

Open the MCC Melody interface (blue MCC icon). In **Device Resources**, add a **Timer (TMR1)**. In its configuration panel set:

- **Clock source**: `FOSC/2` (i.e. `FCY`)
- **Requested Period**: `500 ms` (to reproduce the GPIO blink) — you will lower this later for debouncing
- Tick **Enable Timer Interrupt**

Then select **Project Resources** on the left and click **Generate**.

`[CAPTURE: MCC Melody TMR1 configuration window]`

This generates `tmr1.h` and `tmr1.c`, which expose (among others):

- `TMR1_Initialize()` — applies the configuration (already called by `SYSTEM_Initialize()`)
- `TMR1_Start()` / `TMR1_Stop()` — run / halt the timer
- a **callback registration** function, typically `TMR1_TimeoutCallbackRegister(void (*handler)(void))`

> Check the exact name of the callback function in your generated `tmr1.h` — depending on the driver version it may differ slightly (e.g. `TMR1_TimeoutCallbackRegister` vs `TMR1_OverflowCallbackRegister`). Use the one that is actually declared.

### 2. Non-blocking blink

The idea: register a callback that toggles LED1, and let the timer call it on its own every period. The `while(1)` loop is now free.

```c
#include "mcc_generated_files/system/system.h"
#include "mcc_generated_files/system/pins.h"

// Called automatically every timer period (here: 500 ms), from the timer interrupt
static void Timer1_Tick(void)
{
    LED1_Toggle();
}

int main(void)
{
    SYSTEM_Initialize();

    TMR1_TimeoutCallbackRegister(&Timer1_Tick);   // check the exact name in tmr1.h
    TMR1_Start();

    while (1)
    {
        // The CPU is free here for other tasks — no blocking delay.
    }
}
```

The LED now blinks every 500 ms, but the main loop is completely available. Compare this with the GPIO version where `__delay_ms` froze everything: that difference is the whole point of using a timer.

`[CAPTURE: LED1 blinking]`

### 3. Debouncing SW2 with the timer

Recall the problem from the GPIO project: a single ~240 ms press was read thousands of times by the fast loop, producing several unwanted toggles. The fix is to **sample the button at a fixed, slow rate** and only act when the level has been **stable** for several samples — and only on the **transition** from released to pressed.

Change the timer **Requested Period** to **5 ms** and regenerate, then use a small state machine in the callback:

```c
#include "mcc_generated_files/system/system.h"
#include "mcc_generated_files/system/pins.h"
#include <stdbool.h>
#include <stdint.h>

#define STABLE_SAMPLES  4      // 4 x 5 ms = 20 ms of a stable level required

// Called every 5 ms
static void Timer1_Tick(void)
{
    static uint8_t counter     = 0;
    static bool    stableState = true;          // true = released (weak pull-up keeps it HIGH)

    bool reading = (SW2_GetValue() != 0);       // true = released, false = pressed (active low)

    if (reading != stableState)
    {
        counter++;
        if (counter >= STABLE_SAMPLES)          // the new level has held long enough
        {
            stableState = reading;
            counter      = 0;

            if (stableState == false)           // newly, stably PRESSED -> act once
            {
                LED1_Toggle();
            }
        }
    }
    else
    {
        counter = 0;                            // bounce/noise: reset the stability counter
    }
}

int main(void)
{
    SYSTEM_Initialize();

    TMR1_TimeoutCallbackRegister(&Timer1_Tick);
    TMR1_Start();

    while (1)
    {
        // free
    }
}
```

Now one physical press = exactly **one** toggle, no matter how the contact bounces or how long you hold the button. Try holding it down: the LED no longer flickers.

`[CAPTURE: clean single toggle per press]`

## What you learned

- A hardware timer gives **deterministic, parallel** timing without blocking the CPU.
- **Interrupts + callbacks** let the MCU react on a fixed schedule instead of polling in a tight loop.
- **Fixed-rate sampling with a stability count** is the standard, reliable way to debounce a mechanical input.

## Next
**PWM** — generating an analog-like level (LED brightness, servo angle) from a digital pin, using the dsPIC's PWM/SCCP modules.


## ADC Project

*Explaining what ADC is and how it's useful*

<div style='page-break-after: always;'></div>

## ADC Project

In this section you will read the on-board rotary potentiometer with the dsPIC's analog-to-digital converter (ADC), and display the live value on the SSD1306 OLED screen over I2C.

### Goals

In this project you will:

- Configure the ADC to read an analog voltage from the **potentiometer**
- Convert that reading into a digital value (0–4095)
- Drive the **OLED display** over I2C and show the value, updated in real time

The tools involved are the **POT-METER** (rotary potentiometer), the **OLED display** (SSD1306), and **LED1** as a simple heartbeat.

### Physical setup

![](../assets/images/Curiosity-mapper.png)
*Figure — Pin mapping of the dsPIC33CK64MC105 on the Curiosity Nano Explorer board. The potentiometer's wiper is exposed as **POT-METER** and maps to the **ADC7** position, which is physical pin **RA0 / AN0**. Place a jumper linking **POT-METER** to **ADC7**.*

The OLED is permanently wired to the board's I2C bus, but that bus only reaches the microcontroller through the two **I2C SDA** and **I2C SCL** jumpers in the COM remapping area. Make sure **both** are in place — if either is missing, the screen (and every other I2C device on the board) will never answer.

`[CAPTURE: close-up of the board showing (1) the POT-METER -> ADC7 jumper and (2) the two I2C SDA / I2C SCL jumpers in the COM remapping area, all in place]`

### What is an ADC?

The microcontroller is digital: it only understands 0s and 1s. The potentiometer, on the other hand, outputs a **continuous voltage** between 0 V and 3.3 V depending on its position. An **Analog-to-Digital Converter** bridges the two worlds: it samples that voltage and returns a number proportional to it.

This dsPIC's ADC is **12-bit**, so it splits the 0–3.3 V range into `2^12 = 4096` steps. A reading of `0` means ~0 V (potentiometer fully one way), `4095` means ~3.3 V (fully the other way), and `2048` is roughly the middle. Each step therefore represents about `3.3 V / 4096 ≈ 0.8 mV`.

### Setting up on MPLAB

#### 1. Configure the ADC pin and module

Open the MCC Melody interface (blue MCC icon).

First, in the **pin table**, set **RA0** as an **analog input** and tick its *analog* box, then rename it `POT`.

Next, in **Device Resources**, add the **ADC** module. In its configuration, find the channel table, enable the **AN0** channel, give it the custom name `POT`, and — this step is easy to miss — set its **Trigger Source** to **Common Software Trigger**. Without a trigger source, the software trigger fires but no channel is subscribed to it, so no conversion ever happens.

![](../assets/images/03_ADC/01_adc_configuration.png)
*Figure — ADC channel table: AN0 enabled, named POT, Trigger Source set to Common Software Trigger.*

Select **Project Resources** on the left and click **Generate**. This produces `adc1.h` / `adc1.c`, which expose (among others):

- `ADC1_Enable()` — powers up the ADC core
- `ADC1_SoftwareTriggerEnable()` — starts a conversion on the common software trigger
- `ADC1_ConversionResultGet(POT)` — returns the latest 12-bit result for the POT channel

#### 2. Read the potentiometer

A minimal read loop: trigger a conversion, give it a brief moment to complete, then read the result.

```c
#include "mcc_generated_files/system/system.h"
#include "mcc_generated_files/system/pins.h"
#include "mcc_generated_files/adc/adc1.h"

#define FCY 100000000UL
#include <libpic30.h>

uint16_t adcValue;

int main(void)
{
    SYSTEM_Initialize();
    ADC1_Enable();

    while (1)
    {
        ADC1_SoftwareTriggerEnable();      // start a conversion
        __delay_us(50);                    // let it finish
        adcValue = ADC1_ConversionResultGet(POT);   // 0 .. 4095
    }
}
```

> A cleaner alternative is to poll a "conversion complete" status instead of using a fixed delay (e.g. `while (!ADC1_IsConversionComplete(POT)) { }`). Check the exact function name and behaviour in your generated `adc1.h` before relying on it. The fixed `__delay_us` above is simpler and perfectly fine at this stage.

At this point `adcValue` holds a live reading, but you have no way to *see* it. That is what the OLED is for.

#### 3. Add the OLED display

The OLED uses the SSD1306 controller over I2C. Rather than write a driver from scratch, we reuse Microchip's example driver (`ssd1306.c`, `ssd1306.h`, `font.h`) and port it onto the dsPIC. **Copy the three files into the project folder** (next to `main.c`) and add them via *Add Existing Item…* — do not leave them outside the project, or the include paths break.

A few points matter when porting this driver:

- **One definition rule.** `font.h` ships with the `ASCII` and `MCHP` arrays *defined* in the header. A header is included by several `.c` files, so this causes a *multiple definition* link error. Move the array **definitions** into `ssd1306.c`, and leave only `extern` **declarations** in `font.h`:
  ```c
  extern const unsigned char ASCII[][5];
  extern const unsigned char MCHP[1024];
  ```

- **I2C address.** On this board the OLED answers at **`0x3D`** (the alternative `0x3C` only applies if pin A0 is tied to GND, which it is not here). Set:
  ```c
  #define SSD1306_I2C_ADDRESS 0x3D
  ```

- **Delays.** The driver uses `__delay_ms` / `__delay_us`, which require `FCY` to be defined **before** `#include <libpic30.h>`. Add `#define FCY 100000000UL` at the top.

- **Reset line.** The SSD1306 RESET pin is handled automatically by an on-board RC network, so there is **no** microcontroller pin to drive — you can ignore reset entirely in software.

Add the **I2C (I2C1, Host)** module in MCC, set it to **100 kHz**, generate, and make sure `ssd1306.c` includes the generated driver header:
```c
#include "mcc_generated_files/i2c_host/i2c1.h"
```

`[CAPTURE: MCC I2C1 configuration window — Host mode, 100 kHz, on RC8/RC9]`

#### 4. The non-blocking I2C trap

This is the subtle part, and the one most likely to leave you with a **blank screen even though everything compiles**.

The MCC `I2C1_Write()` function is **non-blocking and interrupt-driven**: it *starts* a transfer and returns immediately. Its `true`/`false` return only means "request accepted", not "transfer finished". The original driver simply waits a fixed `__delay_us(100)` after each write — but a 2-byte transfer at 100 kHz takes about **280 µs**, far more than 100 µs. So the next command is fired while the previous one is still on the bus, `I2C1_Write()` sees the bus busy, returns `false`, and **the byte is silently dropped**. Across the ~25 commands of `SSD1306_Init()`, almost all are lost, the display is never initialised, and it stays black — without ever blocking.

The fix is to wait for the **real** end of each transfer using `I2C1_IsBusy()` instead of a blind delay. In `ssd1306.c`:

```c
// Send an I2C command byte
void SSD1306_SendCommand(uint8_t command) {
    uint8_t cmd[] = {SSD1306_COMMAND, command};
    while (I2C1_IsBusy()) { }                        // bus free?
    I2C1_Write(SSD1306_I2C_ADDRESS, cmd, sizeof(cmd));
    while (I2C1_IsBusy()) { }                        // wait for completion
}

// Send an I2C data byte
void SSD1306_SendData(uint8_t data) {
    uint8_t d[] = {SSD1306_DATA_CONTINUE, data};
    while (I2C1_IsBusy()) { }
    I2C1_Write(SSD1306_I2C_ADDRESS, d, sizeof(d));
    while (I2C1_IsBusy()) { }
}
```

`I2C1_IsBusy()` waits exactly as long as the transfer needs — no more, no less — so no byte is ever dropped.

#### 5. Putting it together

```c
#include "mcc_generated_files/system/system.h"
#include "mcc_generated_files/system/pins.h"
#include "mcc_generated_files/adc/adc1.h"
#include "ssd1306.h"
#include <stdio.h>

#define FCY 100000000UL
#include <libpic30.h>

uint16_t adcValue;
char buffer[16];

int main(void)
{
    SYSTEM_Initialize();
    ADC1_Enable();
    SSD1306_Init();
    SSD1306_Clear();

    while (1)
    {
        ADC1_SoftwareTriggerEnable();
        __delay_us(50);
        adcValue = ADC1_ConversionResultGet(POT);

        // %4u + trailing spaces: pads the number and erases the previous digits
        sprintf(buffer, "POT: %4u   ", adcValue);
        SSD1306_SelectPage(0);
        SSD1306_WriteString(buffer);

        LED1_Toggle();          // heartbeat: confirms the loop is running
        __delay_ms(100);
    }
}
```

Turn the potentiometer: the number on the OLED should sweep between roughly `0` and `4095`, and LED1 should blink steadily.

`[CAPTURE: OLED showing "POT: nnnn", with the potentiometer at a mid position]`
`[CAPTURE: two photos side by side — potentiometer turned fully one way (~0) and fully the other (~4095) — to show the value tracking]`

### What you learned

- An **ADC** turns a continuous voltage into a discrete number; this 12-bit ADC gives 0–4095 over 0–3.3 V.
- A software-triggered ADC channel needs an explicit **Trigger Source** (Common Software Trigger), or it never converts.
- MCC's `I2C1_Write()` is **non-blocking** — you must wait on `I2C1_IsBusy()` between transfers, otherwise commands are dropped and the display stays blank.
- Reusing a third-party driver means respecting C basics: **definitions in a `.c`, `extern` declarations in the `.h`**, and the files physically inside the project.

### Next

**ADC + PWM** — reuse this ADC reading to drive a PWM duty cycle (for example LED brightness), closing the loop between an analog input and an analog-like output.


<div style='page-break-after: always;'></div>

## Proximity Sensor Project

In this section you will read the on-board **VCNL4200** infrared proximity sensor over I2C and show the live distance value on the OLED screen.

This is the **first stage of a larger application**: later sections will reuse this same reading to drive a colour LED (so the colour follows your hand) and to stream the value to a PC over the serial port. Here we focus on getting the sensor to talk.

### Goals

In this project you will:

- Configure and read a real external **I2C sensor** (the VCNL4200)
- Understand why a register read needs a **repeated start** (`I2C1_WriteRead`)
- Reuse the OLED to display the live **proximity** value

The tools involved are the **VCNL4200 proximity sensor**, the **OLED display**, and **LED1** as a heartbeat.

### Physical setup

The VCNL4200 and the OLED both sit on the **same I2C bus**, at different addresses (`0x51` for the sensor, `0x3D` for the screen), so there is nothing new to wire. As in the ADC project, only the two **I2C SDA** and **I2C SCL** jumpers in the COM remapping area need to be in place.

`[CAPTURE: board close-up showing the two I2C SDA / I2C SCL jumpers in place (same as the ADC project)]`

### How a proximity sensor works

The VCNL4200 has an infrared emitter and a light detector. It sends out IR pulses and measures how much light bounces back: the closer an object is, the more light is reflected, so the reported value **rises as something approaches** and falls back to a baseline when nothing is near. It is not an absolute distance in centimetres — it is a relative reflectance value (here 12-bit, 0–4095).

Communication is over I2C, but with one twist compared to the OLED: the sensor's registers are **16-bit words**, each addressed by a one-byte **command code**, and the data comes back **least-significant byte first**.

### Setting up on MPLAB

#### 1. Reuse the existing setup

No new MCC module is needed. You already have **I2C1 (Host, 100 kHz)** and the ported OLED driver from the ADC project — keep them. You do **not** need the ADC module here, since the sensor is digital (I2C), not analog.

#### 2. The VCNL4200 register map

We only need three registers, each identified by its command code:

| Command code | Register | Use |
|---|---|---|
| `0x03` | PS_CONF1 / PS_CONF2 | configuration (power on, integration time…) |
| `0x08` | PS_DATA | the proximity reading (16-bit, LSB first) |
| `0x0E` | ID | device ID — low byte is `0x58`, used to check the sensor is alive |

#### 3. Waking the sensor up

Out of reset, the proximity function is **shut down** (the `PS_SD` bit is set). To enable it, we write to the configuration register `0x03` with `PS_SD` cleared. We send three bytes: the command code, then the low byte (PS_CONF1), then the high byte (PS_CONF2).

```c
#define VCNL4200_ADDR     0x51
#define VCNL4200_PS_CONF  0x03   // command code: PS_CONF1 (low) + PS_CONF2 (high)
#define VCNL4200_PS_DATA  0x08   // command code: proximity output (16-bit, LSB first)
#define VCNL4200_ID       0x0E   // command code: device ID (low byte expected = 0x58)

static void VCNL4200_Init(void)
{
    // PS_CONF1 (low)  = 0x08 : proximity enabled (PS_SD = 0), medium integration time
    // PS_CONF2 (high) = 0x00 : 12-bit output, no interrupt (we poll)
    uint8_t cfg[3] = { VCNL4200_PS_CONF, 0x08, 0x00 };
    while (I2C1_IsBusy()) { }
    I2C1_Write(VCNL4200_ADDR, cfg, sizeof(cfg));
    while (I2C1_IsBusy()) { }
}
```

> The `0x08` configuration byte (integration time, duty) is a reasonable starting point. If your readings are too weak or too noisy, these are the tuning knobs to adjust — see the VCNL4200 datasheet.

#### 4. The repeated-start trap

This is the key new idea of this project. To read a register you cannot just "read 2 bytes" — you must first **tell the sensor which register** by sending its command code, and only then read the data. Crucially, between sending the command code and reading the result the bus must **not** be released: the read starts with a **repeated start**, not a fresh Start after a Stop. If you do a normal `I2C1_Write()` (which ends with a Stop) followed by a separate `I2C1_Read()`, the sensor loses track of the requested register and returns only zeros.

The MCC driver has exactly the right function for this: `I2C1_WriteRead()`, which writes the command code, inserts the repeated start, then reads — all in one transaction.

```c
// Read a 16-bit register via WriteRead (repeated start is mandatory)
static uint16_t VCNL4200_ReadReg(uint8_t reg)
{
    uint8_t rx[2] = {0, 0};
    while (I2C1_IsBusy()) { }
    I2C1_WriteRead(VCNL4200_ADDR, &reg, 1, rx, 2);
    while (I2C1_IsBusy()) { }
    return (uint16_t)(rx[0] | (rx[1] << 8));   // LSB first
}
```

#### 5. Validate before trusting the data

Before reading proximity, read the **ID register** (`0x0E`). It must return `0x58` in its low byte (`0x1058` as a full word). If you get that, the I2C link and the `WriteRead` are working; if not, fix the link first instead of chasing the proximity value. This is a cheap, reliable "is the device alive?" check — the same idea as pinging a device address.

#### 6. Putting it together

```c
#include "mcc_generated_files/system/system.h"
#include "mcc_generated_files/system/pins.h"
#include "mcc_generated_files/i2c_host/i2c1.h"
#include "ssd1306.h"
#include <stdio.h>

#define FCY 100000000UL
#include <libpic30.h>

#define VCNL4200_ADDR     0x51
#define VCNL4200_PS_CONF  0x03
#define VCNL4200_PS_DATA  0x08
#define VCNL4200_ID       0x0E

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

uint16_t prox;
char buffer[16];

int main(void)
{
    SYSTEM_Initialize();
    SSD1306_Init();
    SSD1306_Clear();
    VCNL4200_Init();

    // Sanity check: the ID must read 0x1058 (low byte 0x58)
    uint16_t id = VCNL4200_ReadReg(VCNL4200_ID);
    sprintf(buffer, "ID: %04X   ", id);
    SSD1306_SelectPage(0);
    SSD1306_WriteString(buffer);
    __delay_ms(2000);                 // hold the ID on screen for 2 s

    while (1)
    {
        prox = VCNL4200_ReadReg(VCNL4200_PS_DATA);
        sprintf(buffer, "PROX:%5u   ", prox);
        SSD1306_SelectPage(0);
        SSD1306_WriteString(buffer);

        LED1_Toggle();                // heartbeat
        __delay_ms(100);
    }
}
```

On power-up the screen briefly shows the device ID, then switches to the live proximity value: move your hand towards the sensor and the number climbs; pull away and it drops back.

`[CAPTURE: OLED showing "ID: 1058" at startup]`
`[CAPTURE: two photos side by side — hand far from the sensor (low value) and hand close (high value) — showing PROX tracking]`

### What you learned

- Driving an **external I2C sensor** means two steps: **configure** its registers, then **read** them.
- This sensor's registers are **16-bit, command-code addressed, LSB first**.
- A register read requires a **repeated start** — use `I2C1_WriteRead()`, never a separate Write then Read.
- Always **check the device ID first**: it isolates a wiring/protocol problem from a sensor-tuning problem.

### Next

This reading will now feed two outputs:

- **Colour LED (PWM)** — drive the on-board RGB LED with three PWM channels so its colour follows the proximity value. This is where PWM is finally used — and unlike a raw signal, you validate it directly with your eyes, no oscilloscope required.
- **Serial output (UART)** — send the proximity value to the PC over the debugger's virtual COM port (CDC), to read it in a terminal or plot it live in the Data Visualizer.