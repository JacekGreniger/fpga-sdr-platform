-- ISE Webpack 12.3

--ver 15
-- 06.02.2013
-- RX_AUX no longer controlled by AUX CONTROL command (0x40), it's now another SPI port (0x20 0x00)
-- increasing EP4 fifo for receiving control commands from 512B to 1024B to avoid timeout problems during gr-fsdr startup

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.vcomponents.all;

entity fsdr_top is
  Port ( 
    CLK_IN	: in  STD_LOGIC;
    CODEC_CLK_OUT	: out  STD_LOGIC;

    BUTTON_SELECT	: in  STD_LOGIC;

    LED_S1	: out  STD_LOGIC;
    LED_S2	: out  STD_LOGIC;
    LED_S3	: out  STD_LOGIC;

    TP82	  : out  STD_LOGIC;
    TP84	  : out  STD_LOGIC;

    FD	    : inout  STD_LOGIC_VECTOR(15 downto 0);

    FLAGA	  : in  STD_LOGIC; -- flaga=0 - EP2 is empty, PC->FPGA (codec data)
    FLAGB	  : in  STD_LOGIC; -- flagb=0 - EP4 is empty  PC->FPGA 
    FLAGC	  : in  STD_LOGIC; -- flagc=0 - EP8 is full   FPGA->PC 
    FLAGD	  : in  STD_LOGIC; -- flagd=0 - EP6 is full   FPGA->PC (codec data) 

    PKTEND	: out  STD_LOGIC;
    FIFOADR : out  STD_LOGIC_VECTOR(1 downto 0);
    SLOE	   : out  STD_LOGIC;
    SLWR	   : out  STD_LOGIC;
    SLRD	   : out  STD_LOGIC;
    IFCLK	: out  STD_LOGIC;


    TXD        : out  STD_LOGIC_VECTOR(11 downto 0);
    TXIQ	      : out  STD_LOGIC;
    TXCLK	   : out  STD_LOGIC;
	 
    TX_SCS	   : out  STD_LOGIC;
    TX_SCLK	   : out  STD_LOGIC;
    TX_SDAT	   : inout  STD_LOGIC;
    TX_AUX	   : out  STD_LOGIC;

    TRXD       : in  STD_LOGIC_VECTOR(11 downto 0);
    TRXIQ	   : in  STD_LOGIC;
    TRXCLK	   : in  STD_LOGIC;
	 
    RX_SCS	   : out  STD_LOGIC;
    RX_SCLK	   : out  STD_LOGIC;
    RX_SDAT	   : inout  STD_LOGIC;
    RX_AUX	   : out  STD_LOGIC;

    CODEC_SCS	  : out  STD_LOGIC;
    CODEC_SCLK	  : out  STD_LOGIC;
    CODEC_SDAT	  : inout  STD_LOGIC;
    CODEC_RESET  : out  STD_LOGIC
  );
end fsdr_top;


architecture Behavioral of fsdr_top is

constant FW_VERSION : std_logic_vector(7 downto 0) := X"15";

COMPONENT usb_if is
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
	 
	 MODE_SEL  : in STD_LOGIC_VECTOR(1 downto 0);

    RX_FIFO_DOUT  : in STD_LOGIC_VECTOR(15 downto 0);
    RX_FIFO_EMPTY : in STD_LOGIC;
    RX_FIFO_RD_EN : out STD_LOGIC;

    EP8_FIFO_DIN   : in STD_LOGIC_VECTOR(15 downto 0);
    EP8_FIFO_WR_EN : in STD_LOGIC;
    EP8_FIFO_FULL  : out STD_LOGIC;

    TX_FIFO_DIN   : out STD_LOGIC_VECTOR(15 downto 0);
    TX_FIFO_FULL  : in STD_LOGIC;
    TX_FIFO_WR_EN : out STD_LOGIC;
	 
	 RX_LED        : out STD_LOGIC;
	 TX_LED        : out STD_LOGIC	 
  );
end COMPONENT usb_if;


COMPONENT spi is
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
end COMPONENT spi;

COMPONENT cmd_parser is
  Port (
    CLK     : in  STD_LOGIC;                  
    FW_VERSION : in  STD_LOGIC_VECTOR(7 downto 0);	
	 
    EP4_DIN   : in STD_LOGIC_VECTOR(15 downto 0);
    EP4_RD_EN : out STD_LOGIC;
    EP4_EMPTY : in STD_LOGIC;

    EP8_FIFO_DIN   : out STD_LOGIC_VECTOR(15 downto 0);
    EP8_FIFO_WR_EN : out STD_LOGIC;
    EP8_FIFO_FULL  : in STD_LOGIC;
	 
    SPI_DOUT : out STD_LOGIC_VECTOR(7 downto 0);
    SPI_DIN  : in  STD_LOGIC_VECTOR(7 downto 0);	 
    SPI_RW   : out STD_LOGIC;
    SPI_START: out STD_LOGIC;
    SPI_BUSY : in STD_LOGIC;
	 SPI_CE   : out STD_LOGIC;
	 
	 SCS_OUTPUT : out STD_LOGIC;	 
	 TX_AUX_OUT : out STD_LOGIC;
	 RX_AUX_OUT : out STD_LOGIC;
	 SERIAL_PORT_SEL : out STD_LOGIC_VECTOR(1 downto 0); 
	 MODE_SEL : out STD_LOGIC_VECTOR(1 downto 0);
	 CODEC_CLOCK_SEL : out STD_LOGIC_VECTOR(2 downto 0);
	 CODEC_RESET_OUT : out STD_LOGIC;
	 TX_FIFO_FILL : out STD_LOGIC;
	 DEBUG_OUT : out STD_LOGIC
  );
end COMPONENT cmd_parser;

COMPONENT rx_block is
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
end COMPONENT rx_block;
  
COMPONENT tx_block is
  Port (
    TX_DATA_CLOCK_IN : in STD_LOGIC;
	 CLK_IN     : in STD_LOGIC;
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
	 DEBUG_OUT1  : out STD_LOGIC;
	 DEBUG_OUT2 : out STD_LOGIC	 
  );
end COMPONENT tx_block;
  
signal system_clock : std_logic;
signal sampling_clock_x2 : STD_LOGIC;
signal sampling_clock : STD_LOGIC;
signal CLK_IF : std_logic;

signal reset : std_logic;
signal resetcnt : integer range 0 to 2**31-1;

signal txspi_start : std_logic;
signal txspi_data : std_logic_vector(7 downto 0);
signal rxspi_data : std_logic_vector(7 downto 0);
signal txspi_busy : std_logic;
signal txspi_rw : std_logic;
signal txspi_ce : std_logic;

signal ep4_dout  : STD_LOGIC_VECTOR(15 downto 0);
signal ep4_rd_en : STD_LOGIC;
signal ep4_empty : STD_LOGIC;

signal ep8_fifo_din   : STD_LOGIC_VECTOR(15 downto 0);
signal ep8_fifo_wr_en : STD_LOGIC;
signal ep8_fifo_full  : STD_LOGIC;
	 
signal scs_output : STD_LOGIC;

signal serial_port_sel : STD_LOGIC_VECTOR(1 downto 0);
signal mode_sel : STD_LOGIC_VECTOR(1 downto 0);

signal serial_cs       : STD_LOGIC;
signal serial_clock    : STD_LOGIC;
signal serial_data_in  : STD_LOGIC;
signal serial_data_out : STD_LOGIC;
signal serial_data_oe  : STD_LOGIC;

signal codec_reset_sig : STD_LOGIC;

signal codec_clock_sel : STD_LOGIC_VECTOR(2 downto 0);

signal clk_div2     : STD_LOGIC := '0';
signal clk_div4     : STD_LOGIC := '0';
signal clk_div6_cnt : integer range 0 to 3;
signal clk_div6     : STD_LOGIC := '0';
signal clk_div8_cnt : integer range 0 to 3;
signal clk_div8     : STD_LOGIC := '0';
signal clk_div12    : STD_LOGIC := '0';
signal clk_div24    : STD_LOGIC := '0';
signal clk_div48    : STD_LOGIC := '0';

signal rx_fifo_dout  : STD_LOGIC_VECTOR(15 downto 0);
signal rx_fifo_empty : STD_LOGIC;
signal rx_fifo_rd_en : STD_LOGIC;	 

signal debug_out1 : STD_LOGIC;
signal debug_out2 : STD_LOGIC;

signal tx_fifo_din   : STD_LOGIC_VECTOR(15 downto 0);
signal tx_fifo_full  : STD_LOGIC;
signal tx_fifo_wr_en : STD_LOGIC;

signal tx_led : STD_LOGIC;
signal rx_led : STD_LOGIC;

signal tx_fifo_fill : STD_LOGIC;
signal tx_enable    : STD_LOGIC;

begin

  -- system_clock = 48MHz
  system_clock <= CLK_IN;
 
  CLK_IF <= system_clock; -- clock for usb_if

  sampling_clock <= clk_div48 when codec_clock_sel(1 downto 0)="00" else
                    clk_div24 when codec_clock_sel(1 downto 0)="01" else
                    clk_div12 when codec_clock_sel(1 downto 0)="10" else						 
						  clk_div8;
				
  sampling_clock_x2 <= clk_div24 when codec_clock_sel(1 downto 0)="00" else
                       clk_div12 when codec_clock_sel(1 downto 0)="01" else
                       clk_div6 when codec_clock_sel(1 downto 0)="10" else						 
						     clk_div4;
						 
  CODEC_CLK_OUT <= sampling_clock when codec_clock_sel(2)='0' else
                   sampling_clock_x2;

  -- clock dividers
  process (system_clock) is
  begin
    if rising_edge(system_clock) then
      clk_div2 <= not clk_div2; --clk 24MHz
    end if;
  end process; 

  process (clk_div2) is
  begin
    if rising_edge(clk_div2) then
      clk_div4 <= not clk_div4; --clk 12MHz
    end if;
  end process; 
  
  process(system_clock) is
  begin
    if rising_edge(system_clock) then
      if (clk_div6_cnt = 2) then
        clk_div6 <= not clk_div6;
		  clk_div6_cnt <= 0;
		else
		  clk_div6_cnt <= clk_div6_cnt + 1;
		end if;
    end if;
  end process;
  
  process (clk_div6) is
  begin
    if rising_edge(clk_div6) then
      clk_div12 <= not clk_div12; --clk 4MHz
    end if;
  end process;  

  process (clk_div12) is
  begin
    if rising_edge(clk_div12) then
      clk_div24 <= not clk_div24; --clk 2MHz
    end if;
  end process;

  process (clk_div24) is
  begin
    if rising_edge(clk_div24) then
      clk_div48 <= not clk_div48; --clk 1MHz
    end if;
  end process;
  
  process(system_clock) is
  begin
    if rising_edge(system_clock) then
      if (clk_div8_cnt = 3) then
        clk_div8 <= not clk_div8;
		  clk_div8_cnt <= 0;
		else
		  clk_div8_cnt <= clk_div8_cnt + 1;
		end if;
    end if;
  end process;


  CODEC_RESET <= (not reset) and codec_reset_sig;

  -- generating reset on startup process   
  process(system_clock) is
  begin
    if rising_edge(system_clock) then
      if (resetcnt < 25000000) then
        resetcnt <= resetcnt + 1;
        reset <= '1';
      else
        reset <= '0';
      end if;
    end if;
  end process;


  Inst_usb_if: usb_if
    PORT MAP (
      FDATA => FD,
      FADDR => FIFOADR,
      SLRD  => SLRD,
      SLWR  => SLWR,
      FLAGD => FLAGD,
      FLAGA => FLAGA,
      FLAGB => FLAGB,
      FLAGC => FLAGC,		
      IFCLK => CLK_IF,
      SLOE  => SLOE,
      PKTEND => PKTEND,
      EP4_DOUT  => ep4_dout,
      EP4_RD_EN => ep4_rd_en,
      EP4_EMPTY => ep4_empty,
      EP8_FIFO_DIN   => ep8_fifo_din,
      EP8_FIFO_WR_EN => ep8_fifo_wr_en,
      EP8_FIFO_FULL  => ep8_fifo_full,		
		mode_sel => mode_sel,
      RX_FIFO_DOUT  => rx_fifo_dout,
      RX_FIFO_EMPTY => rx_fifo_empty,
      RX_FIFO_RD_EN => rx_fifo_rd_en,
      TX_FIFO_DIN   => tx_fifo_din,
      TX_FIFO_FULL  => tx_fifo_full,
      TX_FIFO_WR_EN => tx_fifo_wr_en,
		RX_LED => rx_led,
		TX_LED => tx_led
    );
  
  IFCLK <= CLK_IF; -- clock output for CY7C68013

  Inst_cmd_parser : cmd_parser
    PORT MAP (
      clk     => system_clock,
      fw_version => FW_VERSION,		

      ep4_din   => ep4_dout,
      ep4_rd_en => ep4_rd_en,
      ep4_empty => ep4_empty,

      EP8_FIFO_DIN   => ep8_fifo_din,
      EP8_FIFO_WR_EN => ep8_fifo_wr_en,
      EP8_FIFO_FULL  => ep8_fifo_full,
		
      spi_dout => txspi_data,
		spi_din  => rxspi_data,
      spi_rw   => txspi_rw,
      spi_start=> txspi_start,
      spi_busy => txspi_busy,
		spi_ce   => txspi_ce,
		scs_output => serial_cs,
		tx_aux_out => TX_AUX,
		rx_aux_out => open, --RX_AUX,
		serial_port_sel => serial_port_sel,
		mode_sel => mode_sel,
		CODEC_CLOCK_SEL => codec_clock_sel,
		CODEC_RESET_OUT => codec_reset_sig,
		TX_FIFO_FILL => tx_fifo_fill,
		DEBUG_OUT => open
    );
 
  
  Inst_txspi : spi
    PORT MAP (
      clk_in    => system_clock,
		CE        => txspi_ce,
      sclk      => serial_clock,
      sdata_in  => serial_data_in,
		sdata_out => serial_data_out,
		sdata_oe  => serial_data_oe,
      data_in   => txspi_data,
		data_out  => rxspi_data,
      start     => txspi_start,
      rw        => txspi_rw,
      busy      => txspi_busy
    );
  
  --http://forums.xilinx.com/t5/Synthesis/problem-of-quot-INOUT-quot-use-quot-internal-tristates-are/td-p/122342  
  TX_SCS  <= serial_cs when serial_port_sel="01" else '1';
  TX_SCLK <= serial_clock when serial_port_sel="01" else '0';
  TX_SDAT <= serial_data_out when (serial_port_sel="01" and serial_data_oe='1') else 'Z';
					
  RX_SCS  <= serial_cs when serial_port_sel="10" else '1';
  RX_AUX  <= serial_cs when serial_port_sel="00" else '1';
  RX_SCLK <= serial_clock when (serial_port_sel="10" or serial_port_sel="00") else '0';
  RX_SDAT <= serial_data_out when ((serial_port_sel="10" or serial_port_sel="00") and serial_data_oe='1') else 'Z';

  CODEC_SCS  <= serial_cs when serial_port_sel="11" else '1';
  CODEC_SCLK <= serial_clock when serial_port_sel="11" else '0';
  CODEC_SDAT <= serial_data_out when (serial_port_sel="11" and serial_data_oe='1') else 'Z';
  
  serial_data_in <= CODEC_SDAT when (serial_port_sel="11" and serial_data_oe='0') else
                    TX_SDAT    when (serial_port_sel="01" and serial_data_oe='0') else
					     RX_SDAT    when (serial_port_sel="10" and serial_data_oe='0') else
						  RX_SDAT    when (serial_port_sel="00" and serial_data_oe='0') else
                    '0';  
  
  LED_S1 <= debug_out1;
  LED_S2 <= rx_led; --mode_sel(1); serial_port_sel(1);
  LED_S3 <= tx_led; --mode_sel(0); --serial_port_sel(0);
  
  TP82 <= not reset; --debug_out1;
  TP84 <= debug_out2; -- and BUTTON_SELECT;
  
  tx_enable <= BUTTON_SELECT;
  Inst_rx_block: rx_block
    PORT MAP (
      TRXD   => TRXD,
      TRXIQ  => TRXIQ,
      TRXCLK => TRXCLK,
	   RST    => reset,
      RD_CLK => CLK_IF,
      DOUT   => rx_fifo_dout,
      EMPTY  => rx_fifo_empty,
      RD_EN  => rx_fifo_rd_en,
      DEBUG_OUT => open		
    );
	 
  Inst_tx_block : tx_block
    PORT MAP (
	   TX_DATA_CLOCK_IN => sampling_clock_x2,
		CLK_IN     => system_clock,
		CE         => tx_enable,
      TXD        => TXD,
      TXIQ	     => TXIQ,
      TXCLK	     => TXCLK,
      RST        => reset,
      TX_FIFO_FILL => tx_fifo_fill,
      WR_CLK     => CLK_IF,
      DIN        => tx_fifo_din,
      FULL       => tx_fifo_full,
      WR_EN      => tx_fifo_wr_en,
	   DEBUG_OUT1 => debug_out1,
      DEBUG_OUT2 => debug_out2
    );
	
end Behavioral;
