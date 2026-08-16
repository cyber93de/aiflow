---
name: stack-embedded
description: Architecture, quality and test checklist for embedded/firmware work in C or C++ — MCU and RTOS targets, HAL/driver separation, deterministic memory and timing, cross-compilation and flashing, on-host unit tests with a mocked HAL, and the failure modes that only bite on real hardware. Invoke when the project targets a microcontroller, an RTOS (FreeRTOS/Zephyr/RIOT), bare metal, or a Linux embedded board, when the build uses a cross-toolchain (arm-none-eabi, riscv, Xtensa), or on explicit request — "embedded", "firmware", "MCU", "bare metal", "ISR", "HAL", "cross-compile".
---

# Embedded / firmware

Applies `AGENTS.md` §2 (architecture rules) and §3a (quality gates) to a target where memory is
finite, timing is a contract, and "just restart it" is not an option.

## Layering (§2a, embedded dialect)

```
application   (state machines, business logic — no register access, no vendor SDK types)
     ↓
service       (sensor/actuator abstractions, protocol handlers, scheduling)
     ↓
HAL / port    (interface: gpio_set(), uart_write(), timer_start())
     ↓
driver / vendor SDK / register access   (the only layer that knows the chip)
```

- The **HAL is the port** (`§2a` interfaces at every seam) — application code calls
  `sensor_read_temperature()`, never `HAL_I2C_Mem_Read()`. This is what makes on-host testing and
  a chip swap possible at all.
- **No vendor SDK types above the driver layer.** `stm32f4xx_hal.h` in a state machine is the
  embedded equivalent of an ORM annotation on a domain entity.
- Board-specific pin/clock config lives in one `board_*.c`, never scattered through features.

## Non-negotiables

- **No dynamic allocation after init** on constrained targets. `malloc`/`new` in a control loop is
  a defect: fragmentation is unbounded and failure is unrecoverable. Static pools, fixed-size
  buffers, or arena allocation at startup.
- **ISRs are short and allocation-free.** Set a flag / push to a lock-free queue and return.
  No logging, no blocking, no `printf`. Anything shared with an ISR is `volatile` **and** access
  is either atomic or explicitly critical-sectioned — `volatile` alone is not a memory barrier.
- **Every buffer bound is checked.** No `strcpy`/`sprintf`/`gets`; use the `n`-variants with an
  explicit size, and validate every length that came off a wire.
- **Watchdog is fed from one place**, on evidence that the system is alive (all tasks checked in),
  never unconditionally from a timer ISR — that turns the watchdog into decoration.
- **Deterministic timing:** no unbounded loops in a real-time path; document worst-case execution
  where a deadline exists. Priority inversion is a design bug — use priority inheritance mutexes.
- **Integer discipline:** fixed-width types (`uint16_t`, not `int`), explicit about signedness and
  overflow, no undefined behaviour relied upon. Beware implicit promotion on 8/16-bit targets.
- **Power states** are part of the design, not an afterthought, on battery targets.

## Toolchain

- Cross-compile with the vendor/GCC toolchain (`arm-none-eabi-gcc`, `riscv64-unknown-elf-gcc`,
  Xtensa for ESP). On Windows this belongs in **WSL**, never MinGW — see the installation docs.
- Build with `cmake`+`ninja` or the vendor's generator; keep the linker script and the memory map
  in version control and **review changes to them like code**.
- Warnings are errors: `-Wall -Wextra -Werror`, plus `-Wconversion` where the codebase can take it.
- Static analysis is not optional here: `clang-tidy`, `cppcheck`, and MISRA-C where the domain
  requires it (automotive, medical, industrial). §3a's "no tool = do it yourself" still applies.
- Track flash and RAM usage per build (`size`, `.map` diff) and fail the build on a regression —
  running out of flash three months in is a schedule event, not a bug report.

## Testing (§3a on a target you can't easily run)

- **Unit tests run on the host**, not the MCU: compile the application and service layers against
  a **mocked HAL** (Unity+CMock, GoogleTest, Ceedling). That is the payoff of the HAL port — if a
  module can't be tested on the host, its dependencies are wrong.
- **Integration tests on real hardware** for the driver layer, ideally in a hardware-in-the-loop
  rig triggered from CI. Where no rig exists, say so in the handoff and keep the driver layer thin
  enough to review by eye.
- **BDD E2E** (§3a) maps to scenario tests against the device's external interface (serial
  protocol, CAN frames, BLE characteristics) — Given a device in state X, When frame Y arrives,
  Then …
- Simulate the failure cases that hardware will eventually produce: sensor returns garbage, bus
  times out, power browns out mid-write, flash write fails, clock drifts.

## Logging (§3a, adapted)

A `printf` on a 64 kB target is a design decision, not a convenience. Use a compile-time-levelled,
ring-buffered logger with a cheap transport (RTT, UART at a fixed rate, or binary/deferred logging
where bandwidth is tight). Levels still mean what §3a says they mean. Never log inside an ISR.

## Typical findings to raise

Blocking delay in a state machine · shared variable without `volatile` or a critical section ·
`malloc` in a loop · unbounded `while` waiting on a hardware flag with no timeout · watchdog fed
unconditionally · magic register values with no symbolic name · business logic reading a register
directly · a driver that also parses a protocol.
