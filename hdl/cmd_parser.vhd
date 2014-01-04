library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity cmd_parser is
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
end cmd_parser;


architecture Behavioral of cmd_parser is

type state_type is (S0,S1,S2,S3,
                    S_SPI_WR_1, S_SPI_WR_2,
						  S_SPI_RD_1, S_SPI_RD_2, S_SPI_RD_3,
						  S_CODEC_RESET);
signal state      : state_type := s0;
signal state_next : state_type;

signal ep4din_R    : STD_LOGIC_VECTOR(15 downto 0);


signal tx_aux_out_R    : STD_LOGIC := '0';
signal tx_aux_out_next : STD_LOGIC := '0';

signal rx_aux_out_R    : STD_LOGIC := '0';
signal rx_aux_out_next : STD_LOGIC := '0';

signal scs_output_R    : STD_LOGIC := '1';
signal scs_output_next : STD_LOGIC := '1';

signal spi_ce_next     : STD_LOGIC := '0';
signal spi_rw_next     : STD_LOGIC := '0';
signal spi_dout_next   : STD_LOGIC_VECTOR(7 downto 0);
signal spi_start_next  : STD_LOGIC := '0';
signal spi_busy_R      : STD_LOGIC;

signal spi_din_R       : STD_LOGIC_VECTOR(7 downto 0);

signal serial_port_sel_R    : STD_LOGIC_VECTOR(1 downto 0) := "11"; -- default: codec serial port
signal serial_port_sel_next : STD_LOGIC_VECTOR(1 downto 0) := "11";

signal mode_sel_R    : STD_LOGIC_VECTOR(1 downto 0) := "00"; -- default codec mode
signal mode_sel_next : STD_LOGIC_VECTOR(1 downto 0) := "00";

signal codec_reset_cnt : integer;
signal codec_reset_cnt_next : integer;
signal codec_reset_out_next : STD_LOGIC;

signal codec_clock_sel_R    : STD_LOGIC_VECTOR(2 downto 0) := "001"; -- default codec clock 2MHz (48MHz/24)
signal codec_clock_sel_next : STD_LOGIC_VECTOR(2 downto 0) := "001";

signal ep4_rd_en_next : STD_LOGIC := '0';
signal ep4_empty_R : STD_LOGIC := '0';

signal ep8_fifo_wr_en_next : STD_LOGIC := '0';
signal ep8_fifo_din_next   : STD_LOGIC_VECTOR(15 downto 0) :=(others=>'1');
signal ep8_fifo_full_R     : STD_LOGIC;

signal dummy      : STD_LOGIC_VECTOR(15 downto 0) := X"0001";
signal dummy_next : STD_LOGIC_VECTOR(15 downto 0);

signal tx_fifo_fill_next : STD_LOGIC;

begin
  
  DEBUG_OUT <= EP4_EMPTY;
  
  process (CLK) is
  begin
    if falling_edge(CLK) then
      state <= state_next;
		TX_AUX_OUT   <= tx_aux_out_next;
		tx_aux_out_R <= tx_aux_out_next;
		RX_AUX_OUT   <= rx_aux_out_next;
		rx_aux_out_R <= rx_aux_out_next;
		scs_output_R <= scs_output_next;
		SCS_OUTPUT   <= scs_output_next;
		SPI_CE   <= spi_ce_next;
		SPI_RW   <= spi_rw_next;
		SERIAL_PORT_SEL <= serial_port_sel_next;
		serial_port_sel_R  <= serial_port_sel_next;
		MODE_SEL <= mode_sel_next;
		mode_sel_R <= mode_sel_next;
		codec_reset_cnt <= codec_reset_cnt_next;
      CODEC_RESET_OUT <= codec_reset_out_next;
		CODEC_CLOCK_SEL   <= codec_clock_sel_next;
		codec_clock_sel_R <= codec_clock_sel_next;
	
		EP4_RD_EN <= ep4_rd_en_next;
		ep4din_R <= EP4_DIN;

		SPI_START  <= spi_start_next;
		SPI_DOUT   <= spi_dout_next;
		spi_busy_R <= SPI_BUSY;
      spi_din_R  <= SPI_DIN;
      
      ep4_empty_R <= EP4_EMPTY;
		
      EP8_FIFO_WR_EN  <= ep8_fifo_wr_en_next;
      EP8_FIFO_DIN    <= ep8_fifo_din_next;
      ep8_fifo_full_R <= EP8_FIFO_FULL;
		
		TX_FIFO_FILL <= tx_fifo_fill_next;
		
		dummy <= dummy_next;
    end if;
  end process;
  
  
  process (state, ep4din_R, tx_aux_out_R, rx_aux_out_R, scs_output_R, ep4_empty_R,
           serial_port_sel_R, mode_sel_R, spi_busy_R, codec_reset_cnt, 
			  codec_clock_sel_R, ep8_fifo_full_R, spi_din_R, FW_VERSION, dummy) is
  begin
    spi_dout_next <= X"00";
    spi_start_next <= '0';
	 spi_ce_next <= '0';
	 spi_rw_next <= '1';

	 tx_aux_out_next <= tx_aux_out_R;
	 rx_aux_out_next <= rx_aux_out_R;
	 scs_output_next <= scs_output_R;
    serial_port_sel_next <= serial_port_sel_R;
	 mode_sel_next <= mode_sel_R;
	 codec_reset_out_next <= '1';
	 codec_reset_cnt_next <= codec_reset_cnt;
	 codec_clock_sel_next <= codec_clock_sel_R;
	 ep4_rd_en_next <= '0';
	 
	 ep8_fifo_wr_en_next <= '0';
	 ep8_fifo_din_next   <= dummy;
	 --writing dummy value is required to remove warning that latch has constant value
	 dummy_next <= dummy(14 downto 0) & dummy(15);
	 tx_fifo_fill_next <= '0';

    case state is
      when S0 =>
        if ep4_empty_R='0' then --EP4 is not empty
          state_next <= S1;
        else		  
          state_next <= S0;
        end if;

      when S1 =>
		  ep4_rd_en_next <= '1';
        state_next <= S2;

      when S2 =>
		  --pominiecie tego stanu spowodowalo, ze w stanie S3 korzystal z poprzednio wyslanej danej a nie tej pobranej z fifo
		  --zatrzasniecie ep4din_R
        state_next <= S3;

      when S3 =>
	     if ep4din_R(15 downto 8)=X"80" then -- spi transmit
		    spi_dout_next <= ep4din_R(7 downto 0);
          spi_start_next <= '1';
			 spi_ce_next <= '1';
  	 	    spi_rw_next <= '0';
          state_next <= S_SPI_WR_1; -- send data over spi
	     elsif ep4din_R(15 downto 8)=X"81" then -- spi receive
          spi_start_next <= '1';
			 spi_ce_next <= '1';
  	 	    spi_rw_next <= '1';
          state_next <= S_SPI_RD_1;
        elsif ep4din_R(15 downto 8)=X"10" then -- scs control
          scs_output_next <= ep4din_R(0);
          state_next <= S0;
        elsif ep4din_R(15 downto 8)=X"20" then -- serial port select
          serial_port_sel_next <= ep4din_R(1 downto 0);
			 scs_output_next <= '1';
          state_next <= S0;
        elsif ep4din_R(15 downto 8)=X"30" then -- mode select
          mode_sel_next <= ep4din_R(1 downto 0);
          state_next <= S0;
        elsif ep4din_R(15 downto 8)=X"31" then -- mode select read
		    if ep8_fifo_full_R='0' then --drop data if ep8 fifo is full
            ep8_fifo_wr_en_next <= '1';
			   ep8_fifo_din_next   <= X"310" & "00" & mode_sel_R;
			 end if;
          state_next <= S0;
        elsif ep4din_R(15 downto 8)=X"01" then -- get fw version
		    if ep8_fifo_full_R='0' then --drop data if ep8 fifo is full
            ep8_fifo_wr_en_next <= '1';
			   ep8_fifo_din_next   <= X"01" & FW_VERSION;
			 end if;
          state_next <= S0;
        elsif ep4din_R(15 downto 8)=X"40" then -- aux control
          tx_aux_out_next <= ep4din_R(0);
          rx_aux_out_next <= ep4din_R(1);
          state_next <= S0;
        elsif ep4din_R(15 downto 8)=X"41" then -- aux control read
		    if ep8_fifo_full_R='0' then --drop data if ep8 fifo is full
            ep8_fifo_wr_en_next <= '1';
				ep8_fifo_din_next(15 downto 8) <= X"41";
				ep8_fifo_din_next(7 downto 2)  <= (others=>'1');
			   ep8_fifo_din_next(1)           <= tx_aux_out_R;
			   ep8_fifo_din_next(0)           <= tx_aux_out_R;
			 end if;		  
          state_next <= S0;
        elsif ep4din_R(15 downto 8)=X"50" then -- codec reset 100ms pulse
          codec_reset_cnt_next <= 0;
          state_next <= S_CODEC_RESET;
        elsif ep4din_R(15 downto 8)=X"60" then -- codec clock select
          codec_clock_sel_next(1 downto 0) <= ep4din_R(1 downto 0);
          codec_clock_sel_next(2) <= ep4din_R(4); --
          state_next <= S0;
        elsif ep4din_R(15 downto 8)=X"61" then -- codec clock read
		    if ep8_fifo_full_R='0' then --drop data if ep8 fifo is full
            ep8_fifo_wr_en_next <= '1';
				ep8_fifo_din_next(15 downto 8) <= X"61";
				ep8_fifo_din_next(7 downto 4)  <= "000" & codec_clock_sel_R(2);
			   ep8_fifo_din_next(3 downto 0)  <= "00"  & codec_clock_sel_R(1 downto 0);
			 end if;
          state_next <= S0;
        elsif ep4din_R(15 downto 8)=X"70" then -- tx fifo fill
          tx_fifo_fill_next <= '1';
          state_next <= S0;
		  else
          state_next <= S0;
        end if;

      when S_SPI_WR_1 =>
 		  spi_ce_next <= '1';
        spi_rw_next <= '0';
        spi_start_next <= '1'; -- added just for sure that spi_module receives start condition
		  if spi_busy_R='0' then -- wait for ack (busy=='1') from spi_module
          state_next <= S_SPI_WR_1;
		  else
          state_next <= S_SPI_WR_2;
		  end if;
		  	  
      when S_SPI_WR_2 =>  
        if spi_busy_R='1' then -- wait for the end of spi transmission
          spi_ce_next <= '1';
		 	 spi_rw_next <= '0';
          state_next <= S_SPI_WR_2;
        else
          state_next <= S0;
        end if;

      when S_SPI_RD_1 =>
 		  spi_ce_next <= '1';
        spi_rw_next <= '1';
        spi_start_next <= '1'; -- added just for sure that spi_module receives start condition
		  if spi_busy_R='0' then -- wait for ack (busy=='1') from spi_module
          state_next <= S_SPI_RD_1;
		  else
          state_next <= S_SPI_RD_2;
		  end if;
		  	  
      when S_SPI_RD_2 =>  
        if spi_busy_R='1' then -- wait for the end of spi transmission
          spi_ce_next <= '1';
		 	 spi_rw_next <= '1';
          state_next <= S_SPI_RD_2;
        else
          state_next <= S_SPI_RD_3;
        end if;

      when S_SPI_RD_3 => 
        ep8_fifo_wr_en_next <= '1';
        ep8_fifo_din_next <= X"81" & spi_din_R;
		  state_next <= S0;
		
		  
		when S_CODEC_RESET =>
		  if (codec_reset_cnt < 3200000) then -- 65ms pulse
		    codec_reset_out_next <= '0';
			 codec_reset_cnt_next <= codec_reset_cnt + 1;
			 state_next <= S_CODEC_RESET;
		  else
		    state_next <= S0;
		  end if;

      when others =>
        state_next <= S0;

    end case;
  end process;

end Behavioral;

