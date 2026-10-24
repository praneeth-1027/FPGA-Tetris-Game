# Design and Implementation of a Tetris Game on FPGA

A Tetris game implemented in Verilog HDL on the Digilent Basys 3 FPGA board as a VLSI mini project. Game control, collision detection, board storage, video generation, scoring, and sound generation are implemented in digital hardware without a soft processor or external game software.

The game is displayed on a VGA monitor and controlled using the board's push-buttons. Optional Bluetooth Low Energy (BLE) control is supported through a PmodBLE module. A PmodAMP2 and speaker provide game sound effects.

## Team

| Name | Roll Number |
| --- | --- |
| Jaisujan SJ | CB.EN.U4ECE24123 |
| Praneeth J | CB.EN.U4ECE24138 |
| R S Vishal | CB.EN.U4ECE24141 |

## Features

- All seven tetrominoes with four rotation states.
- A 10 × 20 playfield with collision detection against walls, the floor, and settled blocks.
- Automatic falling, manual downward movement, piece locking, line clearing, and row shifting.
- Three-piece preview queue.
- Score display on the VGA monitor and the onboard seven-segment display.
- Session high score, game-over detection, and restart.
- Debounced push-button controls and optional BLE serial commands.
- Sound effects for movement, rejected moves, locking, line clearing, a new high score, and restart.

## Hardware and Software

| Item | Specification or Purpose |
| --- | --- |
| FPGA board | Digilent Basys 3 |
| FPGA device | Xilinx Artix-7 XC7A35T-1CPG236C |
| HDL | Verilog |
| Development tools | Vivado and Vivado Simulator; supplied implementation reports were generated with Vivado 2025.2 |
| Input clock | 100 MHz onboard oscillator |
| Pixel clock | 25 MHz |
| Automatic fall rate | 2 Hz game tick |
| Video output | 640 × 480, approximately 60 Hz, RGB444 |
| Local controls | Five onboard push-buttons, including reset |
| Wireless control | Optional PmodBLE and a compatible BLE terminal or controller app |
| Audio output | PmodAMP2 and speaker |
| Programming | USB connection to the Basys 3 |

## System Architecture

Button inputs pass through debounce circuits. BLE bytes pass through the UART receiver and command decoder. Both input paths produce the same movement commands for the game logic.

The game controller coordinates the active piece, board memory, preview queue, line processing, and score updates. The VGA driver combines the settled board, active piece, previews, score, and game-over popup into the displayed image. Sound events are passed to the tone generator for PWM audio output.

| Module | Responsibility |
| --- | --- |
| `tetris_top.v` | Integrates the game, input, video, audio, and score display modules |
| `clk_divider.v` | Generates the pixel clock and game tick from the board clock |
| `debounce.v` | Converts each physical button press into a clean pulse |
| `uart_rx.v` | Receives serial bytes at 115200 baud, 8N1 |
| `ble_cmd_decoder.v` | Converts supported ASCII bytes into movement commands |
| `board_ctrl.v` | Controls initialization, locking, line clearing, spawning, scoring, and game over |
| `board_memory.v` | Stores the 10 × 20 board using 3-bit colour cells |
| `piece_ctrl.v` | Handles piece movement, rotation, collision checks, and lock requests |
| `piece_rom.v` | Stores tetromino geometry and rotation bitmaps |
| `piece_gen.v` | Generates pseudo-random piece types using an LFSR |
| `vga_controller.v` | Generates pixel coordinates, sync signals, and the visible-region flag |
| `vga_driver.v` | Renders the playfield, piece, previews, score, and popup |
| `seven_seg_driver.v` | Displays the current score on the onboard display |
| `tone_gen.v` | Produces PWM sound effects from game events |

### Game Control

The game controller uses seven states:

| State | Operation |
| --- | --- |
| `S_INIT` | Initializes the piece preview queue |
| `S_FALLING` | Handles active gameplay and checks for locking or game over |
| `S_LOCK` | Writes the landed piece into board memory |
| `S_LINE_CHK` | Identifies completed rows |
| `S_CLEAR` | Clears completed rows, shifts the remaining rows, and updates the score |
| `S_SPAWN` | Selects the next piece and advances the preview queue |
| `S_GAME_OVER` | Waits for a movement command to start another game |

Each cleared row adds **100 points**. The current score and high score are stored as four-digit BCD values. The high score is retained when restarting after game over and is cleared by the reset button.

## Controls

| Action | Basys 3 Button | BLE Command |
| --- | --- | --- |
| Move left | BTNL | `L` or `l` |
| Move right | BTNR | `R` or `r` |
| Rotate | BTNU | `U` or `u` |
| Move down | BTND | `D` or `d` |
| Restart after game over | Any direction/action button | Any supported movement command |
| Reset game and high score | BTNC | Not assigned |

BLE commands are single ASCII characters. Unsupported bytes are ignored. The FPGA receives commands through a **115200 baud, 8 data bits, no parity, 1 stop bit** UART interface. Configure the BLE module's UART side to match these settings.

## Hardware Connections

The pin assignments are defined in `constraints/tetris_top.xdc`.

### Display and Programming

- Connect the monitor to the Basys 3 VGA connector.
- Connect the board to the computer through its USB programming interface.
- Use the onboard push-buttons for local gameplay.

### Optional BLE Control

Connect the PmodBLE to the **JB top row**, following the connector orientation in the supplied constraints.

| PmodBLE Connection | Basys 3 Connection | FPGA Signal |
| --- | --- | --- |
| Pin 3, TXD | JB3, package pin B15 | `ble_rxd` |
| Pin 5, GND | JB ground | Ground |
| Pin 6, VCC | JB 3.3 V supply | Power |

The implemented UART path is receive-only. Use a compatible BLE app to send the command characters listed above. With no BLE module attached, keep the UART RX input at its idle-high level if needed to avoid unintended commands.

### Audio Output

Connect the PmodAMP2 to the **JC top row** and attach the speaker to the amplifier output.

| PmodAMP2 Connection | Basys 3 Connection | FPGA Signal |
| --- | --- | --- |
| Pin 1, AIN | JC1, package pin K17 | `audio_pwm` |
| Pin 2, GAIN | JC2, package pin M18 | `amp_gain` |
| Pin 4, active-low shutdown input | JC4, package pin P18 | `amp_enable` |
| Pin 5, GND | JC ground | Ground |
| Pin 6, VCC | JC 3.3 V supply | Power |

The FPGA drives GAIN high and enables the amplifier when reset is inactive. Do not strap the FPGA-driven GAIN or shutdown pins directly to the supply or ground.

## Project Files

| Path | Contents |
| --- | --- |
| `src/` | Synthesizable Verilog modules |
| `constraints/tetris_top.xdc` | Board pin assignments and input clock constraint |
| `sim/` | Verilog testbenches and a schematic PDF |

## Simulation and Verification

The `sim/` directory includes module-level testbenches, integration scenarios, BLE tests, audio tests, and frame-capture testbenches.

Three dedicated use-case testbenches cover:

| Testbench | Scenario |
| --- | --- |
| `tb_uc1_piece_control.v` | Piece movement, rotation, collision detection, and locking |
| `tb_uc2_line_clear_score.v` | Completing a row, clearing it, shifting rows, and updating the score |
| `tb_uc3_vga_timing.v` | VGA pixel counting, visible-region timing, and synchronization |

To inspect a scenario in Vivado, add the required testbench as a simulation source, set it as the simulation top, and run behavioural simulation. Review its console output and waveform signals. Restore `tetris_top` as the design top before synthesis.

Some simulation sources provide waveform or image capture rather than automatic pass/fail checks; review each testbench's comments for its intended use.

## Implementation Results

The following values are taken from the supplied Vivado implementation reports. They describe the archived build and may change when the project is rebuilt.

| Resource | Used | Available | Utilization |
| --- | ---: | ---: | ---: |
| Slice LUTs | 2,042 | 20,800 | 9.82% |
| Slice registers | 1,141 | 41,600 | 2.74% |
| DSPs | 1 | 90 | 1.11% |
| Bonded IOBs | 35 | 106 | 33.02% |

| Timing Metric | Reported Value |
| --- | --- |
| Worst setup slack | +6.331 ns |
| Data path delay for the worst setup path | 3.625 ns |
| Logic contribution | 1.977 ns |
| Routing contribution | 1.648 ns |
| Worst hold slack | +0.253 ns |

These timing figures are reported for the constraints in the supplied project; they do not establish an independently measured maximum operating frequency.

## Design Notes

- Piece columns use signed arithmetic to handle the left boundary correctly.
- A spawn-cycle guard avoids checking game over against a stale piece position.
- The preview queue accounts for the LFSR output latency before capturing the next piece.
- The LFSR's value 7 is folded to 0 to select from seven piece types. This introduces a small distribution bias; the generator is not a seven-bag randomizer.
- The session high score is held in FPGA registers and is not retained across reset, power loss, or reprogramming.
