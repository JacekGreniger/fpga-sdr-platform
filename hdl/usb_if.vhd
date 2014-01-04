library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Implementation of fifo read:
--
--              +-- latching data in cypress
--              |
-- ifclock --|__|--|__|--|__|--|__|--
-- 
-- sloe    --|___________|--------------
--
--                 |___ latching fdata_in
--
-- slrd    --|_____|---------------------
--
-- wr_en   ______________|-----|_________ fifo write
--
-- 
--
entity usb_if is
  Port (
    FDATA     : inout STD_LOGIC_VECTOR(15 downto 0);  --  FIFO data lines.
    FADDR     : out STD_LOGIC_VECTOR(1 downto 0); --  FIFO select lines
    SLRD      : out STD_LOGIC;                    -- Read control line
    SLWR      : out STD_LOGIC;                    -- Write control line
    
    FLAGA     : in  STD_LOGIC;                    --EP2 empty flag
    FLAGB     : in  STD_LOGIC;                    --EP4 empty flag
    FLAGC     : in  STD_LOGIC;                    --EP8 full flag
    FLAGD     : in  STD_LOGIC;                    --EP6 full flag
    IFCLK     : in  STD_LOGIC;                    --Interface Clock
    SLOE      : out STD_LOGIC;                    --Slave Output Enable control
    PKTEND    : out STD_LOGIC;                    --packet end
    EP4_DOUT  : out STD_LOGIC_VECTOR(15 downto 0);
    EP4_RD_EN : in STD_LOGIC;
    EP4_EMPTY : out STD_LOGIC;

    EP8_FIFO_DIN   : in STD_LOGIC_VECTOR(15 downto 0);
    EP8_FIFO_WR_EN : in STD_LOGIC;
    EP8_FIFO_FULL  : out STD_LOGIC;
	 
	 MODE_SEL  : in STD_LOGIC_VECTOR(1 downto 0);

    RX_FIFO_DOUT  : in STD_LOGIC_VECTOR(15 downto 0);
    RX_FIFO_EMPTY : in STD_LOGIC;
    RX_FIFO_RD_EN : out STD_LOGIC;

    TX_FIFO_DIN   : out STD_LOGIC_VECTOR(15 downto 0);
    TX_FIFO_FULL  : in STD_LOGIC;
    TX_FIFO_WR_EN : out STD_LOGIC;
	 
	 RX_LED    : out STD_LOGIC;
	 TX_LED    : out STD_LOGIC
  );
end usb_if;


architecture rtl of usb_if is

COMPONENT ep4_fifo
  port (
    clk  : IN std_logic;
    rst  : IN std_logic;
    din  : IN std_logic_VECTOR(15 downto 0);
    wr_en: IN std_logic;
    rd_en: IN std_logic;
    dout : OUT std_logic_VECTOR(15 downto 0);
    full : OUT std_logic;
    empty: OUT std_logic
  );
end COMPONENT ep4_fifo;

component ep8_fifo
	port (
	clk   : IN std_logic;
	rst   : IN std_logic;
	din   : IN std_logic_VECTOR(15 downto 0);
	wr_en : IN std_logic;
	rd_en : IN std_logic;
	dout  : OUT std_logic_VECTOR(15 downto 0);
	full  : OUT std_logic;
	empty : OUT std_logic);
end component;

signal faddr_next  : STD_LOGIC_VECTOR(1 downto 0); --  FIFO select lines
signal slrd_next   : STD_LOGIC;                    -- Read control line
signal slwr_next   : STD_LOGIC;                    -- Write control line
signal sloe_next   : STD_LOGIC;                     --Slave Output Enable control
signal data_next   : STD_LOGIC_VECTOR(15 downto 0);  --  FIFO data lines.
signal data        : STD_LOGIC_VECTOR(15 downto 0);  --  FIFO data lines.

signal tx_led_next : STD_LOGIC;
signal rx_led_next : STD_LOGIC;

type state_type is (s0,s1,s2, 
                    S_EP8_WR1, S_EP8_WR2, S_EP8_WR3,
						  s10,s11,s12, 
						  s20,s21, 
						  s30,
						  S40,S41, 
						  S50,S51,S52);
						  
signal sm      : state_type := s0;
signal sm_next : state_type;

signal flaga_R   : STD_LOGIC; --EP2 empty
signal flagb_R   : STD_LOGIC; --EP4 empty
signal flagc_R   : STD_LOGIC; --EP8 full
signal flagd_R   : STD_LOGIC; --EP6 full

signal pktend_next : STD_LOGIC;
  
signal cnt : integer range 0 to 2**20-1;
signal cnt_next : integer range 0 to 2**20-1;

signal reset : STD_LOGIC;
signal resetcnt : integer range 0 to 1023;

signal ep4_fifo_data       : STD_LOGIC_VECTOR(15 downto 0);
signal ep4_fifo_data_R     : STD_LOGIC_VECTOR(15 downto 0);
signal ep4_fifo_data_next  : STD_LOGIC_VECTOR(15 downto 0);

signal ep4_fifo_wr_en : STD_LOGIC;
signal ep4_fifo_wr_en_next : STD_LOGIC;
signal ep4_fifo_full  : STD_LOGIC;

signal mode_sel_R : STD_LOGIC_VECTOR(1 downto 0);

signal fdata_out  : STD_LOGIC_VECTOR(15 downto 0);
signal fdata_out_next  : STD_LOGIC_VECTOR(15 downto 0);

signal fdata_in : STD_LOGIC_VECTOR(15 downto 0);
  
signal test_cnt1 : STD_LOGIC_VECTOR(15 downto 0) := (others=>'0');
signal test_cnt1_next : STD_LOGIC_VECTOR(15 downto 0) := (others=>'0');

signal rx_fifo_dout_R     : STD_LOGIC_VECTOR(15 downto 0);
signal rx_fifo_empty_R    : STD_LOGIC;
signal rx_fifo_rd_en_next : STD_LOGIC;	  

signal drop_cnt      : integer range 0 to 4095 := 0;
signal drop_cnt_next : integer range 0 to 4095 := 0;

signal tx_fifo_din_next   : STD_LOGIC_VECTOR(15 downto 0);
signal tx_fifo_full_R     : STD_LOGIC;
signal tx_fifo_wr_en_next : STD_LOGIC;	  

signal ep8_fifo_dout       : STD_LOGIC_VECTOR(15 downto 0);
signal ep8_fifo_dout_R     : STD_LOGIC_VECTOR(15 downto 0);
signal ep8_fifo_empty      : STD_LOGIC;
signal ep8_fifo_empty_R    : STD_LOGIC;
signal ep8_fifo_rd_en      : STD_LOGIC;
signal ep8_fifo_rd_en_next : STD_LOGIC;

begin
  --TX_LED <= '0';
  --RX_LED <= '0';
  
  Inst_ep4_fifo : ep4_fifo
  port map (
    clk   => IFCLK,
    rst   => reset,
    din   => ep4_fifo_data,
    wr_en => ep4_fifo_wr_en,
    rd_en => EP4_RD_EN,
    dout  => EP4_DOUT,
    full  => ep4_fifo_full,
    empty => EP4_EMPTY
  );

  
  Inst_ep8_fifo : ep8_fifo
  port map (
    clk   => IFCLK,
    rst   => reset,
    din   => EP8_FIFO_DIN,
    wr_en => EP8_FIFO_WR_EN,
    rd_en => ep8_fifo_rd_en,
    dout  => ep8_fifo_dout,
    full  => EP8_FIFO_FULL,
    empty => ep8_fifo_empty
  );
  

  process (IFCLK) is
  begin
    if rising_edge(IFCLK) then
      if (resetcnt < 1000) then
        reset <= '1';
        resetcnt <= resetcnt + 1;
      else
        reset <= '0';
      end if;
    end if;
  end process;

  process (ifclk) is
  begin
    if falling_edge(ifclk) then
      flagd_R <= FLAGD;
      flaga_R <= FLAGA;
      flagc_R <= FLAGC;
      flagb_R <= FLAGB;

      ep4_fifo_wr_en <= ep4_fifo_wr_en_next;
		
      ep4_fifo_data_R <= ep4_fifo_data_next;    
      ep4_fifo_data   <= ep4_fifo_data_next;    

      SLOE <= sloe_next;
      SLRD <= slrd_next;
      SLWR <= slwr_next;
      FADDR <= faddr_next;
      PKTEND <= pktend_next;
		
      data <= data_next;
      cnt <= cnt_next;
      sm <= sm_next;
		mode_sel_R <= MODE_SEL;

      test_cnt1 <= test_cnt1_next;
 
 		if (sloe_next='0') then --output enable
		  FDATA <= "ZZZZZZZZZZZZZZZZ";
		  fdata_in <= FDATA;
		else
		  FDATA <= fdata_out_next;
		end if;
		  
      rx_fifo_dout_R  <= RX_FIFO_DOUT;
      rx_fifo_empty_R <= RX_FIFO_EMPTY;
      RX_FIFO_RD_EN   <= rx_fifo_rd_en_next;  
		
      TX_FIFO_DIN    <= tx_fifo_din_next;
      TX_FIFO_WR_EN  <= tx_fifo_wr_en_next;  
      tx_fifo_full_R <= TX_FIFO_FULL;

		drop_cnt <= drop_cnt_next;

      ep8_fifo_empty_R <= ep8_fifo_empty;
      ep8_fifo_rd_en   <= ep8_fifo_rd_en_next;
      ep8_fifo_dout_R  <= ep8_fifo_dout;
		
		TX_LED <= tx_led_next;
		RX_LED <= rx_led_next;
   end if;
  end process;

  --http://www.edaboard.com/thread55243.html

-- flaga=0 - EP2 is empty, PC->FPGA (codec data)
-- flagb=0 - EP4 is empty  PC->FPGA
-- flagc=0 - EP8 is full   FPGA->PC
-- flagd=0 - EP6 is full   FPGA->PC (codec data)  

  process (sm, flaga_R, flagb_R, flagc_R, flagd_R, cnt, fdata_in, data, ep4_fifo_data_R, ep4_fifo_full, 
           mode_sel_R, test_cnt1, rx_fifo_dout_R, rx_fifo_empty_R, drop_cnt,
			  tx_fifo_full_R, ep8_fifo_empty_R, ep8_fifo_dout_R) is
  begin
    sloe_next <= '1';
    slrd_next <= '1';
    slwr_next <= '1';
    faddr_next <= "00";
    data_next <= data;
    cnt_next <= cnt;
    pktend_next <= '1';
    ep4_fifo_data_next <= ep4_fifo_data_R;
    ep4_fifo_wr_en_next <= '0';
    fdata_out_next <= (others=>'0');
	 test_cnt1_next <= test_cnt1;  
    rx_fifo_rd_en_next <= '0';
	 drop_cnt_next <= drop_cnt;

    tx_fifo_din_next <= (others=>'0');
    tx_fifo_wr_en_next <= '0';
	 
	 ep8_fifo_rd_en_next <= '0';
	 
	 tx_led_next <= '1';
	 rx_led_next <= '1';

    case sm is
      when S0 =>
        cnt_next <= cnt + 1;
      
        if cnt=(2**19) and flagc_R='1' and ep8_fifo_empty_R='0' then 
          --EP8 write
			 faddr_next <= "11";
			 ep8_fifo_rd_en_next <= '1';
          sm_next <= S_EP8_WR1;
			 
		  --tempo wpisywania do kodeka jest wazne, dla 2**20 rzadko przechodzila inicjalizacja oraz bist
        elsif cnt=(2**20-1) and flagb_R='1' and ep4_fifo_full='0' then -- flagb_R - EP4 not empty
          --EP4 read
          faddr_next <= "01"; --EP4
          --sloe_next <= '0';
          --slrd_next <= '0';
          cnt_next <= 0;
          sm_next <= S10;

        elsif mode_sel_R="00" and rx_fifo_empty_R='0' and flagd_R='1' then -- flagd_R - EP6 not full
		    --codec rx mode, EP6 write
          faddr_next <= "10";
          rx_fifo_rd_en_next <= '1';			 
			 tx_led_next <= '0';
          sm_next <= S40;
        elsif mode_sel_R="00" and tx_fifo_full_R='0' and flaga_R='1' then -- flaga_R=1 - EP2 in not empty
		    --codec tx mode, EP2 read
          faddr_next <= "00"; --EP2
          --sloe_next <= '0';
          --slrd_next <= '0';	
			 rx_led_next <= '0';
          sm_next <= S50;
			 
        elsif mode_sel_R="11" and flagd_R='1' and flaga_R='1' then -- flagd_R - EP6 not full
		    --loopback  mode
			 faddr_next <= "00"; --EP2
          sloe_next <= '0';
          slrd_next <= '0';			 
          sm_next <= S1;
        elsif mode_sel_R="01" and flagd_R='1' then -- flagd_R - EP6 full
		    --EP6 write, pc receives data test mode
			 faddr_next <= "10"; --EP6 write endpoint
          sm_next <= S20;
        elsif mode_sel_R="10" and flaga_R='1' then -- flaga_R - EP2 empty
		    --EP2 read, pc sends data test mode
		    faddr_next <= "00"; --EP2
          sloe_next <= '0';
          sm_next <= S30;
			 
        else
          sm_next <= S0;
        end if;
      
		-- loopback
      when S1 =>
        faddr_next <= "00";
		  sloe_next <= '0';
        sm_next <= S2;
		  -- po tym stanie nastapi zatrzasniecie fdata_in

      when S2 =>
        faddr_next <= "10"; -- EP6
        fdata_out_next <= fdata_in;
		  if flagd_R='1' then -- flagd_R==1 - EP6 is not full
          slwr_next <= '0';
          sm_next <= S0;
		  else
		    sm_next <= S2;
		  end if;


      --EP8 write
      when S_EP8_WR1 =>
        faddr_next <= "11";
		  --zatrzasniecie odebranej danej
        sm_next <= S_EP8_WR2;
		  
      when S_EP8_WR2 =>
        faddr_next <= "11";
        fdata_out_next <= ep8_fifo_dout_R;
        slwr_next <= '0';
        sm_next <= S_EP8_WR3;

      when S_EP8_WR3 =>
        faddr_next <= "11";
        pktend_next <= '0';
        sm_next <= S0;

      --EP4 read
      when S10 =>
		  if flagb_R='1' and ep4_fifo_full='0' then -- flagb_R - EP4 not empty
          faddr_next <= "01";
          sloe_next <= '0';
          slrd_next <= '0';
          sm_next <= S11;
		  else
          sm_next <= S0;
		  end if;
		  
      when S11 =>
        faddr_next <= "01";
		  -- latching input data into fdata_in
        sloe_next <= '0';
        sm_next <= S12;
		  
      when S12 =>
        faddr_next <= "01";
        ep4_fifo_data_next <= fdata_in;
        ep4_fifo_wr_en_next <= '1';
        sm_next <= S0;

        --A Xilinx COREGEN based FIFO will store data when write enable is high and
        --the FIFO isn't full, it will put valid data only 1 clock cycle after
        --read_enable was asserted with the FIFO not empty. 		  

      --EP6 write, --pc receives data test mode
      when S20 =>
        faddr_next <= "10"; --EP6
		  if flagd_R='1' then -- flagd_R - EP6 not full
          sm_next <= S21;
		  else
          sm_next <= S0;
		  end if;
		  
      when S21 =>
        faddr_next <= "10";
        fdata_out_next <= test_cnt1;
		  --bez powtornego sprawdzenia flagi czasami traci sie wpisywane dane
		  if flagd_R='1' then -- flagd_R - EP6 full
          slwr_next <= '0';
  		    test_cnt1_next <= test_cnt1 + 1;
		  end if;
        sm_next <= S0;


      --EP2 read, pc sends data test mode 
      when S30 =>
		  faddr_next <= "00"; --EP2
		  if flaga_R='1' then -- flaga_R=1 - EP2 not empty
          slrd_next <= '0';
		  else
          slrd_next <= '1';
		  end if;
        sm_next <= S0;


      --codec rx, EP6 write
      when S40 =>
		  tx_led_next <= '0';
        faddr_next <= "10";
        rx_fifo_rd_en_next <= '0';
		  drop_cnt_next <= 0;
		  --zatrzasniecie danej wyjsciowej fifo do rx_fifo_dout_R
        sm_next <= S41;

      when S41 =>
		  tx_led_next <= '0';
        faddr_next <= "10";
		  fdata_out_next <= rx_fifo_dout_R;
		  if flagd_R='1' then --ep8 fifo is not full
          slwr_next <= '0';
          sm_next <= S0;
		  else 
		    if drop_cnt = 4095 then
			   sm_next <= S0;
			 else
            drop_cnt_next <= drop_cnt + 1;			  
		      sm_next <= S41;
			 end if;
		  end if;          

      --codec tx, EP2 read
      when S50 =>
		  rx_led_next <= '0';
        if tx_fifo_full_R='0' and flaga_R='1' then -- flaga_R=1 - EP2 in not empty
          --trzeba sprawdzac powtornie stan bo albo tx_fifo albo cypress
			 --nieprawidlowo wskazuje, ze mozna oczytywac/ladowac dane
          faddr_next <= "00"; --EP2
          sloe_next <= '0';
          slrd_next <= '0';		
          sm_next <= S51;
		  else
          sm_next <= S0;
		  end if;
		  
		when S51 =>
		  rx_led_next <= '0';
        faddr_next <= "00";
		  -- latching input data into fdata_in
        sloe_next <= '0';
        sm_next <= S52;
		  
      when S52 =>
		  rx_led_next <= '0';
        faddr_next <= "00";
        tx_fifo_din_next <= fdata_in;
        tx_fifo_wr_en_next <= '1';
        sm_next <= S0;
		  
      when others =>
        sm_next <= S0;

    end case;
  end process;
  
end rtl;

