# sdr4
AD9363 + XC6SLX9 board

![sdr4](sdr4.jpg)

* To configure the AD9363 use the tool here: https://github.com/gabriel-tenma-white/sdr4-sw/tree/master/ad9361/sw (modify frequency and other parameters before running)
* Output is a 3-byte format defined by https://github.com/gabriel-tenma-white/sdr4/blob/master/firmware/sdr4_protocol.vhd
  * 2 12-bit values are packed into 3 bytes which are sent over the USB TTY device. Occasionally a 0xddbeef word is sent for synchronization
* The device accepts 8-bit bitbang words which are wired directly to AD9363 SPI pins. See usage here: https://github.com/gabriel-tenma-white/sdr4-sw/blob/master/ad9361/sw/platform_generic/platform.c (spiTransaction() function)

---
To open schematics, it is necessary to add all gEDA symbols here to your symbol library: https://github.com/gabriel-tenma-white/sym

To edit PCB layouts, make sure "packages" is a symlink to a cloned repository of: https://github.com/gabriel-tenma-white/packages2

