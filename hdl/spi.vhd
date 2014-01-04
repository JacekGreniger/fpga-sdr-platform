-- spi rx/tx
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity spi is
  generic ( clock_divider : integer range 1 to 128 := 6 );
  Port ( 
    CLK_IN    : in STD_LOGIC;
    CE        : in STD_LOGIC;	
    SCLK      : out STD_LOGIC;	
    SDATA_IN  : in STD_LOGIC;
    SDATA_OUT : out STD_LOGIC;
	 SDATA_OE  : out STD_LOGIC;
    DATA_IN   : in STD_LOGIC_VECTOR(7 downto 0);
    DATA_OUT  : out STD_LOGIC_VECTOR(7 downto 0);
    START     : in STD_LOGIC;
    RW        : in STD_LOGIC;
    BUSY      : out STD_LOGIC 
  );
end spi;

architecture Behavioral of spi is

type state_type is (s0,s1,s2,s3,s4,s5,s6);
signal state      : state_type := s0;
signal state_next : state_type;

signal data      : std_logic_vector(7 downto 0);
signal data_next : std_logic_vector(7 downto 0);

signal data_in_R : std_logic_vector(7 downto 0);
signal data_out_R : std_logic_vector(7 downto 0);
signal data_out_next : std_logic_vector(7 downto 0);

signal bitcnt      : integer range 0 to 7;
signal bitcnt_next : integer range 0 to 7;

signal fdiv : integer := 0;
signal fdiv_next : integer := 0;

signal sdata_out_next : STD_LOGIC;
signal sdata_in_R : STD_LOGIC;
signal sdata_oe_next : STD_LOGIC; --'1' if output

signal sclk_next : STD_LOGIC;
signal busy_next : STD_LOGIC;
signal start_R : STD_LOGIC;
signal rw_R : STD_LOGIC;

begin

process (CLK_IN, CE) is
begin
  if rising_edge(CLK_IN) and CE='1' then
    state  <= state_next;
    bitcnt <= bitcnt_next;
    data   <= data_next;
	 fdiv   <= fdiv_next;
	 sdata_in_R <= SDATA_IN;
	 SDATA_OUT  <= sdata_out_next;
	 SDATA_OE  <= sdata_oe_next;
	 SCLK   <= sclk_next;
	 BUSY   <= busy_next;
	 data_in_R  <= DATA_IN;
	 start_R    <= START;
	 rw_R       <= RW;
	 DATA_OUT   <= data_out_next;
	 data_out_R <= data_out_next;
  end if;
end process;

process (state, data, bitcnt, fdiv, start_R, rw_R, data_in_R, sdata_in_R, data_out_R) is
begin
  data_next <= data;
  bitcnt_next <= bitcnt;
  fdiv_next <= fdiv;
  data_next <= data;
  busy_next <= '0';
  sclk_next <= '0';
  sdata_out_next <= '0';
  sdata_oe_next <= '1'; -- SDATA is output
  data_out_next <= data_out_R;
  
  case state is
    when s0=> -- idle
		fdiv_next <= clock_divider-1;
      state_next <= S0;
	 
      if (start_R='1' and rw_R='0') then -- spi write
        data_next <= data_in_R;
        bitcnt_next <= 7;
        busy_next <= '1';
        state_next <= S1;
		elsif (start_R='1' and rw_R='1') then -- spi read
		  sdata_oe_next <= '0'; -- SDATA is input
        bitcnt_next <= 7;
        busy_next <= '1';
        state_next <= S4;
		end if;
		
	 -- spi tx	
    when s1 =>
      sclk_next <= '0';
      sdata_out_next <= data(bitcnt);
		busy_next <= '1';
		if (fdiv = 0) then
		  fdiv_next <= clock_divider-1;
        state_next <= S2;
		else 
		  fdiv_next <= fdiv-1;
        state_next <= S1;
		end if;

    when s2=>
      sclk_next <= '1';
      sdata_out_next <= data(bitcnt);
		busy_next <= '1';
	   if (fdiv = 0) then
		  if (bitcnt = 0) then
          state_next <= S3;
        else
		    fdiv_next <= clock_divider-1;
          bitcnt_next <= bitcnt - 1;     
          state_next <= S1; --next bit
		  end if;
		else
		  fdiv_next <= fdiv-1;
        state_next <= S2;
      end if;
		
    when S3=> --ack
		busy_next <= '1';
      state_next <= S0;
	
	
	 -- spi rx
    when S4 =>
      sdata_oe_next <= '0'; -- SDATA is input
      sclk_next <= '0';
		busy_next <= '1';
		if (fdiv = 0) then
		  fdiv_next <= clock_divider-1;
        data_out_next(bitcnt) <= sdata_in_R; --store value before rising edge on SCLK
        state_next <= S5;
		else 
		  fdiv_next <= fdiv-1;
        state_next <= S4;
		end if;

    when S5=>
      sdata_oe_next <= '0'; -- SDATA is input
      sclk_next <= '1';
		busy_next <= '1';
	   if (fdiv = 0) then
		  if (bitcnt = 0) then
          state_next <= S6; -- last bit was received
        else
		    fdiv_next <= clock_divider-1;
          bitcnt_next <= bitcnt - 1;     
          state_next <= S4; --next bit
		  end if;
		else
		  fdiv_next <= fdiv-1;
        state_next <= S5;
      end if;
		
    when S6=> --ack
		busy_next <= '1';
      state_next <= S0;	
		
    when others =>
      state_next <= s0;
	 
  end case;
end process;

end Behavioral;
