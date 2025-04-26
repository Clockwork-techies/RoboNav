library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity NEW_UART_TX is
    Port (
        clk       : in STD_LOGIC;
        uart_tx   : out STD_LOGIC;
        led_output: out STD_LOGIC;
        nw_enb       : out STD_LOGIC;
        trigger   : in STD_LOGIC;
        nw_addrb_out  : out STD_LOGIC_VECTOR(5 downto 0);
        nw_doutb_in  : in STD_LOGIC_VECTOR(15 downto 0); --- sliced
        done_c_sig: out STD_LOGIC:='0'
    );
end NEW_UART_TX;

architecture Behavioral of NEW_UART_TX is
    type state_type is (IDLE, START_TX,INIT, DATA, STOP, WAITS);
    signal tx_state : state_type := IDLE;
    
    -- UART Parameters
    constant BAUD_RATE  : integer := 115200;
    constant CLK_FREQ   : integer := 100000000;  -- 100 MHz clock
    constant BIT_PERIOD : integer := CLK_FREQ / BAUD_RATE;
    constant WAIT_TIME  : integer := 5*BIT_PERIOD;  -- 5-second delay
    
    -- Signal Registers
    signal clk_counter_tx : integer range 0 to BIT_PERIOD := 0;
    signal wait_counter   : integer range 0 to WAIT_TIME := 0;
    signal bit_index_tx   : integer range 0 to 7 := 0;
    signal nw_addrb       : integer range 0 to 6 := 0;
    
    -- Transmit Data: Fixed value 10101010
    signal tx_shift_reg   : STD_LOGIC_VECTOR(7 downto 0) := "00000000";  
    signal led_state      : STD_LOGIC := '0';
signal nw_doutb:std_logic_vector(7 downto 0):="00000000";
begin
    -- LED Output
    led_output <= led_state;
    

    -- UART Transmission Process
    process(clk, trigger)
    begin
        if rising_edge(clk) then
            case tx_state is
                when IDLE =>
                 uart_tx <= '1';
                 nw_addrb <= 0;
                 nw_enb <= '0';
                 
                    if trigger = '1' then
                        tx_state <= START_TX;
                         done_c_sig<= '0';
                        report "moving to sstart_tx";
                    else  done_c_sig<= '1';
                    end if;
                    report "waiting for trig";
                --   IDLE: Wait for 5 seconds
                when START_TX =>
                    uart_tx <= '1';  -- Idle line is high
                    
                    led_state <= '0'; 
                    report "in start_tx";
                     
                    nw_enb <='1';
                    
                    tx_shift_reg<=nw_doutb_in(7 downto 0);
                    if wait_counter < WAIT_TIME - 1 then
                        wait_counter <= wait_counter + 1;
                        report "wait_counter = " & integer'image(wait_counter);
                    else
                        wait_counter <= 0;
                        tx_state <= INIT;  -- Move to START state
                    end if;

                -- ✅ START: Send the start bit
                when INIT =>
                    report "INIT";
                    uart_tx <= '0';  -- Start bit (low)
                    led_state <= '1';  -- LED on during transmission
                    
                    if clk_counter_tx < BIT_PERIOD - 1 then
                        clk_counter_tx <= clk_counter_tx + 1;
                        report "bit_counter = " & integer'image(clk_counter_tx);
                    else
                        clk_counter_tx <= 0;
                        tx_state <= DATA;
                    end if;

                -- DATA: Send 8 bits of 10101010
                when DATA =>
                    report "data is being sent";
                    uart_tx <= tx_shift_reg(bit_index_tx);  -- Send bit-by-bit
                    
                    if clk_counter_tx < BIT_PERIOD - 1 then
                        clk_counter_tx <= clk_counter_tx + 1;
                    else
                        clk_counter_tx <= 0;
                        
                        if bit_index_tx = 7 then
                            tx_state <= STOP;  -- Move to STOP state after 8 bits
                        else
                            bit_index_tx <= bit_index_tx + 1;
                        end if;
                    end if;

                -- ✅ STOP: Send the stop bit
                when STOP =>
                    uart_tx <= '1';  -- Stop bit (high)
                    report "sent data";
                    if clk_counter_tx < BIT_PERIOD - 1 then
                        clk_counter_tx <= clk_counter_tx + 1;
                    else
                        clk_counter_tx <= 0;
                        tx_state <= WAITS;  -- Move to WAITS state
                    end if;

                -- ✅ WAITS: Small delay before returning to IDLE
                when WAITS =>
                    led_state <= '0';  -- Turn off LED after transmission
                    
                    if wait_counter < WAIT_TIME - 1 then
                        wait_counter <= wait_counter + 1;
                    else
                        wait_counter <= 0;
                        nw_addrb <= nw_addrb+1;
                        bit_index_tx <= 0;
                        if tx_shift_reg = "11111111" then
                        done_c_sig <= '1';
                        tx_state <= IDLE;  -- Return to IDLE

                        else tx_state <= START_TX;
                        end if;
                    end if;
            end case;
        end if;
    end process;
    nw_addrb_out <= std_logic_vector(to_unsigned(nw_addrb,6));
end Behavioral;