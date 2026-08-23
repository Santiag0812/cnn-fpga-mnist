library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.package_cnn.all;

entity relu_unit is
    generic(
        SHIFT_VALUE : integer := 7
    );
    port(
        x_in  : in  acc_t;
        y_out : out s8_t
    );
end entity;

architecture structural_rtl of relu_unit is
begin
    y_out <= relu_clip_shift(x_in, SHIFT_VALUE);
end architecture;
