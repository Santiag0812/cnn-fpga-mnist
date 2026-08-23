library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.package_cnn.all;

entity mac_unit is
    port(
        clk       : in  std_logic;
        rst       : in  std_logic;
        clear_acc : in  std_logic;
        enable    : in  std_logic;
        x_in      : in  s8_t;
        w_in      : in  s8_t;
        acc_out   : out acc_t
    );
end entity;

architecture structural_rtl of mac_unit is
    signal acc_reg : acc_t := (others => '0');
begin
    process(clk)
        variable prod : signed(15 downto 0);
    begin
        if rising_edge(clk) then
            if rst = '1' or clear_acc = '1' then
                acc_reg <= (others => '0');
            elsif enable = '1' then
                prod := x_in * w_in;
                acc_reg <= acc_reg + resize(prod, 32);
            end if;
        end if;
    end process;

    acc_out <= acc_reg;
end architecture;
