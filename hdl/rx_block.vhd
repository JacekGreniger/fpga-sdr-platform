library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity rx_block is
  Port (
    TRXD       : in  STD_LOGIC_VECTOR(11 downto 0);
    TRXIQ	   : in  STD_LOGIC;
    TRXCLK	   : in  STD_LOGIC;
	 
    RST        : in  STD_LOGIC;
	 
    RD_CLK     : in  STD_LOGIC;
    DOUT       : out STD_LOGIC_VECTOR(15 downto 0);
    EMPTY      : out STD_LOGIC;
    RD_EN      : in  STD_LOGIC;
	 DEBUG_OUT : out STD_LOGIC	 
  );
end rx_block;

architecture Behavioral of rx_block is

component rx_fifo
  port (
    rst    : IN std_logic;
    wr_clk : IN std_logic;
    rd_clk : IN std_logic;
    din    : IN std_logic_VECTOR(15 downto 0);
    wr_en  : IN std_logic;
    rd_en  : IN std_logic;
    dout   : OUT std_logic_VECTOR(15 downto 0);
    full   : OUT std_logic;
    empty  : OUT std_logic
  );
end component;

signal din    : STD_LOGIC_VECTOR(15 downto 0);
signal full   : STD_LOGIC;
signal wr_clk : STD_LOGIC;
signal wr_en  : STD_LOGIC;

begin

inst_rx_fifo : rx_fifo
  port map (
	 rst    => RST,
    wr_clk => wr_clk,
    rd_clk => RD_CLK,
    din    => din,
    wr_en  => wr_en,
    rd_en  => RD_EN,
    dout   => DOUT,
    full   => full,
    empty  => EMPTY
  );

--By default, the time-aligned TRXD[11:0] and TRXIQ output
--signals are driven on the rising edge of the TRXCLK signal.
--Latching in fifo also on the rising edge.
  wr_clk <= not TRXCLK;
  wr_en  <= not full;
  din    <= TRXIQ & "000" & TRXD;
  DEBUG_OUT <= TRXIQ;
  
end Behavioral;

