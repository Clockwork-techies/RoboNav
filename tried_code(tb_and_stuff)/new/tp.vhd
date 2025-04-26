LIBRARY IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.functions.all;
use IEEE.NUMERIC_STD.ALL;

ENTITY BRAM_Testbench IS
END BRAM_Testbench;

ARCHITECTURE Behavioral OF BRAM_Testbench IS

    type state_type is (IDLE, WRITE_CELL, PRE_WRITE_CELL, START_FLOODFILL, WAIT_FLOODFILL, READ_BRAM, DONE_C);
    signal state : state_type := IDLE;
    signal cell_index_x : integer range 0 to 6 := 0;--6 to solve 5,5 issue
    signal cell_index_y : integer range 0 to 6 := 0;
    signal init_done : std_logic := '0';
    signal init_start : std_logic := '1';
    signal walls : std_logic_vector(3 downto 0) := "0000";
    
    -- Control Signals for Flood Fill
    SIGNAL clka  : STD_LOGIC := '0';
    SIGNAL clkb  : STD_LOGIC := '0';
    SIGNAL reset : STD_LOGIC := '0';
    SIGNAL start : STD_LOGIC := '0';
    SIGNAL done  : STD_LOGIC := '0';
    signal goal_x, goal_y : integer range 0 to 6 := 0;
    
    -- Separate sets of signals
    SIGNAL ena_ff,  enb_ff : STD_LOGIC;
    SIGNAL wea_ff: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"; 
    SIGNAL addra_ff, addrb_ff : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL dina_ff : STD_LOGIC_VECTOR(15 DOWNTO 0);
    
    SIGNAL ena_user,  enb_user : STD_LOGIC;
     SIGNAL wea_user: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"; 
    SIGNAL addra_user, addrb_user : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL dina_user : STD_LOGIC_VECTOR(15 DOWNTO 0);
    
    
    -- Final signals to BRAM
    SIGNAL ena, enb : STD_LOGIC;
    SIGNAL wea : STD_LOGIC_VECTOR(1 DOWNTO 0);
    SIGNAL addra, addrb : STD_LOGIC_VECTOR(5 DOWNTO 0);
    SIGNAL dina : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL doutb : STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL temp : STD_LOGIC_VECTOR(15 DOWNTO 0);
    -- Clock Period
    CONSTANT CLK_PERIOD : TIME := 10 ns;
    
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
    
    -- Clock Process
    -- Clock Generation (FloodFill runs at half BRAM speed)
    process
    begin
        wait for 1 ns;
        clka <= not clka;
    end process;

    -- BRAM Clock (Twice the speed of FloodFill clock)
    process
    begin
        wait for 2 ns;
        clkb <= not clkb;
    end process;

    -- Write and Read Process
    

-- Process for Initializing BRAM Walls and Running Flood Fill
process (clka,clkb)
begin
    if rising_edge(clkb) then
     
        case state is
            when IDLE =>
                if init_start = '1' then  -- Start signal for initialization
                    cell_index_x <= 0;
                    cell_index_y <= 0;
                    goal_x <= 2;
                    goal_y <=2;
                    init_done <= '0';
                    walls <= "0000";
                    report "in idle";
                    state <= PRE_WRITE_CELL;
                    ena_user <='0';
                end if;
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
                report "in prewrite";
            when WRITE_CELL =>
                -- Calculate (x, y) from cell index
                 report "write cell";
                
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
                end if;
 
            when START_FLOODFILL =>
                start <= '1'; -- Start Flood Fill Module
                state <= WAIT_FLOODFILL;
report "starting algo";
            when WAIT_FLOODFILL =>
            
                if done = '1' then
                    start <= '0';
                    cell_index_x <= 0; 
                    cell_index_y <= 0; -- Reset index for BRAM reading
                    state <= READ_BRAM;
                 else 
                    state <= WAIT_FLOODFILL;
                    start <= '1';
                end if;

            when READ_BRAM =>
            
    enb_user  <= '1';  
    addrb_user <= std_logic_vector(to_unsigned(cell_index_x + 6 * cell_index_y, 6));

    -- Print BRAM Value
    report "BRAM[" & integer'image(cell_index_x) & "," & integer'image(cell_index_y) & "] = " 
       & integer'image(to_integer(unsigned(doutb(7 downto 0))));


    -- Move to next cell
    if cell_index_x < 5 then
        cell_index_x <= cell_index_x + 1;
    elsif (cell_index_x = 5) and (cell_index_y < 5) then
        cell_index_y <= cell_index_y + 1;
        cell_index_x <= 0;
    else
        state <= DONE_C;  -- All cells read, transition to DONE state
    end if;


            when DONE_C =>
            report "done";
                init_done <= '1';  -- Signal that initialization is complete
                state <= IDLE;     -- Ready for next initialization
        end case;
    end if;
end process;

-- Control arbitration logic
ena  <= ena_ff  when (state = START_FLOODFILL or state = WAIT_FLOODFILL) else ena_user;
wea  <= wea_ff  when (state = START_FLOODFILL or state = WAIT_FLOODFILL) else wea_user;
addra <= addra_ff when (state = START_FLOODFILL or state = WAIT_FLOODFILL) else addra_user;
dina  <= dina_ff when (state = START_FLOODFILL or state = WAIT_FLOODFILL) else dina_user;

enb  <= enb_ff  when (state = START_FLOODFILL or state = WAIT_FLOODFILL) else enb_user;
addrb <= addrb_ff when (state = START_FLOODFILL or state = WAIT_FLOODFILL) else addrb_user;




END Behavioral;