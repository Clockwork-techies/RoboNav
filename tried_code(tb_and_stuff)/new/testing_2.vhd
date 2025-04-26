library IEEE; 
use IEEE.STD_LOGIC_1164.ALL;
use work.functions.all;
use IEEE.NUMERIC_STD.ALL;

entity FloodFill is
    Port (
        clk                : in std_logic;
        reset              : in std_logic;
        start              : in std_logic;
        goal_x, goal_y     : in integer range 0 to 5 := 2;
        doutb              : in std_logic_vector (15 downto 0);
        addrb              : out std_logic_vector (5 downto 0);
        addra              : out std_logic_vector (5 downto 0);
        dina               : out std_logic_vector (15 downto 0);
        ena                : out std_logic;
        wea                : out std_logic_vector(1 downto 0);
        enb                : out std_logic;
        done               : out std_logic
    );
end FloodFill;

architecture Behavioral of FloodFill is
    type state_type is (IDLE, INIT, PROCESSER, NEIGHBOR, UPDATE, COMPLETE);
    signal next_state : state_type;

    type queue_type is array (0 to 31) of integer range 0 to 5; -- Adjusted range to 0-5
    signal queue_x, queue_y : queue_type;
    signal head, tail       : integer range 0 to 31;

    signal current_x, current_y : integer range 0 to 5 := 0; -- Adjusted range to 0-5
    signal next_x, next_y       : integer range 0 to 5 := 0;

    signal direction_index : integer range 0 to 3 := 0;
    signal temp : std_logic_vector(15 downto 0);

begin
    process(clk, reset)
    begin
        if reset = '1' then
            -- Asynchronous reset initialization
            next_state <= IDLE;
            head <= 0;
            tail <= 0;
            current_x <= 0;
            current_y <= 0;
            next_x <= 0;
            next_y <= 0;
            direction_index <= 0;
            temp <= (others => '0');
            addrb <= (others => '0');
            addra <= (others => '0');
            dina <= (others => '0');
            ena <= '0';
            wea <= "00";
            enb <= '0';
            done <= '0';
            queue_x <= (others => 0);
            queue_y <= (others => 0);
        elsif rising_edge(clk) then
            case next_state is
                when IDLE =>
                    addra <= (others => '0');
                    addrb <= (others => '0');
                    dina <= (others => '0');
                    temp <= (others => '0');
                    ena <= '0';
                    enb <= '0'; 
                    wea <= "00";
                    head <= 0;
                    tail <= 0;
                    direction_index <= 0;
                    done <= '0';
                    if start = '1' then
                        queue_x(0) <= goal_x;
                        queue_y(0) <= goal_y;
                        tail <= 1;
                        next_state <= INIT;
                    else
                        next_state <= IDLE;
                    end if;

                when INIT =>
                    wea <= "01";
                    ena <= '1';
                    addra <= bramindex(goal_x, goal_y);
                    dina <= x"0000";
                    next_state <= PROCESSER;

                when PROCESSER =>
                    ena <= '0';
                    wea <= "00";
                    if head /= tail then
                        current_x <= queue_x(head);
                        current_y <= queue_y(head);
                        enb <= '1';
                        addrb <= bramindex(queue_x(head), queue_y(head));
                        next_state <= NEIGHBOR;
                        direction_index <= 0;
                    else
                        next_state <= COMPLETE;
                    end if;

                when NEIGHBOR =>
                    enb <= '1';
                    if direction_index = 0 then 
                        temp <= doutb;
                    end if;
                    case direction_index is
                        when 0 => -- North
                            if current_y > 0 then
                                next_x <= current_x;
                                next_y <= current_y - 1;
                                addrb <= bramindex(current_x, current_y - 1);
                            end if;
                        when 1 => -- East
                            if current_x < 5 then
                                next_x <= current_x + 1;
                                next_y <= current_y;
                                addrb <= bramindex(current_x + 1, current_y);
                            end if;
                        when 2 => -- West
                            if current_x > 0 then
                                next_x <= current_x - 1;
                                next_y <= current_y;
                                addrb <= bramindex(current_x - 1, current_y);
                            end if;
                        when 3 => -- South
                            if current_y < 5 then
                                next_x <= current_x;
                                next_y <= current_y + 1;
                                addrb <= bramindex(current_x, current_y + 1);
                            end if;
                    end case;
                    next_state <= UPDATE;

                when UPDATE =>
                    enb <= '0';
                    if next_x >= 0 and next_x <= 5 and next_y >= 0 and next_y <= 5 then
                        if temp(15 - direction_index) = '0' then
                            if doutb(7 downto 0) = x"FF" or unsigned(doutb(7 downto 0)) > unsigned(temp(7 downto 0)) + 1 then
                                ena <= '1';
                                wea <= "01";
                                addra <= bramindex(next_x, next_y);
                                dina <= "00000000" & std_logic_vector(unsigned( temp(7 downto 0)) + 1);
                                queue_x(tail) <= next_x;
                                queue_y(tail) <= next_y;
                                if tail < 31 then
                                    tail <= tail + 1;
                                else
                                    tail <= 0;
                                end if;
                            end if;
                        end if;
                    end if;
                    if direction_index < 3 then
                        direction_index <= direction_index + 1;
                        next_state <= NEIGHBOR;
                    else
                        direction_index <= 0;
                        if head < 31 then
                            head <= head + 1;
                        else
                            head <= 0;
                        end if;
                        next_state <= PROCESSER;
                    end if;

                when COMPLETE =>
                    done <= '1';
                    next_state <= IDLE;

                when others =>
                    next_state <= IDLE;
            end case;
        end if;
    end process;
end Behavioral;