library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.package_cnn.all;

entity maxpool2x2 is
    port(
        a      : in  s8_t;
        b      : in  s8_t;
        c      : in  s8_t;
        d      : in  s8_t;
        y_out  : out s8_t
    );
end entity;

architecture structural_rtl of maxpool2x2 is
    signal m1, m2 : s8_t;
begin
    m1 <= a when a >= b else b;
    m2 <= c when c >= d else d;
    y_out <= m1 when m1 >= m2 else m2;
end architecture;
