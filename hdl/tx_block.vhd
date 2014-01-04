library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity tx_block is
  Port (
    TX_DATA_CLOCK_IN : in STD_LOGIC;
	 CLK_IN     : in STD_LOGIC; -- 48MHz
	 
	 CE         : in STD_LOGIC;
  
    TXD        : out  STD_LOGIC_VECTOR(11 downto 0);
    TXIQ	      : out  STD_LOGIC;
    TXCLK	   : out  STD_LOGIC;
	 
    RST        : in  STD_LOGIC;
	 TX_FIFO_FILL  : in  STD_LOGIC;
	 
    WR_CLK     : in  STD_LOGIC;
    DIN        : in STD_LOGIC_VECTOR(15 downto 0);
    FULL       : out STD_LOGIC;
    WR_EN      : in  STD_LOGIC;
	 DEBUG_OUT1 : out STD_LOGIC;
	 DEBUG_OUT2 : out STD_LOGIC
  );
end tx_block;

architecture Behavioral of tx_block is

component tx_fifo
	port (
     rst: IN std_logic;
     wr_clk: IN std_logic;
     rd_clk: IN std_logic;
     din: IN std_logic_VECTOR(15 downto 0);
     wr_en: IN std_logic;
     rd_en: IN std_logic;
     dout: OUT std_logic_VECTOR(15 downto 0);
     full: OUT std_logic;
     empty: OUT std_logic
  );
end component;

signal rd_clk : std_logic;
signal rd_en  : std_logic;
signal dout   : std_logic_VECTOR(15 downto 0);
signal dout_R : std_logic_VECTOR(15 downto 0);
signal empty  : std_logic;
signal empty_R  : std_logic;
signal txiq_sig : STD_LOGIC := '0';
signal comp     : STD_LOGIC;

signal cnt : integer range 0 to 15;
signal fifo_init : STD_LOGIC := '0';

signal tx_data_clock : STD_LOGIC;

begin

  inst_tx_fifo : tx_fifo
    port map (
      rst    => RST,
      wr_clk => WR_CLK,
      rd_clk => rd_clk,
      din    => DIN,
      wr_en  => WR_EN,
      rd_en  => rd_en,
      dout   => dout,
      full   => FULL,
      empty  => empty
	 );


  --[0x31]=0x9F, positive edge latches data
  
  process (CLK_IN, TX_FIFO_FILL) is
  begin
    if falling_edge(CLK_IN) then
	   fifo_init <= '0';
		
	   if TX_FIFO_FILL='1' then
	     cnt <= 0;
		elsif (cnt < 4) then
		  cnt <= cnt+1;
		  fifo_init <= '1';
		end if;
    end if;
  end process;
  
  tx_data_clock <= TX_DATA_CLOCK_IN when (fifo_init='0') else CLK_IN;
  
  process (tx_data_clock) is
  begin
    if falling_edge(tx_data_clock) then
		empty_R <= empty;
      dout_R <= dout(15 downto 0);
      txiq_sig <= not txiq_sig;
    end if;
  end process;

  comp <= not (dout_R(15) xor txiq_sig);

  rd_clk <= tx_data_clock;
  rd_en <= (not empty_R) and comp;

  TXCLK <= tx_data_clock and CE;
  TXIQ <= txiq_sig;
  TXD <= dout_R(11 downto 0);
  
  DEBUG_OUT1 <= comp; --txiq_sig;
  DEBUG_OUT2 <= fifo_init; --comp;
  
end Behavioral;

