## ============================================================
## tetris_top.xdc
## Constraints file for the Basys 3 board (Xilinx Artix-7,
## XC7A35T-1CPG236C).
##
## Pin numbers below are taken from Digilent's official
## Basys3_Master.xdc (github.com/Digilent/Basys3), verified
## against the source rather than assumed from memory.
##
## Port names match tetris_top.v exactly. If you rename any
## top-level port, update the corresponding get_ports line here.
## ============================================================

## ---- Clock (100 MHz onboard oscillator) ----
set_property PACKAGE_PIN W5 [get_ports clk_in]
set_property IOSTANDARD LVCMOS33 [get_ports clk_in]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports clk_in]

## ---- Reset button (center pushbutton, BTNC) ----
set_property PACKAGE_PIN U18 [get_ports btn_reset]
set_property IOSTANDARD LVCMOS33 [get_ports btn_reset]

## ---- Direction/action buttons ----
## Mapped as: Left=BTNL, Right=BTNR, Rotate=BTNU, Down/soft-drop=BTND
set_property PACKAGE_PIN W19 [get_ports btn_left_raw]
set_property IOSTANDARD LVCMOS33 [get_ports btn_left_raw]

set_property PACKAGE_PIN T17 [get_ports btn_right_raw]
set_property IOSTANDARD LVCMOS33 [get_ports btn_right_raw]

set_property PACKAGE_PIN T18 [get_ports btn_rotate_raw]
set_property IOSTANDARD LVCMOS33 [get_ports btn_rotate_raw]

set_property PACKAGE_PIN U17 [get_ports btn_down_raw]
set_property IOSTANDARD LVCMOS33 [get_ports btn_down_raw]

## ---- VGA Connector ----
## Basys 3 has 4 bits per color channel (RGB444), matching
## vga_red/vga_green/vga_blue[3:0] in tetris_top.v.
set_property PACKAGE_PIN G19 [get_ports {vga_red[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_red[0]}]
set_property PACKAGE_PIN H19 [get_ports {vga_red[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_red[1]}]
set_property PACKAGE_PIN J19 [get_ports {vga_red[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_red[2]}]
set_property PACKAGE_PIN N19 [get_ports {vga_red[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_red[3]}]

set_property PACKAGE_PIN J17 [get_ports {vga_green[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_green[0]}]
set_property PACKAGE_PIN H17 [get_ports {vga_green[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_green[1]}]
set_property PACKAGE_PIN G17 [get_ports {vga_green[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_green[2]}]
set_property PACKAGE_PIN D17 [get_ports {vga_green[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_green[3]}]

set_property PACKAGE_PIN N18 [get_ports {vga_blue[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_blue[0]}]
set_property PACKAGE_PIN L18 [get_ports {vga_blue[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_blue[1]}]
set_property PACKAGE_PIN K18 [get_ports {vga_blue[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_blue[2]}]
set_property PACKAGE_PIN J18 [get_ports {vga_blue[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {vga_blue[3]}]

set_property PACKAGE_PIN P19 [get_ports hsync]
set_property IOSTANDARD LVCMOS33 [get_ports hsync]
set_property PACKAGE_PIN R19 [get_ports vsync]
set_property IOSTANDARD LVCMOS33 [get_ports vsync]

## ---- Seven-segment display (score) ----
## Only needed if you add the seven_seg_driver instance to
## tetris_top.v and expose seg[6:0]/an[3:0] as top-level ports
## (see integration note at the bottom of this file).
set_property PACKAGE_PIN W7 [get_ports {seg[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[0]}]
set_property PACKAGE_PIN W6 [get_ports {seg[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[1]}]
set_property PACKAGE_PIN U8 [get_ports {seg[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[2]}]
set_property PACKAGE_PIN V8 [get_ports {seg[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[3]}]
set_property PACKAGE_PIN U5 [get_ports {seg[4]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[4]}]
set_property PACKAGE_PIN V5 [get_ports {seg[5]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[5]}]
set_property PACKAGE_PIN U7 [get_ports {seg[6]}]
set_property IOSTANDARD LVCMOS33 [get_ports {seg[6]}]

set_property PACKAGE_PIN U2 [get_ports {an[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[0]}]
set_property PACKAGE_PIN U4 [get_ports {an[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[1]}]
set_property PACKAGE_PIN V4 [get_ports {an[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[2]}]
set_property PACKAGE_PIN W4 [get_ports {an[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {an[3]}]

## ============================================================
## seg[6:0]/an[3:0] are already wired in tetris_top.v (the
## seven_seg_driver instance is connected to board_ctrl's
## internal "score" signal), so the constraints above should
## resolve directly during synthesis with no further wiring
## needed on your end.
## ============================================================

## ============================================================
## PmodBLE (phone control over Bluetooth LE)
## Pin numbers verified from Digilent's PmodBLE reference manual
## and the official Basys3_Master.xdc JB mapping.
##
## Plug PmodBLE into the JB Pmod port, using its top row of 6
## pins (pins 1-4 = RTS/RXD/TXD/CTS, pins 5-6 = GND/VCC, which
## connect to the Pmod connector's fixed ground/power pins and
## need no XDC entry). We only use TXD (pin 3) -- the byte
## stream the phone sends arrives there and the FPGA reads it
## as ble_rxd. RXD/RTS/CTS are left unconnected: we're receive-
## only, and simple apps like a BLE terminal don't need flow
## control for short, infrequent single-byte commands.
##
##   PmodBLE pin 3 (TXD) -> JB[2] -> ble_rxd
## ============================================================
set_property PACKAGE_PIN B15 [get_ports ble_rxd]
set_property IOSTANDARD LVCMOS33 [get_ports ble_rxd]

## ============================================================
## PmodAMP2: connect to JC TOP row, pins 1..6.
## Remove previous GAIN/GND and SHUTDOWN/VCC jumper wires.
## FPGA drives the control pins; never strap these driven pins to rails.
## Pin 1 AIN -> JC1 K17; pin 2 GAIN -> JC2 M18 (HIGH = 6 dB).
## Pin 3 NC; pin 4 ~SHUTDOWN -> JC4 P18 (HIGH = enabled).
## Pin 5 GND and pin 6 3.3V are connector power pins.
set_property PACKAGE_PIN K17 [get_ports audio_pwm]
set_property IOSTANDARD LVCMOS33 [get_ports audio_pwm]
set_property PACKAGE_PIN M18 [get_ports amp_gain]
set_property IOSTANDARD LVCMOS33 [get_ports amp_gain]
set_property PACKAGE_PIN P18 [get_ports amp_enable]
set_property IOSTANDARD LVCMOS33 [get_ports amp_enable]
