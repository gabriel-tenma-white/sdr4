library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
package fir_types is
	type intArray is array(integer range<>) of integer;
end package;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.fir_types.all;
entity fir is
	generic(order: integer := 10;
			coeffBits: integer := 12;
			bits: integer := 12;
			bitGrowth: integer := 4);
    Port (clk: in std_logic;
		inp: in signed(bits-1 downto 0);
		outp: out signed(bits+bitGrowth-1 downto 0);
		coeffs: intArray(order-1 downto 0)
		);
end;

architecture a of fir is
	constant internalBits: integer := bits+bitGrowth;
	
	-- coefficients
	type coeffArr is array(0 to order-1) of signed(coeffBits-1 downto 0);
	signal coeffB: coeffArr;
	
	
	type arrSrIn is array(0 to order*2-1) of signed(bits-1 downto 0);
	signal firSrIn: arrSrIn; -- new values come in at 0
	type multArr is array(0 to order-1) of signed(bits+coeffBits-1 downto 0);
	signal firMult1: multArr;
	type addArr is array(0 to order-1) of signed(internalBits-1 downto 0);
	signal firTrunc1,firAdd1: addArr;
begin
g0:
	for I in 0 to order-1 generate
		coeffB(I) <= to_signed(coeffs(I), coeffBits);
	end generate;

	-- input shift register
	firSrIn <= (inp) & firSrIn(0 to order*2-2) when rising_edge(clk);
	
	-- multipliers
g1:
	for I in 0 to order-1 generate
		firMult1(I) <= firSrIn(I*2+1) * coeffB(I) when rising_edge(clk);
	end generate;
	
	-- adders
g2:
	for I in 0 to order-1 generate
		firTrunc1(I) <= firMult1(I)(firMult1(I)'left downto firMult1(I)'left-internalBits+1);
	end generate;
g3:
	for I in 1 to order-1 generate
		firAdd1(I) <= firTrunc1(I) + firAdd1(I-1) when rising_edge(clk);
	end generate;
	firAdd1(0) <= firTrunc1(0) when rising_edge(clk);


	outp <= firAdd1(order-1) when rising_edge(clk);
end a;
