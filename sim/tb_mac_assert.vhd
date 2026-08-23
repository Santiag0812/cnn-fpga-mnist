library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.package_cnn.all;

entity tb_mac_assert is
end entity;

architecture sim of tb_mac_assert is
    signal clk       : std_logic := '0';
    signal rst       : std_logic := '1';
    signal clear_acc : std_logic := '0';
    signal enable    : std_logic := '0';
    signal x_in      : s8_t := (others => '0');
    signal w_in      : s8_t := (others => '0');
    signal acc_out   : acc_t;
begin
    clk <= not clk after 10 ns;

    dut : entity work.mac_unit
        port map(clk => clk, rst => rst, clear_acc => clear_acc, enable => enable,
                 x_in => x_in, w_in => w_in, acc_out => acc_out);

    process
    begin
        wait for 30 ns;
        rst <= '0';
        wait until rising_edge(clk);

        clear_acc <= '1';
        wait until rising_edge(clk);
        clear_acc <= '0';

        x_in <= to_signed(3, 8);
        w_in <= to_signed(4, 8);
        enable <= '1';
        wait until rising_edge(clk);

        x_in <= to_signed(-2, 8);
        w_in <= to_signed(5, 8);
        wait until rising_edge(clk);
        enable <= '0';
        wait until rising_edge(clk);

        assert to_integer(acc_out) = 2
            report "ERROR MAC: esperado 2 = 3*4 + (-2)*5"
            severity failure;

        report "OK MAC: assert superado" severity note;
        wait;
    end process;
end architecture;
