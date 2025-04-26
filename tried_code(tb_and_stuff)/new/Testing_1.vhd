library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.functions.all;
use IEEE.NUMERIC_STD.ALL;

entity FloodFill is
    Port (
        clk                : in std_logic;   -- Clock signal
        reset              : in std_logic;   -- Reset signal
        start              : in std_logic;   -- Start signal to begin flood fill
        goal_x, goal_y     : in integer range 0 to 5; -- Goal coordinates
        doutb              : in std_logic_vector (15 downto 0);
        addrb              : out std_logic_vector (5 downto 0);
        addra              : out std_logic_vector (5 downto 0);
        dina              : out std_logic_vector (15 downto 0);
        ena                : out std_logic;
        wea                : out std_logic_vector(1 downto 0);
        enb                : out std_logic; 
        done               : out std_logic
    );
end FloodFill;

architecture Behavioral of FloodFill is
    type state_type is (IDLE, INIT, PROCESSER, NEIGHBOR, UPDATE, COMPLETE); -- FSM states
    signal current_state, next_state : state_type;

    -- Queue to hold cells to be processed
    type queue_type is array (0 to 255) of integer range 0 to 6;
    signal queue_x, queue_y : queue_type;
    signal head, tail       : integer range 0 to 255;

    signal current_x, current_y : integer range 0 to 6:=0;
    signal next_x, next_y       : integer range 0 to 6:=0;

    signal direction_index : integer range 0 to 4 := 0;
    signal temp :std_logic_vector(15 downto 0);
begin
    -- State transition process
    process(clk, reset)
    begin
        if reset = '1' then
            current_state <= IDLE;
        elsif rising_edge(clk) then
            current_state <= next_state;
          end if;
    end process;

    -- Next state logic and operations
    process(current_state, start)
    begin
        case current_state is
            when IDLE =>
                if start = '1' then
                    next_state <= INIT; --1
                else
                    next_state <= IDLE; --1
                end if;
                done <= '0'; --1

            when INIT =>
                -- Initialize the flood fill process
                head <= 0; --1
                tail <= 1; --1
                queue_x(0) <= goal_x; --1
                queue_y(0) <= goal_y; --1
                wea<="01";
                ena<='1';
                addra <= bramindex(goal_x,goal_y);
                dina<="00000000";
                
                direction_index <= 0; --1
                next_state <= PROCESSER; --1

            when PROCESSER =>
                if head /= tail then
                    current_x <= queue_x(head); --p
                    current_y <= queue_y(head); --p
                    next_state <= NEIGHBOR; --p
                    direction_index <= 0;  
                    enb<='1';
                    addrb<=bramindex(queue_x(head),queue_y(head)); --any error check with enb off and on that controls read 
report "Next neighbour "  severity note;
                else
                    next_state <= COMPLETE; --p
                end if;

            when NEIGHBOR =>
            if direction_index=0 then
            temp<=doutb;
                if direction_index < 4 then
                enb<='1';
                 
			
                    -- Calculate neighbor coordinates based on direction_index
                    case direction_index is
                        when 0 =>  -- North 
	if current_x > 0 and current_y >0 then
                            next_x <= current_x - 1; --1
                            next_y <= current_y; --1
                            addrb<=bramindex(current_x -1,current_y);
	end if;
                        when 1 =>  -- East
                            next_x <= current_x;--2
                            next_y <= current_y + 1;--2
                            addrb<=bramindex(current_x,current_y +1);
                        when 2 =>  -- South
                            next_x <= current_x + 1;--3
                            next_y <= current_y; --3
                            addrb<=bramindex(current_x +1,current_y);
                        when 3 =>  -- West
	if current_x >0 and current_y >0 then
                            next_x <= current_x;--4
                            next_y <= current_y - 1; --4
                            addrb<=bramindex(current_x,current_y -1);
	end if;
                        when others =>
                            next_x <= current_x; --5
                            next_y <= current_y; --5
                            addrb<=bramindex(current_x,current_y);
                    end case;
		 
                    -- Check bounds
                    
			  report "Updated flood value for (" & integer'image(next_x) & ", " & integer'image(next_y) & 
                   ") to " & integer'image(maze_memory(next_x, next_y).flood_value) severity note;
                    report "In Neighbour next update "  severity note;
                    next_state <= UPDATE;
                else
                    direction_index <= 0;
report "In neigbour next Proces "  severity note;
                    next_state <= PROCESSER;
                    head <= head + 1;
                end if;

            when UPDATE =>
                if next_x >= 0 and next_x < 6 and next_y >= 0 and next_y < 6 then
                        report "Within bounds "  severity note;-- Check wall presence
			report "Checking walls(" & integer'image(direction_index) & ") at (" & integer'image(current_x) & 
       ", " & integer'image(current_y) & ") = " & std_ulogic'image(maze_memory(current_x, current_y).walls(direction_index)) severity note;

			 
                        if doutb(15 - direction_index) = '0' then
                           report "No walls "  severity note; -- Check visited status and flood value
			
                           
                        if doutb(7 downto 0) = "11111111" or 
   unsigned(doutb(7 downto 0)) > (unsigned(temp(7 downto 0)) + 1) then
   ena<='1';
   wea<="01";
   dina(7 downto 0) <= std_logic_vector(unsigned(temp(7 downto 0)) + 1);

                        report "updated "  severity note;
                                queue_x(tail) <= next_x;
                                queue_y(tail) <= next_y;
                                tail <= tail + 1;
                            end if;
                        end if;
                    end if;
                next_state <= NEIGHBOR;
		report "Entered direction loop for i = " & integer'image(direction_index) severity note;
report "In update next neighbour "  severity note;
                direction_index <= direction_index + 1;
            when COMPLETE =>
                done <= '1';
                next_state <= IDLE;

            when others =>
                next_state <= IDLE;
        end case;
    end process;
end Behavioral;