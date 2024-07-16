# Mini11-M8
MC68HC11A1 MCU based SBC

Documentation is a work in progress. This project is based on hardware and software provided here:
https://github.com/EtchedPixels/Mini11

# Memory Map
## Hardware
- 0000-7FFF  Bank 0 NVRAM
- 8000-EFFF  Bank 1 NVRAM
- F000-F03F  CPU control registers
- F040-F0FF  Internal RAM
- F100-F3FF  Bank 1 NVRAM
- F400-F7FF  Expansion Bus Device Select
- F800-FFFF  EPROM/EEPROM (read) / Memory Paging Register (write)
