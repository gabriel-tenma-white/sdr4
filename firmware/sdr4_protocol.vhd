library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity sdr4Protocol is
    Port (
		clk: in std_logic;
		rxval: in std_logic;
		rxrdy: out std_logic;
		rxdat: in std_logic_vector(23 downto 0);
		
		txval: out std_logic;
		txrdy: in std_logic;
		txdat: out std_logic_vector(7 downto 0)
		);
end sdr4Protocol;

architecture a of sdr4Protocol is
	-- counts input periods
	signal counter,counterNext: unsigned(9 downto 0);
	
	signal state,stateNext,statePrev: unsigned(3 downto 0);
	signal rxrdyNext,rxrdyI: std_logic;
	
	signal sr,srNext: std_logic_vector(23 downto 0);
	signal curValid,curValidNext: std_logic;
begin
	counterNext <= counter+1;
	counter <= counterNext when state=2 and rising_edge(clk);
	
	
	
	stateNext <= to_unsigned(0, 4) when state=2 else state+1;
	state <= stateNext when rising_edge(clk);
	statePrev <= state when rising_edge(clk);
	
	rxrdyNext <= '1' when state=1 and counter/=0 else '0';
	rxrdyI <= rxrdyNext when rising_edge(clk);
	rxrdy <= rxrdyI;
	
	
	-- rxrdy is asserted when state=2, so new data comes when state=0
	curValidNext <= '1' when rxval='1' or counter=0 else '0';
	curValid <= curValidNext when state=2 and rising_edge(clk);
	
	srNext <= rxdat when rxrdyI='1' and rxval='1' else
			X"ddbeef" when state=2 and counter=0 else
			X"00"&sr(23 downto 8);
	sr <= srNext when rising_edge(clk);
	
	txval <= curValid;
	txdat <= sr(7 downto 0);
end a;
