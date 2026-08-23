library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_textio.all;

library std;
use std.textio.all;
use std.env.all;

use work.package_cnn.all;

entity tb_cnn_image_assert is
    generic(
        IMAGE_FILE     : string  := "sim/data/img_000_label_7.hex";
        EXPECTED_DIGIT : integer := 7;
        MAX_CYCLES     : integer := 3000000
    );
end entity;

architecture sim of tb_cnn_image_assert is

    signal clk         : std_logic := '0';
    signal rst         : std_logic := '1';
    signal start       : std_logic := '0';

    signal img_we      : std_logic := '0';
    signal img_addr    : integer range 0 to IMG_DEPTH-1 := 0;
    signal img_din     : s8_t := (others => '0');

    signal done        : std_logic;
    signal digit_out   : std_logic_vector(3 downto 0);
    signal debug_state : std_logic_vector(3 downto 0);

    constant CLK_PERIOD : time := 20 ns; -- 50 MHz

begin

    -- Reloj
    clk <= not clk after CLK_PERIOD/2;

    -- DUT: CNN completa
    dut : entity work.cnn_top
        port map(
            clk         => clk,
            rst         => rst,
            start       => start,

            img_we      => img_we,
            img_addr    => img_addr,
            img_din     => img_din,

            done        => done,
            digit_out   => digit_out,
            debug_state => debug_state
        );

    -- Proceso de prueba
    stim_proc : process
        file img_file      : text open read_mode is IMAGE_FILE;
        variable line_v    : line;
        variable pix_slv   : std_logic_vector(7 downto 0);
        variable pred_int  : integer;
        variable completed : boolean := false;
    begin

        report "==============================================";
        report "INICIO TEST CNN MNIST";
        report "Imagen cargada: " & IMAGE_FILE;
        report "Digito esperado: " & integer'image(EXPECTED_DIGIT);
        report "==============================================";

        -- Reset inicial
        rst <= '1';
        start <= '0';
        img_we <= '0';
        wait for 100 ns;
        wait until rising_edge(clk);

        rst <= '0';
        wait until rising_edge(clk);

        -- Carga de la imagen 28x28 desde archivo .hex
        report "Cargando imagen en RAM de entrada...";

        for i in 0 to IMG_DEPTH-1 loop
            if endfile(img_file) then
                assert false
                    report "ERROR: El archivo de imagen tiene menos de 784 pixeles."
                    severity failure;
            end if;

            readline(img_file, line_v);
            hread(line_v, pix_slv);

            img_addr <= i;
            img_din  <= signed(pix_slv);
            img_we   <= '1';

            wait until rising_edge(clk);
        end loop;

        img_we <= '0';
        wait until rising_edge(clk);

        report "Imagen cargada correctamente.";

        -- Pulso de inicio
        report "Iniciando inferencia CNN...";
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        -- Espera de finalización con timeout
        for cycle_count in 0 to MAX_CYCLES loop
            wait until rising_edge(clk);

            if done = '1' then
                pred_int := to_integer(unsigned(digit_out));
                completed := true;

                report "==============================================";
                report "FIN DE INFERENCIA";
                report "Digito esperado : " & integer'image(EXPECTED_DIGIT);
                report "Digito predicho : " & integer'image(pred_int);
                report "debug_state     : " & integer'image(to_integer(unsigned(debug_state)));
                report "==============================================";

                assert pred_int = EXPECTED_DIGIT
                    report "ERROR: La CNN no reconocio correctamente la imagen."
                    severity error;

                if pred_int = EXPECTED_DIGIT then
                    report "RESULTADO: OK, prediccion correcta.";
                end if;

                stop;
            end if;
        end loop;

        if completed = false then
            assert false
                report "ERROR: Timeout. La CNN no activo done dentro del numero maximo de ciclos."
                severity failure;
        end if;

        wait;
    end process;

end architecture;