# Mini11-M8
MC68HC11A1 MCU based SBC

## IMPORTANT! This project is deprecated. It's superceded by this device:
https://github.com/KenWillmott/Mini11-M8E

This project is based on hardware and software developed here:
https://github.com/EtchedPixels/Mini11

# Overview
This is a 10cm * 10cm PCB with an MC68HC11A1 processor. It uses only traditional through hole PCB construction and MSI glue logic in the 74HC line. It does not have any programmable logic device other than the usual EEPROM. There is one exception, the reset controller is an SMD device. This is because of a noticeable cost/availability problem with through hole type reset controllers. To interface with additional peripherals, the board follows M8 sytem outline and mounting hole dimensions, and is equipped with a full bus interface that will connect with the M8 series of peripheral expansion PCB's available on this hosting.

The processor itself has a lot of built in features that make a self contained computer easier to make. The serial connection can connect to a host computer or some other device. The processor can support a TF memory card directly with software driving the built in SPI. That gives it a disk. To complement that there is 512kb of non volatile memory, battery backed up. Any 32k bank of this memory can be assigned to either the upper or lower 32k of the CPU memory map, by writing to the memory paging control latch. This essentially makes all the memory selectively available to the CPU.

The main memory is made non-volatile using a DS1210 NVRAM controller IC. An option is provided for either 128kb or 512kb of memory. Either one is a single IC. There is provision for either an on board or external battery, and also an auxiliary battery for additional protection or to allow hot swapping batteries.

# Memory Map
## Hardware
- 0000-7FFF  Bank 0 NVRAM
- 8000-EFFF  Bank 1 NVRAM
- F000-F03F  CPU control registers
- F040-F0FF  Internal RAM
- F100-F3FF  Bank 1 NVRAM
- F400-F7FF  Expansion Bus Device Select
- F800-FFFF  EPROM/EEPROM (read) / Memory Paging Register (write)
## Software
(current)
- 0000-EC00 dual bank general purpose memory
- EF80  stack
- EFC4-EFFF CPU vector jump table
- F800-FB5F Boot code
- FF80  I/O vector table
- FFD6-FFFF CPU vectors
## Operation
Currently, the system boots from the 2k ROM space. It sets up some system variables and then attempts to boot from SD. If a disk is found, it will load the first sector of disk into RAM and then run it. If SD is not used, the 2k block below the highest block can be programmed with a stand alone monitor. The upper and lower half of upper 4k of EEPROM is configured with a jumper on the PCB, so that a choice of boot routines can be made. The monitor is duplicated with the boot firmware, so is available for support in case the disk does not operate.

The CPU vectors in high ROM are copied into a vector table in RAM so that they can be redirected. simple serial I/O routines are in ROM, and can be used by applications by referencing the table in ROM where they are combined.

Memory banking is simple. The upper 4 bits of the memory latch select one of sixteen 32kb blocs from the 512kb main memory, that will appear in the upper 32k of CPU memory. Similarly, the lower 4 bits of the memory latch select an independent 32k bank from main memory, which appears in the lower 32k of CPU memory.
# Connectors
## J2 SPI/SD
Connects to the MCU SPI pins, mimics the common pinout of an SD/TF card adapter module (such as often used with Arduino). The module must have its own 3.3V/5V signal voltage translation on board. Many modules don't have that and can't tolerate 5V from the MCU
## J1 Serial
Typical TX/RX/VCC/GND connections usually to a USB to serial adapter module.
## J3 Parallel I/O
MCU Port A pins PA0-PA6 are presented at a connector (PA7 is used for an additional SD chip select)
## J6 Analog
MCU ADC inputs PE0-PE3, VCC and GND
# Jumpers
## JP4 Boot select
- 0: monitor
- 1: boot from SD card
## J7 BAT1
Place a jumper across two of the three pins to select:
- int: connects internal battery to the NVRAM controller
- ext: use to connect an external backup battery (3.0V) or a jumper to disable the NVRAM.
## J8 BAT2
Optionally connect an secondary, auxiliary backup battery. If this is powered, the on board battery may be changed without any data loss. Place a jumper if no battery is connected.
## JP3 512/128
- 512: use 512kb IC such as AS6C4008
- 128: use 128kb IC such as AS6C1008
## RES SW
provision for an external reset switch. Note that the MCU reset circuit is not common drain, it is a CMOS driven voltage level. Thus any reset signal must not be applied to the MCU/bus RESET signal line, only to the internal/external reset switch circuit that controls the reset controller IC.
## MODA, MODB
These are MCU mode control pins. They are held high with pull up resistors so are left open in normal operation.
