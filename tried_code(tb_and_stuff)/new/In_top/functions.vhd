library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package functions is
    function bramindex(x, y: integer) return std_logic_vector;
    function to_fixed_str(num : integer) return string;
end package functions;

package body functions is
    function bramindex(x, y: integer) return std_logic_vector is
        variable addr : integer := 0;
    begin
        addr := (y * 6) + x;  -- Row-major order
        return std_logic_vector(to_unsigned(addr, 6)); -- 6-bit address
    end function bramindex;

    function to_fixed_str(num : integer) return string is
        variable str : string(1 to 3) := "   "; -- Fixed 3-char width
        variable temp_str : string(1 to 11); -- Max length of integer'image
    begin
        temp_str := integer'image(num); -- Convert to string
        if num < 10 then
            str(1 to 3) := "  " & temp_str(1); -- Right-align single-digit numbers
        elsif num < 100 then
            str(1 to 3) := " " & temp_str(1 to 2); -- Right-align two-digit numbers
        else
            str(1 to 3) := temp_str(1 to 3); -- Use all three characters
        end if;
        return str;
    end function to_fixed_str;
end package body functions;
