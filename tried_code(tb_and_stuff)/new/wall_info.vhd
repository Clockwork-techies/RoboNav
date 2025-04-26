architecture Behavioral of WallStorage is
    type ram_type is array (63 downto 0) of std_logic_vector(15 downto 0);
    shared variable RAM : ram_type := (others => (others => '0'));
    signal w_x, w_y : integer range 0 to 5;
    signal t : std_logic_vector(15 downto 0);
    signal direction_index : integer range 0 to 3;
    signal state : state_type;

    function bramindex(x, y: integer) return integer is
    begin
        return (6 * y) + x;
    end function;

begin
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                for i in 0 to 5 loop
                    RAM(bramindex(0, i)) := "00000100"; -- Left boundary (x=0)
                    RAM(bramindex(i, 0)) := "00001000"; -- Top boundary (y=0)
                    RAM(bramindex(5, i)) := "00000010"; -- Right boundary (x=5)
                    RAM(bramindex(i, 5)) := "00000001"; -- Bottom boundary (y=5)
                end loop;
                state <= IDLE;
            else
                case state is
                    when IDLE =>
                        if init_start = '1' then
                            w_x <= 0;
                            w_y <= 0;
                            state <= PRE_WRITE_CELL;
                            ena_user <= '0';
                        end if;
                    
                    when PRE_WRITE_CELL =>
                        if w_y = 0 then
                            t(3) <= '1';  -- North wall
                        elsif w_y = 5 then
                            t(0) <= '1';  -- South wall
                        end if;
                        if w_x = 0 then
                            t(1) <= '1';  -- West wall
                        elsif w_x = 5 then
                            t(2) <= '1';  -- East wall
                        end if;
                        state <= WRITE_CELL;
                    
                    when WRITE_CELL =>
                        ena_user  <= '1';
                        wea_user  <= "11";
                        addra_user <= std_logic_vector(to_unsigned(bramindex(w_x, w_y), 6));
                        dina_user <= t & "0000" & x"FF";
                        
                        if w_x < 5 then
                            w_x <= w_x + 1;
                            state <= PRE_WRITE_CELL;
                        elsif w_x = 5 and w_y < 5 then
                            w_y <= w_y + 1;
                            w_x <= 0;
                            state <= PRE_WRITE_CELL;
                        else
                            state <= START_FLOODFILL;
                        end if;
                    
                    when START_FLOODFILL =>
                        start <= '1';
                        state <= WAIT_FLOODFILL;
                    
                    when WAIT_FLOODFILL =>
                        if done = '1' then
                            start <= '0';
                            w_x <= 0;
                            w_y <= 0;
                            state <= READ_BRAM;
                        end if;
                    
                    when READ_BRAM =>
                        enb_user  <= '1';
                        addrb_user <= std_logic_vector(to_unsigned(bramindex(w_x, w_y), 6));
                        report "BRAM[" & integer'image(w_x) & "," & integer'image(w_y) & "] = " & integer'image(to_integer(unsigned(doutb(7 downto 0))));
                        if w_x < 5 then
                            w_x <= w_x + 1;
                        elsif w_x = 5 and w_y < 5 then
                            w_y <= w_y + 1;
                            w_x <= 0;
                        else
                            state <= DONE_C;
                        end if;
                end case;
            end if;
        end if;
    end process;
end Behavioral;
