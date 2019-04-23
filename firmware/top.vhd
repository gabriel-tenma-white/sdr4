----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    14:35:18 08/01/2018 
-- Design Name: 
-- Module Name:    top - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library UNISIM;
use UNISIM.VComponents.all;


use work.clk_wiz_v3_6;
use work.ulpi_serial;
use work.dcfifo;
use work.slow_clock;
use work.slow_clock_odd;
use work.resetGenerator;
use work.sdr4Protocol;
use work.fm_filter;

entity top is
    Port (CLOCK_40_IN: in  STD_LOGIC;
           LED : out  STD_LOGIC_VECTOR (1 downto 0);
           
           AD9361_P0, AD9361_P1: inout std_logic_vector(11 downto 0);
           AD9361_FB_CLK, AD9361_TX_FRM, AD9361_ENABLE, AD9361_TXNRX, AD9361_RESET: out std_logic;
           AD9361_DATA_CLK, AD9361_RX_FRM: in std_logic;
           
           AD9361_SPI_CLK, AD9361_SPI_CS, AD9361_SPI_SDI: out std_logic;
           AD9361_SPI_SDO: in std_logic;
           
           
           LCD_SCL,LCD_SDI,LCD_CS,LCD_DC,LCD_RST: out std_logic;
			  
           USB_DIR: in std_logic;
			USB_NXT: in std_logic;
			USB_DATA: inout std_logic_vector(7 downto 0);
			USB_RESET_B: out std_logic;
			USB_STP: out std_logic;
			USB_REFCLK: out std_logic);
end top;

architecture a of top is
	signal internalclk,CLOCK_40,CLOCK_60,CLOCK_240,spiclk,adcclk: std_logic;
	
	--reset
	signal clkgen_en: std_logic := '0';
	signal usbclk: std_logic;
	signal reset: std_logic;
	
	
	--usb serial data
	signal rxval,rxrdy,rxclk,txval,txrdy,txclk,gpiotxval,adctxval: std_logic;
	signal rxdat,txdat,gpiotxdat,adctxdat: std_logic_vector(7 downto 0);
	signal usbtxval,usbtxrdy,usbrxval,usbrxrdy: std_logic;
	signal usbtxdat,usbrxdat: std_logic_vector(7 downto 0);
	signal txroom: unsigned(13 downto 0);
	signal tmp: unsigned(7 downto 0);
	signal led_usbserial: std_logic;
	signal usb_txcork: std_logic;
	
	signal fifo1empty,fifo1full: std_logic;
	
	-- usb adc data
	signal sampClk,coreClk,coreClk2,coreClk4,coreClk8: std_logic;
	signal usb_use_adcData,sdr4prxval,sdr4prxrdy: std_logic;
	signal P0buf1,P0buf2: std_logic_vector(11 downto 0);
	signal AD9361_RX_FRM_buf: std_logic;
	signal adcData,adcData1,adcData2,sdr4ptxdat,sdr4prxdat: std_logic_vector(23 downto 0);
	signal inI, inQ: signed(11 downto 0);
	signal filteredI, filteredQ: signed(15 downto 0);
	
	
	-- usb gpio
	signal gpioIn, gpioOut: std_logic_vector(7 downto 0); -- only lower 7 bits are used for gpioOut
	signal gpioClk, gpioDoSample: std_logic;
	signal gpioValue,gpioValueNext: std_logic_vector(7 downto 0); -- msb of gpioValue indicates whether to sample inputs
	
begin
	--############# CLOCKS ##############
	rg: entity resetGenerator generic map(10000) port map(spiclk, reset);
	pll: entity clk_wiz_v3_6 port map(
		CLK_IN1=>CLOCK_40_IN,
		CLK_OUT1=>CLOCK_40,
		CLK_OUT2=>CLOCK_60,
		CLK_OUT3=>CLOCK_240,
		CLK_OUT4=>sampClk);
	coreClk <= CLOCK_40;
	INST_STARTUP: STARTUP_SPARTAN6
        port map(
         CFGCLK => open,
         CFGMCLK => internalclk,
         CLK => '0',
         EOS => open,
         GSR => '0',
         GTS => '0',
         KEYCLEARB => '0');
	usbclk <= CLOCK_60;
	--adcclk <= CLOCK_40;
	-- 300kHz spi clock
	spic: entity slow_clock generic map(150,75) port map(internalclk,spiclk);
	gpioClk <= spiclk;
	
	
	--############# usb serial port device ##############
	usbdev: entity ulpi_serial generic map(minTxSize=>2048) port map(USB_DATA, USB_DIR, USB_NXT,
		USB_STP, open, usbclk, usbrxval,usbrxrdy,usbtxval,usbtxrdy, usbrxdat,usbtxdat,
		LED=>led_usbserial, txroom=>txroom, txcork=>'0', inhibitCork=>not usb_use_adcData);
	USB_RESET_B <= '1';
	outbuf: ODDR2 generic map(DDR_ALIGNMENT=>"NONE",SRTYPE=>"SYNC")
		port map(C0=>usbclk, C1=>not usbclk,CE=>'1',D0=>'1',D1=>'0',Q=>USB_REFCLK);
	
	-- fifos
	--fifo1: entity dcfifo generic map(8,13) port map(usbclk,txclk,
	--	usbtxval,usbtxrdy,usbtxdat,open,
	--	txval,txrdy,txdat,open);
	fifo2: entity dcfifo generic map(8,12) port map(rxclk,usbclk,
		rxval,rxrdy,rxdat,open,
		usbrxval,usbrxrdy,usbrxdat,open);
	
	-- usb gpio
	fifo1: entity dcfifo generic map(8,8) port map(usbclk,gpioClk,
		gpiotxval,'1',gpiotxdat,open,
		gpioValue(7),open,gpioIn,open);
	rxclk <= gpioClk;
	txclk <= gpioClk when usb_use_adcData='0' else sampClk;
	rxrdy <= '1';
	gpioValueNext <= rxdat when rxval='1' else "0"&gpioValue(6 downto 0);
	gpioValue <= gpioValueNext when rising_edge(gpioClk);
	
	gpioOut <= gpioValue when rising_edge(gpioClk);
	
	--gpiotxdat <= gpioIn when rising_edge(gpioClk);
	--gpiotxval <= gpioValue(7) when rising_edge(gpioClk);
	txdat <= gpiotxdat when usb_use_adcData='0' else adctxdat;
	txval <= gpiotxval when usb_use_adcData='0' else adctxval;
	
	-- gpio ports
	AD9361_SPI_CLK <= gpioOut(0);
	AD9361_SPI_CS <= gpioOut(1);
	AD9361_SPI_SDI <= gpioOut(2);
	gpioIn <= "0000" & AD9361_SPI_SDO & gpioOut(2 downto 0);
	
	
	-- usb adc data
	usb_use_adcData <= gpioOut(3);
	
	adcclk_buf: IBUFG port map(O => adcClk, I => AD9361_DATA_CLK);
gen_iddr2:
	for I in 0 to 11 generate
		adcdat_buf: IDDR2 port map(C0=>not adcClk, C1=>adcClk, CE=>'1',
						D=>AD9361_P0(I), Q0=>P0buf1(I), Q1=>P0buf2(I));
	end generate;
	adcData2(11 downto 0) <= P0buf1 when falling_edge(adcClk);
	adcData2(23 downto 12) <= P0buf2 when falling_edge(adcClk);
	adcData1 <= adcData2 when rising_edge(adcClk);
	adcfifo: entity dcfifo generic map(24,4) port map(sampClk,adcClk,
		open,'1',adcData,open,
		'1',open,adcData1,open);
	
	-- filter
	coreClk2 <= not coreClk2 when rising_edge(coreClk);
	coreClk4 <= not coreClk4 when rising_edge(coreClk2);
	coreClk8 <= not coreClk8 when rising_edge(coreClk4);
	
	inI <= signed(adcData(11 downto 0)) when rising_edge(sampClk);
	inQ <= signed(adcData(23 downto 12)) when rising_edge(sampClk);
	filtI: entity fm_filter port map(sampClk,coreClk,coreClk2,coreClk4,coreClk8, inI, filteredI);
	filtQ: entity fm_filter port map(sampClk,coreClk,coreClk2,coreClk4,coreClk8, inQ, filteredQ);
	sdr4ptxdat(11 downto 0) <= std_logic_vector(filteredI(filteredI'left downto filteredI'left-11)) when rising_edge(sampClk);
	sdr4ptxdat(23 downto 12) <= std_logic_vector(filteredQ(filteredQ'left downto filteredQ'left-11)) when rising_edge(sampClk);
	
	
	fifo3: entity dcfifo generic map(24,8) port map(usbclk,sampClk,
		sdr4prxval,sdr4prxrdy,sdr4prxdat,open,
		'1',open,sdr4ptxdat,open);
	
	sdr4p: entity sdr4Protocol port map(usbclk, sdr4prxval, sdr4prxrdy, sdr4prxdat, adctxval, '1', adctxdat);
	
	
	
	-- usb tx data selection
	usbtxdat <= adctxdat when usb_use_adcData='1' else gpiotxdat;
	usbtxval <= adctxval when usb_use_adcData='1' else gpiotxval;
	
	
	LED <= led_usbserial & "1";
	
	
	outbuf2: ODDR2 generic map(DDR_ALIGNMENT=>"NONE",SRTYPE=>"SYNC")
		port map(C0=>adcclk, C1=>not adcclk,CE=>'1',D0=>'1',D1=>'0',Q=>AD9361_FB_CLK);
	AD9361_P1 <= "100000000000";
	AD9361_RESET <= not reset;
	AD9361_ENABLE <= '0';
	--AD9361_FB_CLK <= '0';
	AD9361_TXNRX <= '0';
	AD9361_TX_FRM <= '1';
	LCD_DC <= '0';
	LCD_CS <= '0';
	LCD_SDI <= '0';
	LCD_SCL <= '0';
end a;

