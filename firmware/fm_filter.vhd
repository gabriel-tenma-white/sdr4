library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fir_types.all;
use work.fir;
use work.cic_lpf_2_d;
use work.cic_lpf_2_nd;
use work.cic_lpf_2_nd_multi;
entity fm_filter is
	generic(bits: integer := 12;
			bitGrowth: integer := 4);
    Port (sampclk,clk,clk2,clk4,clk8: in std_logic;
		inp: in signed(bits-1 downto 0);
		outp: out signed(bits+bitGrowth-1 downto 0)
		);
end;

architecture a of fm_filter is
	constant outBits: integer := bits+bitGrowth;
	constant internalBits: integer := bits+6;
	constant order: integer := 11;
	constant order2: integer := 13;
	constant order3: integer := 15;
	constant order4: integer := 17;
	
	signal coeffs: intArray(order-1 downto 0);
	signal coeffs2: intArray(order2-1 downto 0);
	signal coeffs3: intArray(order3-1 downto 0);
	signal coeffs4: intArray(order4-1 downto 0);
	
	signal inp1: signed(bits-1 downto 0);
	signal tmp1,tmp2,tmp3: signed(internalBits-1 downto 0);
	
	signal cnt,cntNext: unsigned(7 downto 0);
	signal sync,syncNext: std_logic;
begin
	coeffs <= (0, 5, 52, 213, 459, 588, 459, 213, 52, 5, 0);
	coeffs2 <= (0, 0, 7, 62, 222, 450, 564, 450, 222, 62, 7, 0, 0);
	coeffs3 <= (0, 0, 0, -20, -43, 120, 554, 824, 554, 120, -43, -20, 0, 0, 0);
	coeffs4 <= (0, 0, 2, 0, -34, -56, 133, 567, 820, 567, 133, -56, -34, 0, 2, 0, 0);

	--filt: entity fir generic map(order,12,bits,bitGrowth)
	--	port map(clk,inp,tmp1,coeffs);
	--filt: entity cic_lpf_2_d generic map(bits,internalBits,4,4,2)
	--	port map(clk,clk4,inp,tmp1);
	filt: entity cic_lpf_2_nd_multi generic map(bits,internalBits,5,2,10)
		port map(clk,inp1,tmp1);
	
	inp1 <= inp when cnt=0 else to_signed(0,bits);
	
	cnt <= cntNext when rising_edge(clk);
	cntNext <= to_unsigned(0,8) when cnt=9 else cnt+1;
	sync <= syncNext when rising_edge(clk);
	syncNext <= '1' when cnt=0 else '0';
	
	tmp2 <= tmp1 when cnt=6 and rising_edge(clk);
	outp <= tmp2(tmp2'left downto tmp2'left-outBits+1) when rising_edge(sampclk);
	
	--filt2: entity fir generic map(order2,12,bits+bitGrowth,0)
	--	port map(clk,tmp1,outp,coeffs2);
	--filt3: entity fir generic map(order3,12,bits+bitGrowth,0)
	--	port map(clk4,tmp2,outp,coeffs3);
	--filt4: entity fir generic map(order4,12,bits+bitGrowth,0)
	--	port map(clk8,tmp3,outp,coeffs4);
	
end a;
