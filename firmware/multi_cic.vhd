----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    23:17:06 06/12/2016 
-- Design Name: 
-- Module Name:    cic_lpf_nd - a 
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


-- a bank of integrators; inputs and outputs cycle between the N integrators
-- and the output at any given clock cycle is taken from the same integrator
-- that is receiving input
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.sr_signed;
entity cic_integrator_ring is
	generic(inbits,outbits,N: integer);
	port(clk: in std_logic;
			din: in signed(inbits-1 downto 0);	--unregistered
			dout: out signed(outbits-1 downto 0));	--registered
end entity;
architecture a of cic_integrator_ring is
	signal srIn,srOut: signed(outbits-1 downto 0);
begin
	sr1: entity sr_signed generic map(bits=>outbits,len=>N)
		port map(clk=>clk,din=>srIn,dout=>srOut);
	
	srIn <= srOut+resize(din,outbits);
	dout <= srOut;
end architecture;


-- bank of comb differentiators; dout data corresponds to the differentiator element
-- that received input from din in the last cycle
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.sr_signed;
entity cic_comb_multi is
	generic(bits,len,N: integer);
	port(clk: in std_logic;
			din: in signed(bits-1 downto 0);	--unregistered
			dout: out signed(bits-1 downto 0));	--registered
end entity;
architecture a of cic_comb_multi is
	signal delayed: signed(bits-1 downto 0);
begin
	sr1: entity sr_signed generic map(bits=>bits,len=>len*N)
		port map(clk=>clk,din=>din,dout=>delayed);
	dout <= delayed-din when rising_edge(clk);
end architecture;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.cic_integrator_ring;
use work.cic_comb_multi;

-- cic lowpass filter (non-decimating)
-- cycle delay is stages+1
entity cic_lpf_2_nd_multi is
	generic(inbits: integer := 10;
			outbits: integer := 18;
			stages: integer := 5;
			bw_div: integer := 3;	--the "differential delay" of the comb,
										--or the bandwidth division factor
			N: integer := 10
			);
	Port (clk : in  STD_LOGIC;
			din: in signed(inbits-1 downto 0);
			dout: out signed(outbits-1 downto 0));
end cic_lpf_2_nd_multi;
architecture a of cic_lpf_2_nd_multi is
	constant bitGrowth: integer := outbits-inbits;
	constant gain: integer := bw_div**stages;
	constant allowed_gain: integer := 2**bitGrowth;
	
	type tmp_t is array(0 to stages) of signed(outbits-1 downto 0);
	signal integrators: tmp_t;
	signal differentiators: tmp_t;
begin
	assert gain<=allowed_gain
		report "a bit growth of "&INTEGER'IMAGE(bitGrowth)
			&" will only allow a gain of"&INTEGER'IMAGE(allowed_gain)
			&", but gain (bw_div^stages) is "&INTEGER'IMAGE(gain)
			 severity error;

g1:	for I in 1 to stages generate
		integ: entity cic_integrator_ring generic map(outbits,outbits,N)
			port map(clk,integrators(I-1),integrators(I));
	end generate;
	integrators(0) <= resize(din,outbits) when rising_edge(clk);
g2:	for I in 1 to stages generate
		diff: entity cic_comb_multi generic map(outbits,bw_div,N)
			port map(clk,differentiators(I-1),differentiators(I));
	end generate;
	differentiators(0) <= integrators(stages);
	dout <= differentiators(stages);
end a;



