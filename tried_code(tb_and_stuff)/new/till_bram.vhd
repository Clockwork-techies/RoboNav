----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 26.03.2025 19:20:07
-- Design Name: 
-- Module Name: till_bram - Bram_1
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
 
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity till_bram is
--  Port ( );
port (switch : in std_logic;
     done_c_sig : out std_logic;
    clka :in std_logic;
     
     reset :out STD_LOGIC := '0'
   );
end till_bram;

architecture Bram_1 of till_bram is
 
   
    signal cell_index_x : integer range 0 to 6 := 0;--6 to solve 5,5 issue
    signal cell_index_y : integer range 0 to 6 := 0;
    


 signal walls : std_logic_vector(3 downto 0) := "0000";
 SIGNAL clkb  : STD_LOGIC := '0';
 signal goal_x, goal_y : integer range 0 to 6 := 0;
 SIGNAL done_c_sig_in : STD_LOGIC := '0';

 SIGNAL ena_user,  enb_user : STD_LOGIC;
  SIGNAL wea_user: STD_LOGIC_VECTOR(1 DOWNTO 0) := "00"; 
 SIGNAL addra_user, addrb_user : STD_LOGIC_VECTOR(5 DOWNTO 0);
 SIGNAL dina_user : STD_LOGIC_VECTOR(15 DOWNTO 0);


 
 SIGNAL doutb : STD_LOGIC_VECTOR(15 DOWNTO 0);
 SIGNAL temp : STD_LOGIC_VECTOR(15 DOWNTO 0);

 signal counter : integer := 0;
 type state_type is (IDLE, INIT_WALLS, WRITE_MEMORY, DONE);
    signal state : state_type := IDLE;


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

 begin

    DUT: blk_mem_gen_0
    PORT MAP (
        clka  => clka,
        ena   => ena_user,
        wea   => wea_user,
        addra => addra_user,
        dina  => dina_user,
        clkb  => clka,
        enb   => enb_user,
        addrb => addrb_user,
        doutb => doutb
    );


    process(clka)
    
    
    
   
    begin
        if rising_edge(clka) then
           case state is
                when IDLE =>
                    enb_user <= '0';
                    done_c_sig <= '1';
                    addrb_user <= "000000";
                    dina_user <= x"0000";
                    wea_user <= "00";
                    ena_user <= '0';
                    walls <= "0000";
                    cell_index_x <= 0;
                    cell_index_y <= 0;
                    if switch = '1' then
                        state <= INIT_WALLS;
                    end if;
                when INIT_WALLS =>
                      state <= WRITE_MEMORY;
                    enb_user <= '0';
                   
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
                when WRITE_MEMORY   =>
                enb_user <= '0';
                ena_user  <= '1';
               wea_user  <= "11";
               addra_user <= std_logic_vector(to_unsigned(6*cell_index_y+cell_index_x, 6));
               dina_user <= walls & "0000" & x"FF";

               if cell_index_x < 5 then  
               cell_index_x <= cell_index_x + 1;  
               state <= INIT_WALLS;  
               walls <= "0000";  
       
           elsif cell_index_y < 5 then  
               -- Move to the next row  
               cell_index_y <= cell_index_y + 1;  
               cell_index_x <= 0;  
               state <= INIT_WALLS;  
               walls <= "0000";  
       
           else  
               ena_user <= '0';-- All cells processed, move to next state  
               state <= DONE;  
           end if;  
        when DONE =>
                done_c_sig <= '1';     
            end case;


        end if;
    end process;


end Bram_1;
