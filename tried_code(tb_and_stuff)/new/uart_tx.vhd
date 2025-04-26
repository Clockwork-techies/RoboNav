library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity UART_TX is
    Port (
        clk       : in STD_LOGIC;
        tx_ready  : in STD_LOGIC;
        tx_data   : in STD_LOGIC_VECTOR(7 downto 0);
        uart_tx   : out STD_LOGIC;
        led_output: out STD_LOGIC;
        sent      : out STD_LOGIC
    );
end UART_TX;

architecture Behavioral of UART_TX is
    type state_type is (IDLE, START, DATA, STOP);
    signal tx_state : state_type := IDLE;
    
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

begin
    -- LED Output
    led_output <= led_state;
    sent <= sent_signal;
    
    -- Detect Rising Edge of tx_ready
    process(clk)
    begin
        if rising_edge(clk) then
            tx_ready_prev <= tx_ready;
            tx_ready_edge <= tx_ready and not tx_ready_prev;
        end if;
    end process;
    
    -- UART Transmission Process
    process(clk)
    begin
        if rising_edge(clk) then
            case tx_state is
                when IDLE =>
                    uart_tx <= '1';  -- Idle line is high
                    led_state <= '0'; 
                    bit_index_tx <= 0;
                    clk_counter_tx <= 0;
                    sent_signal <= '1';
                    
                    if tx_ready_edge = '1' then
                        tx_shift_reg <= tx_data;  -- Load input data
                       report"data to be sent:" &  integer'image(to_integer(unsigned(tx_data))) ;
                        tx_active <= '1';
                        tx_state <= START;
                    end if;
                
                when START =>
                sent_signal<='0';
                    uart_tx <= '0';  -- Start bit (low)
                    led_state <= '1';  -- LED on during transmission
                    
                    if clk_counter_tx < BIT_PERIOD - 1 then
                        clk_counter_tx <= clk_counter_tx + 1;
                    else
                        clk_counter_tx <= 0;
                        tx_state <= DATA;
                    end if;
                
                when DATA =>
                    uart_tx <= tx_shift_reg(bit_index_tx);  -- Send bit-by-bit
                    
                    if clk_counter_tx < BIT_PERIOD - 1 then
                        clk_counter_tx <= clk_counter_tx + 1;
                    else
                        clk_counter_tx <= 0;
                        
                        if bit_index_tx = 7 then
                            tx_state <= STOP;
                        else
                            bit_index_tx <= bit_index_tx + 1;
                        end if;
                    end if;
                
                when STOP =>
                    uart_tx <= '1';  -- Stop bit (high)
                    
                    if clk_counter_tx < BIT_PERIOD - 1 then
                        clk_counter_tx <= clk_counter_tx + 1;
                    else
                        clk_counter_tx <= 0;
                        tx_state <= IDLE;
                        tx_active <= '0';
                        sent_signal <= '1';
                        report "sent";
                    end if;
            end case;
        end if;
    end process;
    
end Behavioral;