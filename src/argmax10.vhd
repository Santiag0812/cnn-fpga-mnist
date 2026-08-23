library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.package_cnn.all;

entity argmax10 is
    port(
        logit0 : in  s8_t;
        logit1 : in  s8_t;
        logit2 : in  s8_t;
        logit3 : in  s8_t;
        logit4 : in  s8_t;
        logit5 : in  s8_t;
        logit6 : in  s8_t;
        logit7 : in  s8_t;
        logit8 : in  s8_t;
        logit9 : in  s8_t;
        digit  : out std_logic_vector(3 downto 0)
    );
end entity;

architecture structural_rtl of argmax10 is
begin
    process(logit0, logit1, logit2, logit3, logit4, logit5, logit6, logit7, logit8, logit9)
        variable max_val : s8_t;
        variable max_idx : integer range 0 to 9;
    begin
        max_val := logit0;
        max_idx := 0;

        if logit1 > max_val then max_val := logit1; max_idx := 1; end if;
        if logit2 > max_val then max_val := logit2; max_idx := 2; end if;
        if logit3 > max_val then max_val := logit3; max_idx := 3; end if;
        if logit4 > max_val then max_val := logit4; max_idx := 4; end if;
        if logit5 > max_val then max_val := logit5; max_idx := 5; end if;
        if logit6 > max_val then max_val := logit6; max_idx := 6; end if;
        if logit7 > max_val then max_val := logit7; max_idx := 7; end if;
        if logit8 > max_val then max_val := logit8; max_idx := 8; end if;
        if logit9 > max_val then max_val := logit9; max_idx := 9; end if;

        digit <= std_logic_vector(to_unsigned(max_idx, 4));
    end process;
end architecture;
