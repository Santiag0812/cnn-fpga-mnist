library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.package_cnn.all;

entity tb_argmax_assert is
end entity;

architecture sim of tb_argmax_assert is
    signal l0,l1,l2,l3,l4,l5,l6,l7,l8,l9 : s8_t := (others => '0');
    signal digit : std_logic_vector(3 downto 0);
begin
    dut : entity work.argmax10
        port map(logit0=>l0, logit1=>l1, logit2=>l2, logit3=>l3, logit4=>l4,
                 logit5=>l5, logit6=>l6, logit7=>l7, logit8=>l8, logit9=>l9,
                 digit=>digit);

    process
    begin
        l0 <= to_signed(1,8);  l1 <= to_signed(2,8);  l2 <= to_signed(3,8);
        l3 <= to_signed(4,8);  l4 <= to_signed(5,8);  l5 <= to_signed(50,8);
        l6 <= to_signed(7,8);  l7 <= to_signed(8,8);  l8 <= to_signed(9,8);
        l9 <= to_signed(10,8);
        wait for 20 ns;

        assert digit = "0101"
            report "ERROR ARGMAX: esperado digito 5"
            severity failure;

        report "OK ARGMAX: assert superado" severity note;
        wait;
    end process;
end architecture;
