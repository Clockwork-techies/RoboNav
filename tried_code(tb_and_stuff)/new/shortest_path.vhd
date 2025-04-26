LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;
USE work.functions.ALL;

ENTITY ShortestPathProcessor IS
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
END ShortestPathProcessor;

ARCHITECTURE Behavioral OF ShortestPathProcessor IS

    TYPE State_Type IS (INIT, PROCESSER,FOUR_DIR_COORD_GEN, VALUE_COLLECT, NEXT_DIR, MOVE, CHECK_GOAL);
    SIGNAL state, next_state : State_Type;
 SIGNAL c_x,c_y: INTEGER RANGE 0 TO 5;
    SIGNAL next_direction,prev_d,direction_index : INTEGER RANGE 0 TO 3;
    SIGNAL min_dir : STD_LOGIC_VECTOR(3 DOWNTO 0) := "0000";  -- Bitwise direction storage
    SIGNAL min_value : INTEGER RANGE 0 TO 255 := 255;
    SIGNAL wall_detected : STD_LOGIC := '0';
    SIGNAL toggle : STD_LOGIC := '0'; -- to trigger state transition
    SIGNAL temp : STD_LOGIC_VECTOR(15 DOWNTO 0);
    -- Flood fill values of neighbors
    SIGNAL north_val, east_val, south_val, west_val : INTEGER RANGE 0 TO 255;
function CountOnes(bits: STD_LOGIC_VECTOR(3 downto 0)) return INTEGER is
        variable count : INTEGER := 0;
    begin
        for i in bits'range loop
            if bits(i) = '1' then
                count := count + 1;
            end if;
        end loop;
        return count;
    end function CountOnes;
BEGIN

    -- Synchronous state transition
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            IF reset = '1' THEN
              
                state <= INIT;
            ELSE
                state <= next_state;
                toggle <= not(toggle);
            END IF;
        END IF;
    END PROCESS;

    -- State Machine Logic
    PROCESS (state,start_sp,toggle )
    BEGIN
        CASE state IS
            WHEN INIT =>
                -- Reset all values
               enb_sp<= '0';
               prev_d <= came_from;
                c_x <= current_x;
                c_y <= current_y;
                 enb <= '0';
                addrb<= bramindex(current_x,current_y);
                IF start_sp = '1' THEN
                 report "INIT -> PROCESSOER: Start triggered c" severity note;
                    next_state <= PROCESSER;
                ELSE
                    next_state <= INIT;
                END IF;
            WHEN PROCESSER => 
            if c_x = goal_x and goal_y = c_y then 
             report "GOAL Reached, transmitting end" severity note;
                tx_ready <= '1';
                directions<="11111111";
                reached_goal <= '1';
            else
             min_value <= 255;
                min_dir <= "0000";
                 tx_ready <= '0';
                direction_index <= 0;
                 temp <= doutb;
                  enb <= '1';
                   report "In processer c_x="& integer'image(c_x)&" c_y="& integer'image(c_y)&"its value="& integer' image(to_integer(unsigned(doutb)))severity note;
                  next_state <= FOUR_DIR_COORD_GEN;
              end if;
            WHEN FOUR_DIR_COORD_GEN =>
            report "In FDCG " severity note;
             if direction_index < 4  then -- have to init doutb
                    if temp(15-direction_index) = '0' then --finding wall in dir
                  report "In processer,no wall in direction"severity note;
                    case direction_index is
                        when 0 => addrb<=bramindex(c_x,c_y-1 );
                          report "In processer, di=0" severity note;
 
                        when 1 => 
                         
                            addrb<=bramindex(c_x+1,c_y );
                             report "In processer,di=1" severity note;
                        
                        when 3 =>  -- South 
                            addrb<=bramindex(c_x ,c_y+1);
                            report "In processer,di=3"severity note;
                        when 2 =>  -- West
                           report "In processer,di=2"severity note;
                            addrb<=bramindex(c_x-1,c_y );
                        when others =>
                            addrb<=bramindex(c_x,c_y);
                            report "In processer,wrong init"severity note;
                    end case;
		 

                next_state <= VALUE_COLLECT;
          elsif temp(15-direction_index) = '1' then
           next_state <= FOUR_DIR_COORD_GEN;
          report "In processoer, wall in direction"severity note; 
            direction_index <= direction_index +1;
		

	  end if;
          else 
            next_state <= Next_dir;
            
            
end if;
 
            WHEN VALUE_COLLECT =>
if direction_index <4 then 
                   report "Value_collect state"severity note; 
                case direction_index is
                        when 0 => 
                          IF to_integer(unsigned(doutb(7 DOWNTO 0))) < min_value THEN
                    min_value <= to_integer(unsigned(doutb(7 DOWNTO 0)));
                    min_dir <= "1000"; 
                     report "min_value = 1000"severity note;
                     report "min_dir = "& integer' image(to_integer(unsigned(doutb(7 DOWNTO 0))))severity note;
                    ELSIF to_integer(unsigned(doutb(7 DOWNTO 0))) = min_value THEN
                     report "equal flood value N"severity note;
                    min_dir <= min_dir OR "1000";
                 
                    end if;
                    
                        when 1 => 
                         IF to_integer(unsigned(doutb(7 DOWNTO 0))) < min_value THEN
                    min_value <= to_integer(unsigned(doutb(7 DOWNTO 0)));
                    min_dir <= "0100"; 
                    report "min_value = 0100"severity note;
                     report "min_dir = "& integer' image(to_integer(unsigned(doutb(7 DOWNTO 0))))severity note;
                    ELSIF to_integer(unsigned(doutb(7 DOWNTO 0))) = min_value THEN
                    min_dir <= min_dir OR "0100";
                    report "equal flood value E"severity note;
                    end if;
                             
                        
                        when 3 =>  -- South 
                             IF to_integer(unsigned(doutb(7 DOWNTO 0))) < min_value THEN
                    min_value <= to_integer(unsigned(doutb(7 DOWNTO 0)));
                    min_dir <= "0001"; 
                    report "min_value = 0001"severity note;
                     report "min_dir = "& integer' image(to_integer(unsigned(doutb(7 DOWNTO 0))))severity note;
                    ELSIF to_integer(unsigned(doutb(7 DOWNTO 0))) = min_value THEN
                    min_dir <= min_dir OR "0001";
                    report "equal flood value S"severity note;
                    end if;
                        when 2 =>  -- West
                           IF to_integer(unsigned(doutb(7 DOWNTO 0))) < min_value THEN
                    min_value <= to_integer(unsigned(doutb(7 DOWNTO 0)));
                    min_dir <= "0010"; 
                    report "min_value = 0010"severity note;
                     report "min_dir = "& integer' image(to_integer(unsigned(doutb(7 DOWNTO 0))))severity note;
                    ELSIF to_integer(unsigned(doutb(7 DOWNTO 0))) = min_value THEN
                    min_dir <= min_dir OR "0010";
                    report "equal flood value W"severity note;
                    end if;
                           
                         
                           
                    end case;
                    
                     direction_index <= direction_index +1;
		     next_state <= FOUR_DIR_COORD_GEN;
                  
 
          else 
            next_state <= Next_dir;
		  end if;

            WHEN NEXT_DIR =>
               report "In next_dir, min_dir = "& integer' image(to_integer(unsigned(min_dir)))severity note; 
if sent = '1' then                                        --- initially noo data sent so .. initailise somewhere - top mod
	if CountOnes(min_dir) = 1 then  -- priority for dir
	report "In next_dir, no problem" severity note; 
	directions <= "0000" & min_dir;
            tx_ready<= '1';
            next_state <= processer;
            case min_dir is 
                when "1000" => 
                    c_y <= c_y-1;
                    prev_d <= 3;
                    addrb <= bramindex(c_x,c_y-1); --to store as temp in processor
                     report "North min"severity note;
                when "0100" => 
                    c_x <= c_x+1;
                    prev_d <= 2;
                    addrb <= bramindex(c_x+1,c_y);
                    report "EAST min"severity note;
                when "0010" => 
                    c_x <= c_x-1;
                    prev_d <= 1;
                    addrb <= bramindex(c_x-1,c_y);
                    report "West min"severity note; 
                when "0001" => 
                    c_x <= c_y+1;
                    prev_d <= 0;
                    addrb <= bramindex(c_x,c_y+1);
                    report "South min"severity note;
                      
                 when others => 
                    addrb <= bramindex(c_x,c_y);
                    report "Wrong value"severity note;
                      
                end case;	
	else
		if CountOnes(min_dir) > 1 then
 		            report "more than one min"severity note;
           			 next_state <= processer;
			if ((temp(11 downto 8) and min_dir) = "0000" or (temp(11 downto 8) and min_dir) = (min_dir)) then 
				report "not exp or both exp so oppos"severity note;
				if min_dir(prev_d) = '1' then
					case prev_d is 
                                  when 3 => 
                            c_y <= c_y-1;
		directions <= "00001000";
		report "North minc"severity note;
                            prev_d <= 3;
				tx_ready<= '1';
                            addrb <= bramindex(c_x,c_y-1); --to store as temp in processor
                             
                        when 2 => 
                            c_x <= c_x+1;
                            prev_d <= 2;
				directions <= "00000100";
				tx_ready<= '1';
				report "east minc"severity note;
                            addrb <= bramindex(c_x+1,c_y);
                            
                        when 1 => 
                            c_x <= c_x-1;
                            prev_d <= 1;
			directions <= "00000010";
			tx_ready<= '1';
			report "west minc"severity note;
                            addrb <= bramindex(c_x-1,c_y);
                             
                        when 0 => 
                            c_y <= c_y+1;
                            prev_d <= 0;
				directions <= "00000001";
				tx_ready<= '1';
				report "south minc"severity note;
                            addrb <= bramindex(c_x,c_y+1);
                              
                         when others => 
                            addrb <= bramindex(c_x,c_y);
                              report "others"severity note;
                        end case;
				else 
					if min_dir(3) = '1' then  
              c_y <= c_y-1;
                            prev_d <= 3;
                            addrb <= bramindex(c_x,c_y-1);
directions <= "00001000";
report "Northe min"severity note;
tx_ready<= '1';
        elsif min_dir(2) = '1' then  
           c_x <= c_x+1;
            report "EASTe min"severity note;                
            prev_d <= 2;
directions <= "00000100";
tx_ready<= '1';
                            addrb <= bramindex(c_x+1,c_y); -- Choose East  
        elsif min_dir(1) = '1' then  
        c_x <= c_x-1;
                         report "weste min"severity note;
                            prev_d <= 1;
directions <= "00000010";
tx_ready<= '1';
                            addrb <= bramindex(c_x-1,c_y);
             
        elsif   min_dir(0) = '1' then
           c_x <= c_y+1;
                            prev_d <= 0;
                            report "southe min "severity note;
directions <= "00000001";
tx_ready<= '1';
                            addrb <= bramindex(c_x,c_y+1); -- Choose South  
        else 
                            addrb <= bramindex(c_x,c_y);
                            report "wrong val"severity note;
                            
        end if;
				end if;

			else
				directions <= "0000" & (not(temp(11 downto 8)) and min_dir);
				report "unexplored min = " & integer' image(to_integer(unsigned((not(temp(11 downto 8)) and min_dir))))severity note;
				case (not(temp(11 downto 8)) and min_dir) is --           
                when "1000" => 
                    c_y <= c_y-1;
                    report "North unexp min"severity note;
                    prev_d <= 3;
tx_ready<= '1';

                    addrb <= bramindex(c_x,c_y-1); --to store as temp in processor
                     
                when "0100" => 
                    c_x <= c_x+1;
                    report "east unexp min"severity note;
                    prev_d <= 2;
                    addrb <= bramindex(c_x+1,c_y);
tx_ready<= '1';
                    
                when "0010" => 
                    c_x <= c_x-1;
                    prev_d <= 1;
                    report "west unexp min"severity note;
                    
                    addrb <= bramindex(c_x-1,c_y);
tx_ready<= '1';
                     
                when "0001" => 
                    c_x <= c_y+1;
                    prev_d <= 0;
                    report "south unexp min"severity note;
                    addrb <= bramindex(c_x,c_y+1);
tx_ready<= '1';
                      
                 when others => 
                    addrb <= bramindex(c_x,c_y);
                    report "unecp unexp min"severity note;
                      
                end case;
			end if;

		else 
    addrb <= bramindex(c_x,c_y);

		end if;
	end if;	
else 
	next_state <= processer;
end if;
 


             
            WHEN OTHERS =>
                next_state <= INIT;
        END CASE;
    END PROCESS;

END Behavioral;