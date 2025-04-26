----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 20.03.2025 18:58:30
-- Design Name: 
-- Module Name: tx_test - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tx_test is
--  Port ( );
end tx_test;

architecture Behavioral of tx_test is
signal goal_reached     : std_logic := '0';

signal clk   : std_logic := '0';
    signal shortpath_done    : std_logic := '0';
    signal led_out     : std_logic := '0';
    signal state_led         : std_logic_vector(6 downto 0) := (others => '0');
    signal shortpathdone_beforetx : std_logic := '0';
     signal uart_tx_pin     : std_logic := '0';
     

component top is
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
         

        
END component;

begin



S: top 
port map(
start_bot => '1',
goal_reached => goal_reached,
shortpath_done => shortpath_done,
clka       => clk,
led_out   => led_out,
uart_rx_pin    => '0',
uart_tx_pin   => uart_tx_pin,
state_led         => state_led,
shortpathdone_beforetx  => shortpathdone_beforetx
); 

 process
    begin
        wait for 1 ns;
        clk <= not clk;
    end process;

end Behavioral;
