library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity Clock_Divider is
    Port ( clk  : in STD_LOGIC;  -- 100 MHz system clock from W5
           clka : out STD_LOGIC; -- FloodFill clock
           clkb : out STD_LOGIC  -- BRAM clock
         );
end Clock_Divider;

architecture Behavioral of Clock_Divider is
    signal counter : integer := 0;
    signal clk_a, clk_b : STD_LOGIC := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            counter <= counter + 1;

            -- clkb runs at 50 MHz (1/2 of 100 MHz)
            if counter mod 2 = 0 then
                clk_b <= not clk_b;
            end if;

            -- clka runs at 25 MHz (1/2 of clkb, 1/4 of clk)
            if counter mod 4 = 0 then
                clk_a <= not clk_a;
            end if;
        end if;
    end process;

    clka <= clk_a;
    clkb <= clk_b;
end Behavioral;
