library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity DisplayTwoDigits_Int is
    Port (
        clk   : in  STD_LOGIC;          -- 100 MHz clock
        num1  : in  INTEGER range 0 to 6; -- First digit (rightmost)
        num2  : in  INTEGER range 0 to 6; -- Second digit (next left)
        seg   : out STD_LOGIC_VECTOR(6 downto 0); -- Segments a-g
        an    : out STD_LOGIC_VECTOR(3 downto 0)  -- Anodes
    );
end DisplayTwoDigits_Int;

architecture Behavioral of DisplayTwoDigits_Int is

    signal refresh_counter : unsigned(15 downto 0) := (others => '0');
    signal digit_toggle    : STD_LOGIC := '0';
    signal current_digit   : INTEGER range 0 to 9;

begin

    -- Clock divider: Generates ~762 Hz refresh signal
    process(clk)
    begin
        if rising_edge(clk) then
            refresh_counter <= refresh_counter + 1;
            if refresh_counter = 0 then
                digit_toggle <= not digit_toggle;
            end if;
        end if;
    end process;

    -- Time-multiplexing: Choose digit and enable correct anode
    process(digit_toggle, num1, num2)
    begin
        if digit_toggle = '0' then
            current_digit <= num1;
            an <= "1110"; -- Activate rightmost display
        else
            current_digit <= num2;
            an <= "1101"; -- Activate next digit
        end if;
    end process;

    -- Decoder: Integer to 7-segment pattern (common anode)
    process(current_digit)
    begin
        case current_digit is
            when 0 => seg <= "1000000";
            when 1 => seg <= "1111001";
            when 2 => seg <= "0100100";
            when 3 => seg <= "0110000";
            when 4 => seg <= "0011001";
            when 5 => seg <= "0010010";
            when 6 => seg <= "0000010";
            
            when others => seg <= "1111111"; -- blank
        end case;
    end process;

end Behavioral;
