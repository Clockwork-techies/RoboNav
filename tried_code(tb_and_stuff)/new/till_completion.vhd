----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 25.03.2025 14:54:18
-- Design Name: 
-- Module Name: implementable_till_sp - Implemnetable
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity last_top is
port (switch : in std_logic;
     
    clka :in std_logic;
    reached_goal : out std_logic;
    tx : out std_logic ;
    rx : in std_logic ; 
   rx_check:out std_logic_vector(3 downto 0);
   four_bits:out std_logic_vector(3 downto 0);
    seg  : out STD_LOGIC_VECTOR (6 downto 0); -- Segments a-g
        an   : out STD_LOGIC_VECTOR (3 downto 0);  -- Anodes
    bram_led: out std_logic_vector(3 downto 0)
 
   );
end last_top;

architecture top of last_top is
SIGNAL for_bits: std_logic_vector(3 downto 0);
 SIGNAL  done_c_sig :  std_logic;
   SIGNAL start_sp_out:  std_logic:='0';
SIGNAL  sp_done :  std_logic;
     SIGNAL led_o :  std_logic;
    signal state_id : std_logic_vector(3 downto 0) := "0000";
    type state_type is (IDLE, WRITE_CELL, PRE_WRITE_CELL, START_FLOODFILL, WAIT_FLOODFILL,read_bram, SHORT_PATH,UART_NW,TEMPO,wall_updates, DONE_C);
       signal state : state_type := IDLE;
    signal cell_index_x : integer range 0 to 6 := 0;--6 to solve 5,5 issue
    signal cell_index_y : integer range 0 to 6 := 0;
    signal init_done : std_logic := '0';
    signal init_start : std_logic := '1';
    signal walls : std_logic_vector(3 downto 0) := "0000";
    
    --   for Flood Fill
    
    SIGNAL clkb  : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '0';
    SIGNAL start : STD_LOGIC := '0';
    SIGNAL done  : STD_LOGIC := '0';
    constant goal_x, goal_y : integer := 2;
    
    --  ff bram signals
    SIGNAL ena_ff,  enb_ff : STD_LOGIC;
    SIGNAL wea_ff: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"; 
    SIGNAL addra_ff, addrb_ff : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL dina_ff : STD_LOGIC_VECTOR(15 DOWNTO 0):= "0000000000000000";
    -- wall update signals
    SIGNAL ena_wu,  enb_wu : STD_LOGIC;
    SIGNAL wea_wu: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"; 
    SIGNAL addra_wu, addrb_wu : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL dina_wu : STD_LOGIC_VECTOR(15 DOWNTO 0):= "0000000000000000";
    SIGNAL done_wu : STD_LOGIC := '0';
     -- user bram signals
    SIGNAL done_c_sig_in : STD_LOGIC := '0';
    
    SIGNAL ena_user,  enb_user : STD_LOGIC;
     SIGNAL wea_user: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"; 
    SIGNAL addra_user, addrb_user : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL dina_user : STD_LOGIC_VECTOR(15 DOWNTO 0);
    
    -- shortPATH SIGNALS
    SIGNAL start_sp : STD_LOGIC := '0';
    SIGNAL addrb_sp : STD_LOGIC_VECTOR(5 DOWNTO 0);
      SIGNAL directions : STD_LOGIC_VECTOR(15 DOWNTO 0);
      SIGNAL tx_ready : STD_LOGIC := '0';
     SIGNAL trigger : STD_LOGIC;
    SIGNAL enb_sp : STD_LOGIC;
    
    --  signals to BRAM
    SIGNAL ena, enb : STD_LOGIC;
    SIGNAL wea : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL addra, addrb : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL dina : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL doutb : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL temp : STD_LOGIC_VECTOR(15 DOWNTO 0);
    -- Clock Period
    CONSTANT CLK_PERIOD : TIME := 10 ns;
     signal router   :  STD_LOGIC:='0';
    signal reached_goal_in : STD_LOGIC;
   signal rch_goal_copy :std_logic:='0';
    signal nw_ena   :  STD_LOGIC:='0';
    signal nw_wea   :  STD_LOGIC_VECTOR(1 DOWNTO 0):="00";
    signal nw_addra : STD_LOGIC_VECTOR(5 DOWNTO 0):="000000";
    
    signal nw_enb   :  STD_LOGIC:='0';
    signal nw_addrb :  STD_LOGIC_VECTOR(5 DOWNTO 0):="000000";
   signal nw_doutb : STD_LOGIC_VECTOR(15 DOWNTO 0):="0000000000000000";
   
   signal counter : integer := 0;
   
 signal  c_x, c_y : INTEGER range 0 to 5:=0;
constant init_x  : INTEGER :=0;
constant init_y : INTEGER :=0;
signal destination_reached : STD_LOGIC := '0';
signal next_x, next_y: integer range 0 to 5:=0;

   
    -- DUT Component Declaration
    COMPONENT blk_mem_gen_0
        PORT (
            clka  : IN  STD_LOGIC;
            ena   : IN  STD_LOGIC;
            wea   : IN  STD_LOGIC_VECTOR(1 DOWNTO 0);
            addra : IN  STD_LOGIC_VECTOR(5 DOWNTO 0);
            dina  : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
            clkb  : IN  STD_LOGIC;
            enb   : IN  STD_LOGIC;
            addrb : IN  STD_LOGIC_VECTOR(5 DOWNTO 0);
            doutb : OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
     
            
        );
    END COMPONENT;
    
    component DisplayTwoDigits_Int 
    Port (
        clk   : in  STD_LOGIC;          -- 100 MHz clock
        num1  : in  INTEGER range 0 to 6; -- First digit (rightmost)
        num2  : in  INTEGER range 0 to 6; -- Second digit (next left)
        seg   : out STD_LOGIC_VECTOR(6 downto 0); -- Segments a-g
        an    : out STD_LOGIC_VECTOR(3 downto 0)  -- Anodes
    );
end component;

    component NEW_UART_TX 
        Port (
            clk       : in STD_LOGIC;
            uart_tx   : out STD_LOGIC;
            led_output: out STD_LOGIC;
            nw_enb       : out STD_LOGIC;
            trigger   : in STD_LOGIC;
            nw_addrb_out  : out STD_LOGIC_VECTOR(5 downto 0);
            done_c_sig: out STD_LOGIC;
            nw_doutb_in  : in STD_LOGIC_VECTOR(15 downto 0) --- sliced
        );
    end component;

    component ShortestPathProcessors 
    PORT (
        clk         : IN  STD_LOGIC;
        reset       : IN  STD_LOGIC;
        start_sp       : IN  STD_LOGIC;
        current_x   : IN INTEGER RANGE 0 TO 5;
        current_y   : IN INTEGER RANGE 0 TO 5;
        came_from   : IN INTEGER RANGE 0 TO 3;  -- (0=N,1=E3=S,2=W)
        goal_x      : IN  INTEGER RANGE 0 TO 5;
        goal_y      : IN  INTEGER RANGE 0 TO 5;
        sent         : IN std_logic;
        -- BRAM Interface
        doutb       : IN  STD_LOGIC_VECTOR(15 DOWNTO 0);
        addrb       : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
        enb         : OUT STD_LOGIC;
         nw_ena   : out  STD_LOGIC;
            nw_wea   : out  STD_LOGIC_VECTOR(1 DOWNTO 0);
            nw_addr_abram :out  STD_LOGIC_VECTOR(5 DOWNTO 0);
            

        -- Outputs
        directions : OUT std_logic_vector (15 downto 0):="0000000000000000" ;
         
        reached_goal: OUT STD_LOGIC:='0';
        tx_ready :OUT STD_LOGIC:='0'
        
        
    );
END component;
    
    component Wall_Update is
    Port (
        clk        : in STD_LOGIC;
        reset      : in STD_LOGIC; 
        start_sp   : in STD_LOGIC;
        done_wu   : out STD_LOGIC;
        directions : in STD_LOGIC_VECTOR(15 downto 0); -- changed to 16 bits
        tx_ready   : in STD_LOGIC;
        uart_rx    : in STD_LOGIC;
        ena, enb   : out STD_LOGIC;
        wea        : out STD_LOGIC_VECTOR(1 downto 0); 
        addrb      : out STD_LOGIC_VECTOR(5 downto 0);
        addra      : out STD_LOGIC_VECTOR(5 downto 0);
        dina       : out STD_LOGIC_VECTOR(15 downto 0);
        doutb      : in STD_LOGIC_VECTOR(15 downto 0);
        current_x, current_y : in INTEGER range 0 to 5;
        destination_reached : out STD_LOGIC := '0';
        next_x, next_y : out INTEGER range 0 to 5;
        rx_check:out std_logic_vector(3 downto 0):= "0000";
        
        goal_x, goal_y       : in INTEGER range 0 to 5
    );
end component;
    
    COMPONENT FloodFill
        PORT (
            clk     : IN  STD_LOGIC;
            reset   : IN  STD_LOGIC;
            start   : IN STD_LOGIC;
            goal_x, goal_y : IN INTEGER RANGE 0 TO 5;
            doutb   : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            addrb   : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
            addra   : OUT STD_LOGIC_VECTOR(5 DOWNTO 0);
            dina    : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
            ena     : OUT STD_LOGIC;
            wea     : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            enb     : OUT STD_LOGIC;
            
            done    : OUT STD_LOGIC
        );
    END COMPONENT;
    
BEGIN
    -- Instantiate FloodFill
    FF: FloodFill
    PORT MAP (
        clk     => clkb,
        reset   => reset, 
        start   => start,
        goal_x  => goal_x,
        goal_y  => goal_y,
        doutb   => doutb,
        ena     => ena_ff,
        wea     => wea_ff,
        addra   => addra_ff,
        dina    => dina_ff,
        enb     => enb_ff,
        addrb   => addrb_ff,
       
        done    => done
    );
    U_ShortestPathProcessor : ShortestPathProcessors
    PORT MAP (
        clk         => clkb,
        reset       => reset,
        start_sp    => start_sp,
        current_x   => c_x,
        current_y   => c_y,
        came_from   => 0, -------------- have to add an op in wu
        goal_x      => goal_x,
        goal_y      => goal_y,
        sent        => '1' ,
        doutb       => doutb,
        addrb       => addrb_sp,
        enb         => enb_sp,
        directions  => directions,
        reached_goal => reached_goal_in,
        tx_ready    => tx_ready,
        nw_addr_abram =>nw_addra,
        nw_ena=>nw_ena,
        nw_wea=>nw_wea
    );
    -- Instantiate BRAM
    DUT: blk_mem_gen_0
    PORT MAP (
        clka  => clka,
        ena   => ena,
        wea   => wea,
        addra => addra,
        dina  => dina,
        clkb  => clka,
        enb   => enb,
        addrb => addrb,
        doutb => doutb
    );
    
    U1:  DisplayTwoDigits_Int
        port map (
            clk  => clka,
            num1 => c_x,
            num2 => c_y,
            seg  => seg,
            an   => an
        );
    
    DUT1:blk_mem_gen_0
    PORT MAP (
        clka  => clka,
ena   => nw_ena, 
wea   => nw_wea, 
addra => nw_addra,
dina  => directions,
clkb  => clka,
enb   => nw_enb, 
addrb => nw_addrb,
doutb => nw_doutb
    ); 
    
    
    
    wall_updatedut : Wall_Update
port map (
  
    clk        => clkb,        
    reset      => reset,        
   
    start_sp   => start_sp,       
    done_wu    => done_wu  ,        
    
    directions => directions,   
    
    tx_ready   => tx_ready,    
    uart_rx    => rx,     
    rx_check=>rx_check,
    -- BRAM Interface
    ena        => ena_wu,    -- BRAM port A enable
    enb        => enb_wu,    -- BRAM port B enable
    wea        => wea_wu,    -- BRAM port A write enable (2-bit)
    addra      =>   addra_wu,  -- BRAM port A address (6-bit)
    addrb      =>  addrb_wu,  -- BRAM port B address (6-bit)
    dina       =>  dina_wu,   -- BRAM port A data in (16-bit)
    doutb      =>  doutb ,  -- BRAM port B data out (16-bit)
    
    
    destination_reached=>destination_reached ,
     
    current_x  => c_x,     
    current_y  =>c_y,     
    next_x     =>next_x,        
    next_y     =>next_y,       
    goal_x     => goal_x,       
    goal_y     => goal_y     
);
    
    
    TX1: NEW_UART_TX
    PORT MAP (
        clk       => clka,
        uart_tx   => tx,
        led_output=> led_o,
        nw_enb       => nw_enb,
        trigger   => trigger,
        nw_addrb_out  => nw_addrb,
        done_c_sig => done_c_sig_in,
        nw_doutb_in  => nw_doutb
    );
    
    -- Clock Process
    -- Clock Generation (FloodFill runs at half BRAM speed)
    
 
process(clka)
begin
    if falling_edge(clka) then 
    reached_goal <= reached_goal_in;
     done_c_sig  <=  done_c_sig_in;
     start_sp_out <= start_sp; -- Now toggles on falling edge
        if counter = 1 then  -- Divide by 2
            clkb <= not clkb;
            counter <= 0;
        else
            counter <= counter + 1;
        end if;
    end if;
end process;
  

    -- BRAM Clock (Twice the speed of FloodFill clock)
    
rch_goal_copy<=reached_goal_in;
 
 
-- Process for Initializing BRAM Walls and Running Flood Fill
process (clkb )
begin
    if rising_edge(clkb) then 
     
        case state is
            when IDLE =>
             c_x<=init_x;
             c_y<=init_y;
             four_bits <= "0000";
                bram_led <= "0001";
                cell_index_x <= 0;
                    cell_index_y <= 0;
                  router <='0';
                        trigger <= '0';
                          sp_done <= '0';
                          ena_user <= '0';
                          enb_user <= '0';
                          wea_user <= "00";
                          addrb_user <= "000000";
                          addra_user <= "000000";
                    init_done <= '0';
                    walls <= "0000";
                    bram_led <= "0000";
                if switch = '1' then  -- Start signal for initialization
                    addrb_user <= "000000";
                    walls <= "0000";
                    report "in idle";
                    state <= WRITE_CELL;
                    
                end if;
            when WRITE_CELL=>
            addrb_user <= "000000";
            bram_led <= "0010";
            enb_user <= '0';
                if cell_index_y = 0 then
                    walls(3) <= '1';  -- North wall
                elsif cell_index_y = 5 then
                    walls(0) <= '1';  -- South wall
                end if;
                if cell_index_x = 0 then
                    walls(1) <= '1';  -- West wall
                elsif cell_index_x = 5 then
                    walls(2) <= '1';  -- East wall
                end if;

                -- Write to BRAM
                 
                state <= PRE_WRITE_CELL;
                
            when PRE_WRITE_CELL =>
            bram_led <= "0011";
                -- Calculate (x, y) from cell index
               
                enb_user <= '0';
                 ena_user  <= '1';
                 
                 if router = '0' then 
                wea_user  <= "11";
                else wea_user <= "01";
                end if;
                addra_user <= std_logic_vector(to_unsigned(6*cell_index_y+cell_index_x, 6));
                dina_user <= walls & "0000" & x"FF"; 

                -- Set outer walls
                -- Walls + Empty path + Flood Value = 255

                -- Move to next cell
                 
                     if cell_index_x < 5 then  
        cell_index_x <= cell_index_x + 1;  
        state <= WRITE_CELL;  
        walls <= "0000";  

    elsif cell_index_y < 5 then  
        -- Move to the next row  
        cell_index_y <= cell_index_y + 1;  
        cell_index_x <= 0;  
        state <= WRITE_CELL;  
        walls <= "0000";  

    else  
        -- All cells processed, move to next state  
        state <=START_FLOODFILL ;  
    end if;  
 
            when START_FLOODFILL =>
              bram_led <= "0100";
                start <= '1';
                cell_index_x <= 0; 
                    cell_index_y <= 0; -- Start Flood Fill Module
                state <= WAIT_FLOODFILL;
report "starting algo";
            when WAIT_FLOODFILL =>
              bram_led <= "0101";
                if done = '1' then
                    start <= '0';
                    enb_user<= '1';
                    addrb_user <= std_logic_vector(to_unsigned(cell_index_x + 6 * cell_index_y, 6)); -- Reset index for BRAM reading
                    state <=read_bram; 
                 else 
                    state <=WAIT_FLOODFILL;
                  
                end if;
            
            when read_bram=>
            bram_led <= "0110"; 
            ena_user <= '0';
            wea_user <= "00";
             enb_user  <= '1';  
    addrb_user <= std_logic_vector(to_unsigned(cell_index_x + 6 * cell_index_y, 6));

    -- Print BRAM Value
    report "BRAM[" & integer'image(cell_index_x) & "," & integer'image(cell_index_y) & "] = " 
       & integer'image(to_integer(unsigned(doutb(7 downto 0))));

     if cell_index_x = c_x+1 and cell_index_y = c_y then
            four_bits <= doutb(3 downto 0); end if;
    -- Move to next cell
    if cell_index_x < 5 then
        cell_index_x <= cell_index_x + 1;
    elsif (cell_index_x = 5) and (cell_index_y < 5) then
        cell_index_y <= cell_index_y + 1;
        cell_index_x <= 0;
    else
        state <= SHORT_PATH;  -- All cells read, transition to DONE state
        start_sp <= '1';
    end if;
            
            when SHORT_PATH=>
            bram_led <= "0111"; 
          
            if reached_goal_in = '1' then 
            state <= UART_NW; 
            sp_done <= '1';
            start_sp<='0';
            elsif tx_ready <= '1' then  
             start_sp <= '0';
             end if;

           
            when UART_NW =>
            bram_led <= "1000"; 
            
               trigger <= '1';
               state <= TEMPO;
               report"trig on";
            when TEMPO=>
           bram_led <= "1001"; 
           trigger <= '0';
            if done_c_sig_in = '1' then
            
            report "trig off";
             state <= wall_updates; end if;
             
             when wall_updates=>
               ena_user <= '0';
            enb_user <= '0';
            sp_done<='0';
              bram_led <= "1010";
             if destination_reached='1'then
             state<=done_c;
             elsif done_wu='1'then
             state<=WRITE_CELL;
             c_x<=next_x;
             c_y<=next_y; 
             router <= '1';
             cell_index_x <= 0;
             cell_index_y <= 0;
             end if;
       
            when DONE_C =>
            bram_led <= "1011"; 
            report "done";
             
                init_done <= '1';  -- Signal that initialization is complete
                state <= DONE_C; 
                    -- Ready for next initialization
        
        when others =>state <=  IDLE;
        end case;
    end if;
end process;

 
--this is multiple assignment
ena <= ena_ff when (state = START_FLOODFILL or state = WAIT_FLOODFILL) 
       else ena_wu when (state = WALL_UPDATES) 
       else ena_user;
wea  <= wea_ff  when (state = START_FLOODFILL or state = WAIT_FLOODFILL) else wea_wu when (state = WALL_UPDATES) 
       else wea_user;
addra <= addra_ff when (state = START_FLOODFILL or state = WAIT_FLOODFILL)  else addra_wu when (state = WALL_UPDATES) 
       else addra_user;
dina  <= dina_ff when (state = START_FLOODFILL or state = WAIT_FLOODFILL)  else dina_wu when (state = WALL_UPDATES) 
       else dina_user;

enb  <= enb_ff  when (state = START_FLOODFILL or state = WAIT_FLOODFILL) else 
       enb_sp  when (state = SHORT_PATH) else enb_wu when (state = WALL_UPDATES) 
       else enb_user;

addrb <= addrb_ff when (state = START_FLOODFILL or state = WAIT_FLOODFILL) else 
         addrb_sp when (state = SHORT_PATH) else addrb_wu when (state = WALL_UPDATES) 
       else addrb_user;

end top;
