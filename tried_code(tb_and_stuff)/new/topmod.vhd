LIBRARY IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.functions.all;
use IEEE.NUMERIC_STD.ALL;

ENTITY top is
port(
start_bot : in std_logic;
goal_reached :out std_logic;
shortpath_done :out std_logic;
clka       : in STD_LOGIC;
led_out   : out STD_LOGIC;
uart_rx_pin   : in STD_LOGIC;
uart_tx_pin   : out STD_LOGIC;
state_led         : out STD_LOGIC_VECTOR(6 downto 0);
shortpathdone_beforetx :out std_logic

);      
         

        
END top;

ARCHITECTURE Behavioral OF top IS

    type state_type is (IDLE, WRITE_CELL, PRE_WRITE_CELL, START_FLOODFILL, WAIT_FLOODFILL, short_path,WALL_UPDATES);
    signal state : state_type := IDLE;
    signal cell_index_x : integer range 0 to 6 := 0;--6 to solve 5,5 issue
    signal cell_index_y : integer range 0 to 6 := 0;
     signal c_y : integer range 0 to 6 := 0;
      signal c_x : integer range 0 to 6 := 0;
       signal next_y : integer range 0 to 6 := 0;
      signal next_x : integer range 0 to 6 := 0;
    signal init_done : std_logic := '0';
    signal init_start : std_logic := '1';
      signal sent : std_logic := '1';
    signal walls : std_logic_vector(3 downto 0) := "0000";
    
	CONSTANT initialpos_x : INTEGER := 0;
    CONSTANT initialpos_y : INTEGER := 0;
	CONSTANT init_came_from : INTEGER := 0;
	
    
    --   for Flood Fill
     
    SIGNAL clkb  : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '0';
    SIGNAL start : STD_LOGIC := '0';
    SIGNAL start_ff : STD_LOGIC := '0';
    SIGNAL done  : STD_LOGIC := '0';

    CONSTANT goal_x : INTEGER := 2;
    CONSTANT goal_y : INTEGER := 2;
    ---
     SIGNAL wea_wu: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"; 
       SIGNAL done_wu : STD_LOGIC := '0';
    --  ff bram signals
    SIGNAL ena_ff,  enb_ff : STD_LOGIC;
    SIGNAL wea_ff: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"; 
    SIGNAL addra_ff, addrb_ff : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL dina_ff : STD_LOGIC_VECTOR(15 DOWNTO 0);
     -- user bram signals
     
    SIGNAL ena_user,  enb_user : STD_LOGIC;
     SIGNAL wea_user: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"; 
    SIGNAL addra_user, addrb_user : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL dina_user : STD_LOGIC_VECTOR(15 DOWNTO 0);
    
    -- shortPATH SIGNALS
    SIGNAL start_sp : STD_LOGIC := '0';
    SIGNAL addrb_sp : STD_LOGIC_VECTOR(5 DOWNTO 0);
      SIGNAL directions : STD_LOGIC_VECTOR(7 DOWNTO 0);
      SIGNAL tx_ready : STD_LOGIC := '0';
      SIGNAL reached_goal: STD_LOGIC := '0';
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
--wu
SIGNAL addra_wu : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL addrb_wu : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL dina_wu : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL ena_wu,  enb_wu : STD_LOGIC;

--uart tx
    
    -- UART Parameters
    constant BAUD_RATE  : integer := 115200;
    constant CLK_FREQ   : integer := 100000000;  -- 100 MHz clock
    constant BIT_PERIOD : integer := CLK_FREQ / BAUD_RATE;
    
    -- Signal Registers
    signal clk_counter_tx : integer range 0 to BIT_PERIOD := 0;
    signal bit_index_tx   : integer range 0 to 7 := 0;
    signal tx_shift_reg   : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');  
    signal led_state      : STD_LOGIC := '0';
    signal tx_active      : STD_LOGIC := '0';
    signal sent_signal    : STD_LOGIC := '0';
    signal tx_ready_prev  : STD_LOGIC := '0';
    signal tx_ready_edge  : STD_LOGIC := '0';

    
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
    component ShortestPathProcessor 
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

        -- Outputs
        directions : OUT std_logic_vector (7 downto 0):="00000000" ;
         
        reached_goal: OUT STD_LOGIC;
        tx_ready :OUT STD_LOGIC:='0'
    );
END component;
    
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

component Wall_Update is
    Port (
        clk        : in STD_LOGIC;
        reset      : in STD_LOGIC;
        start_sp   : in STD_LOGIC;
        done_wu   : out STD_LOGIC;
        directions : in STD_LOGIC_VECTOR(7 downto 0);
        tx_ready   : in STD_LOGIC;
        uart_rx    : in STD_LOGIC;
        ena, enb   : out STD_LOGIC;
        addrb      : out STD_LOGIC_VECTOR(5 downto 0);
        addra      : out STD_LOGIC_VECTOR(5 downto 0);
        dina       : out STD_LOGIC_VECTOR(15 downto 0);
        doutb      : in STD_LOGIC_VECTOR(15 downto 0);
        current_x, current_y : in INTEGER range 0 to 5;
        next_x, next_y : out INTEGER range 0 to 5;
        goal_x, goal_y :in INTEGER range 0 to 5
    
    );
end component;

component uart_tx 
port(clk       : in STD_LOGIC;
        tx_ready  : in STD_LOGIC;
        tx_data   : in STD_LOGIC_VECTOR(7 downto 0);
        uart_tx   : out STD_LOGIC;
        led_output: out STD_LOGIC;
        sent      : out STD_LOGIC
    );
end component;

    
BEGIN
    -- Instantiate FloodFill
    FF: FloodFill
    PORT MAP (
        clk     => clkb,
        reset   => reset, 
        start   => start_ff,
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
    U_ShortestPathProcessor : ShortestPathProcessor
    PORT MAP (
        clk         => clkb,
        reset       => reset,
        start_sp    => done,
        current_x   => c_x,
        current_y   => c_y,
        came_from   => init_came_from,
        goal_x      => goal_x,
        goal_y      => goal_y,
        sent        => sent,
        doutb       => doutb,
        addrb       => addrb_sp,
        enb         => enb_sp,
        directions  => directions,
        reached_goal => reached_goal,
        tx_ready    => tx_ready
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
d1:wall_update
port map(
clk=>clkb,
reset=>reset,
start_sp=>start_sp,
done_wu=>done_wu,
directions=> directions,
tx_ready=>tx_ready,
uart_rx=>uart_rx_pin,
ena   => ena_wu,
 
addra => addra_wu,
addrb => addrb_wu,
dina  => dina_wu,
 doutb => doutb,        
enb   => enb_wu,
current_x=> c_x,
current_y=> c_y,
next_x=> next_x,
next_y=> next_y,
goal_x => goal_x,
goal_y => goal_y
);
    
D: uart_tx
    PORT MAP (
        clk  => clka,
tx_ready=>tx_ready,
tx_data=>directions,
uart_tx=>uart_tx_pin,
led_output=>led_out,
sent=>sent);
    

    -- Clock Process
    -- Clock Generation (FloodFill runs at half BRAM speed)
    process (clka)
    begin
      if rising_edge(clka) then 
  
        clkb <= not clkb;

      end if;

    end process;

   

    -- Write and Read Process
    

-- Process for Initializing BRAM Walls and Running Flood Fill
process (clka,clkb)
begin
init_start<=start_bot;
    if rising_edge(clkb) then
     
        case state is
            when IDLE =>
                if init_start = '1' then  -- Start signal for initialization
                    cell_index_x <= initialpos_x;
                    cell_index_y <= initialpos_y;
                    --goal_x <= 2;
                    --goal_y <=2;
                    init_done <= '0';
                    walls <= "0000";
                    report "in idle";
                    state <= PRE_WRITE_CELL;
                    ena_user <='0';
                end if;
-- wall updating defaualt walls 
            when PRE_WRITE_CELL=>
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
                 
                state <= WRITE_CELL;
                
            when WRITE_CELL =>
                -- Calculate (x, y) from cell index
               
                
                 ena_user  <= '1';
                wea_user  <= "11";
                addra_user <= std_logic_vector(to_unsigned(6*cell_index_y+cell_index_x, 6));
                dina_user <= walls & "0000" & x"FF"; 

                -- Set outer walls
                -- Walls + Empty path + Flood Value = 255

                -- Move to next cell
                 
                    if cell_index_x < 5 then
                        cell_index_x <= cell_index_x + 1;
                                            state <= PRE_WRITE_CELL;
                                              walls <= "0000";
                    elsif (cell_index_x = 5) and (cell_index_y < 5) then
                        cell_index_y <= cell_index_y +1;
                        cell_index_x <=0;
                                            state <= PRE_WRITE_CELL;
                                              walls <= "0000";
                                              
                    elsif (cell_index_x = 5) and (cell_index_y = 5) then state <= WRITE_CELL; cell_index_y <= cell_index_y +1; 
                else
                     state <= START_FLOODFILL;
init_done<='1';
                end if;
 
            when START_FLOODFILL =>
                start_ff <= init_done; -- Start Flood Fill Module
                state <= WAIT_FLOODFILL;
report "starting algo";
            when WAIT_FLOODFILL =>
            
                if done = '1' then
                    start_ff <= '0';
                    cell_index_x <= 0; 
                    cell_index_y <= 0; -- Reset index for BRAM reading
                    state <= short_path;

                 else 
                    state <= WAIT_FLOODFILL;
                    start_ff <= '1';
                end if;

            when short_path =>
            
            start_sp <= '1';
            if reached_goal = '1' then state <= wall_updates;
            shortpath_done<='1'; 
            end if;

            
            	
                 
 

when wall_updates =>

 if done_wu= '1' then  
 
state<=start_floodfill;
init_done<='0';
 








else
state<=wall_updates;
end if;
 end case;
       
    end if;
end process;
    process(state)
    begin
        -- Default: all LEDs OFF
        state_led <= "0000000";

        case state is
            when IDLE            => state_led <= "0000001"; -- LED 0 ON
            when WRITE_CELL      => state_led <= "0000010"; -- LED 1 ON
            when PRE_WRITE_CELL  => state_led <= "0000100"; -- LED 2 ON
            when START_FLOODFILL => state_led <= "0001000"; -- LED 3 ON
            when WAIT_FLOODFILL  => state_led <= "0010000"; -- LED 4 ON
            when SHORT_PATH      => state_led <= "0100000"; -- LED 5 ON
            when WALL_UPDATES    => state_led <= "1000000"; -- LED 6 ON
        end case;
    end process;


-- Control logic
ena <= ena_ff when (state = START_FLOODFILL or state = WAIT_FLOODFILL) 
       else ena_wu when (state = WALL_UPDATES) 
       else ena_user;
wea  <= wea_ff  when (state = START_FLOODFILL or state = WAIT_FLOODFILL) else wea_wu when (state = WALL_UPDATES) 
       else wea_wu;
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
shortpathdone_beforetx<=tx_ready;

END Behavioral;