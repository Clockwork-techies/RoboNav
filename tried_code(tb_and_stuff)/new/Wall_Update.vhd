library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
 
use work.functions.all;
 
use IEEE.NUMERIC_STD.ALL;

entity Wall_Update is
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
        next_x, next_y : out INTEGER range 0 to 5;
        goal_x, goal_y       : in INTEGER range 0 to 5;
        rx_check:out std_logic_vector(3 downto 0):= "0000";
        
        destination_reached : out STD_LOGIC := '0'
    );
end Wall_Update;

architecture Behavioral of Wall_Update is
      signal four_bits: std_logic_vector(3 downto 0):= "0000";
    type state_type is (IDLE, COLLECT_DIR, data,stop,READ_BRAM,neighbour_update_r,neighbour_update_w, WAIT_UART,data_waiting, start);
    signal state, next_state : state_type := IDLE;
    signal received_data : STD_LOGIC_VECTOR(7 downto 0);
    signal bot_x, bot_y : INTEGER range 0 to 5;
    signal n_x, n_y : INTEGER range 0 to 5;
    signal uart_shift_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal bit_count : INTEGER range 0 to 7 := 0;
    signal uart_done : STD_LOGIC := '0';
    signal toggle : STD_LOGIC := '0';
    signal di : INTEGER range 0 to 4 := 0;
     signal wall_data : STD_LOGIC_VECTOR(3 downto 0);
    type queue_type is array (0 to 255) of integer range 0 to 6;
    signal queue_x, queue_y : queue_type;
    signal head, tail : INTEGER range 0 to 31 := 0;
    signal queue_count : INTEGER range 0 to 31 := 0;
    type state_typ is (IDLES, START, DATA, STOP);
    signal rx_state : state_typ := IDLES;

    constant BAUD_RATE  : integer := 115200;
    constant CLK_FREQ   : integer := 25000000;  -- 100 MHz clock
    constant BIT_PERIOD : integer := CLK_FREQ / BAUD_RATE;
    signal clk_2 : integer range 0 to 3 := 0;
    signal clk_counter_rx : integer range 0 to BIT_PERIOD := 0;
    signal bit_index   : integer range 0 to 7 := 0;
    signal rx_shift_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal received_flag : STD_LOGIC := '0';
    signal led_state : STD_LOGIC := '0';
    signal tx_ready_prev  : STD_LOGIC := '0';
    signal tx_ready_edge  : STD_LOGIC := '0';
    
begin
process(clk)
    begin
        if rising_edge(clk) then
            four_bits <= rx_shift_reg(3 downto 0);
            tx_ready_prev <= tx_ready;
            tx_ready_edge <= tx_ready and not tx_ready_prev;
        end if;
    end process;
  process(clk)
begin
    if rising_edge(clk) then
        if reset = '1' then
            -- Reset all registers and outputs
             rx_check<="0000";
            state <= IDLE;
            ena <= '0';
            enb <= '0';
            wea<="00";
            done_wu <= '0';
            bot_x <= 0;
            bot_y <= 0;
            head <= 0;
            tail <= 0;
            di <=0;
            n_x<=0;
            n_y<=0;
            queue_count <= 0;
            queue_x <= (others => 0);
            queue_y <= (others => 0);
            next_x <= current_x;
            next_y <= current_y;
            addra <= (others => '0');
            addrb <= (others => '0');
            dina <= (others => '0');
            received_data <= (others => '0');
            destination_reached <= '0';
            received_flag <= '0';
            clk_counter_rx <= 0;
            bit_index   <= 0;
        else
            -- Default assignments
           

            case state is
                when IDLE =>
                rx_check<="0001";
                 ena <= '0';
            enb <= '0';
            done_wu <= '0';
            bot_x <= 0;
            bot_y <= 0;
            head <= 0;
            tail <= 1;
            queue_count <= 0;
            queue_x <= (others => 0);
            queue_y <= (others => 0);
            next_x <= current_x;
            next_y <= current_y;
            addra <= (others => '0');
            addrb <= (others => '0');
            dina <= (others => '0');
            received_data <= (others => '0');
            bot_x <= current_x;
            bot_y <= current_y;
            destination_reached <= '0';
             queue_x(0) <= current_x;
             queue_y(0) <= current_y;
                    if start_sp = '1' then--
                        clk_counter_rx<=0;--
                        queue_count <= 1;
                        state <= COLLECT_DIR;
                    else 
                        state <= IDLE;
                    end if;

                when COLLECT_DIR => rx_check<="0011";
                    if tx_ready_edge = '1' then 
                        case directions(3 downto 0) is
                            when "0001" => -- North
                                if bot_y < 5 then
                                    bot_y <= bot_y + 1;
                                    state <= COLLECT_DIR;
                                    queue_x(tail) <= bot_x;
                                    queue_y(tail) <= bot_y + 1;
                                   if tail < 31 then
                          		  tail <= tail + 1;
				    else 
			   		 tail <= 0;
			end if;
                                end if;
                            when "1000" => -- South
                                if bot_y > 0 then
                                    bot_y <= bot_y - 1;
                                    state <= COLLECT_DIR;
                                    queue_x(tail) <= bot_x;
                                    queue_y(tail) <= bot_y - 1;
                                    if tail < 31 then
                          		  tail <= tail + 1;
				    else 
			   		 tail <= 0;
			end if;
                                end if;
                            when "0100" => -- East
                                if bot_x < 5 then
                                    bot_x <= bot_x + 1;
                                    state <= COLLECT_DIR;
                                    queue_x(tail) <= bot_x + 1;
                                    queue_y(tail) <= bot_y;
                                    if tail < 31 then
                          		  tail <= tail + 1;
				    else 
			   		 tail <= 0;
			end if;
                                end if;
                            when "0010" => -- West
                                if bot_x > 0 then
                                    bot_x <= bot_x - 1;
                                    state <= COLLECT_DIR;
                                    queue_x(tail) <= bot_x - 1;
                                    queue_y(tail) <= bot_y;
                                    if tail < 31 then
                          		  tail <= tail + 1;
				    else 
			   		 tail <= 0;
			end if;
                                end if;
			    when "1111" =>   state <= data_waiting;
   
                            when others =>
                            
                                state <= data_waiting;
                               
                        end case;
                        
                    else
                        state <= collect_dir;
                    end if;
                    when data_waiting =>--idle rx
                     rx_check<="0111";
                     received_flag <= '0';
                    clk_counter_rx <= 0;
                    bit_index   <= 0;
                    if uart_rx = '0' then  -- Detect start bit
                        state       <= START;
                        clk_counter_rx <= 0;
                    end if;
                    
                     when START =>
                      rx_check<="1111";
                    if clk_counter_rx < (BIT_PERIOD / 2) - 1 then
                        clk_counter_rx<= clk_counter_rx + 1;
                    else
                        if uart_rx = '0' then
                            clk_counter_rx <= 0;
                            state       <= DATA;
                        else
                            state <= data_waiting;
                        end if;
                    end if;
                    
                    when DATA =>
                     rx_check<="1000";
                   
                    if clk_counter_rx < BIT_PERIOD - 1 then
                        clk_counter_rx <= clk_counter_rx + 1;
                    else
                        clk_counter_rx <= 0;
                        rx_shift_reg(bit_index) <= uart_rx;
                        if bit_index = 7 then
                            state <=stop;
                        else
                            bit_index <= bit_index + 1;
                        end if;
                    end if;
                   
                when stop =>
                 rx_check<="1100";
                 
                    if clk_counter_rx < BIT_PERIOD - 1 then
                        clk_counter_rx <= clk_counter_rx + 1;
                    else
                        if uart_rx = '1' then -- Stop bit must be high
                            received_flag <= '1'; -- Valid data received
                               
                             
                            end if;
                            clk_counter_rx <= 0;
                            state <= wait_uart;
                        end if;
                        
                        
                    
                when wait_uart =>
                 rx_check<="1110";
                ena <='0';
                    if received_flag = '1' then
                        received_data <= rx_shift_reg;
                        if rx_shift_reg(7 downto 4) = "0000" then
                            -- Read from BRAM
                            
                            addrb <= bramindex(queue_x(head), queue_y(head));
                             enb<='1';
                            state <= READ_BRAM;
                        elsif rx_shift_reg(7 downto 4) = "1010" then
                            -- Destination reached
                            enb <='0';
                            destination_reached <= '1';
                            done_wu <= '1';
                            state <= IDLE;
                        else
                            enb <='0';
                            -- Update next coordinates
                            if head > 0 then
                                next_x <= queue_x(head-1);
                                next_y <= queue_y(head-1);
                            else
                                next_x <= queue_x(255);
                                next_y <= queue_y(255);
                            end if;
                            done_wu <= '1';
                            state <= IDLE;
                        end if;
                    end if;

                when READ_BRAM =>
                 rx_check<="0101";
                    -- Write to BRAM
                    addra <= bramindex(queue_x(head), queue_y(head));
                    dina <= doutb or (received_data(3 downto 0)& "0000" & "00000000");
                    ena <= '1';
                    wea <= "11";
			
                            queue_count <= queue_count - 1;
                     
		    di <= 0;
                    state <= neighbour_update_r;
 when neighbour_update_r => 
  if di < 4 then
        if received_data(di) = '1' then
             
            case di is
                when 0 =>  -- South → y + 1, set North (bit 3)
                    if queue_y(head) < 5 then
                        wall_data <= "1000";
                        addrb <= bramindex(queue_x(head), queue_y(head) + 1);
                         n_x <= queue_x(head);
                    n_y <= queue_y(head) + 1;
                        enb <= '1';
                        state <= neighbour_update_w;
                    else
                        di <= di + 1;  -- Skip out-of-bound
                    end if;

                when 1 =>  -- East → x + 1, set West (bit 2)
                    if queue_x(head) < 5 then
                        wall_data <= "0010";
                        addrb <= bramindex(queue_x(head) + 1, queue_y(head));
                        enb <= '1';
                         n_x <= queue_x(head) + 1;
                    n_y <= queue_y(head);
                        state <= neighbour_update_w;
                    else
                        di <= di + 1;
                    end if;

                when 2 =>  -- West → x - 1, set East (bit 1)
                    if queue_x(head) > 0 then
                        wall_data <= "0100";
                        addrb <= bramindex(queue_x(head) - 1, queue_y(head));
                          n_x <= queue_x(head) - 1;
                    n_y <= queue_y(head);
                        enb <= '1';
                        state <= neighbour_update_w;
                    else
                        di <= di + 1;
                    end if;

                when 3 =>  -- North → y - 1, set South (bit 0)
                    if queue_y(head) > 0 then
                        wall_data <= "0001";
                        addrb <= bramindex(queue_x(head), queue_y(head) - 1);
                        enb <= '1';
                        state <= neighbour_update_w;
                    else
                        di <= di + 1;
                    end if;

                when others =>
                    di <= di + 1;
            end case;
        else
            -- No wall to update in this direction
            di <= di + 1;
        end if;
    else
        state <= data_waiting;  -- Done with all directions
        if head < 31 then
                            head <= head + 1;
			else 
			    head <= 0;
			end if;
    end if;
    
    when neighbour_update_w =>
        
    enb <= '0';
    if (n_x >= 0 and n_x <= 5) and (n_y >= 0 and n_y <= 5) then
        addra <= bramindex(n_x, n_y);
        ena <= '1';
        wea <= "11";
        dina <= doutb or (wall_data & "0000" & x"00");  -- update only wall bits
    end if;
    di <= di + 1;
    state <= neighbour_update_r;
            
            end case;
        end if;
    end if;
end process;

end behavioral;