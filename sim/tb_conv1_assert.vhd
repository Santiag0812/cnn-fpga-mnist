library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.package_cnn.all;

entity tb_conv1_assert is
end entity;

architecture sim of tb_conv1_assert is
    signal clk   : std_logic := '0';
    signal rst   : std_logic := '1';
    signal start : std_logic := '0';
    signal busy  : std_logic;
    signal done  : std_logic;

    signal in_we   : std_logic := '0';
    signal in_addr : integer range 0 to IMG_DEPTH-1 := 0;
    signal in_din  : s8_t := (others => '0');

    signal out_addr : integer range 0 to C1_DEPTH-1 := 0;
    signal out_data : s8_t;

    signal dbg_oc : integer range 0 to CONV1_OUT_CH-1;
    signal dbg_x  : integer range 0 to CONV1_OUT_W-1;
    signal dbg_y  : integer range 0 to CONV1_OUT_H-1;
    signal dbg_acc : acc_t;
begin
    clk <= not clk after 10 ns;

    dut : entity work.conv3x3_layer_struct
        generic map(
            IN_W => 28, IN_H => 28, IN_CH => 1, OUT_CH => 8,
            SHIFT_VALUE => SHIFT_CONV1,
            WEIGHT_FILE => "mem/conv1_kernel_int8.hex",
            BIAS_FILE   => "mem/conv1_bias_int8.hex"
        )
        port map(
            clk => clk, rst => rst, start => start, busy => busy, done => done,
            in_we => in_we, in_addr => in_addr, in_din => in_din,
            out_rd_addr => out_addr, out_dout => out_data,
            dbg_oc => dbg_oc, dbg_x => dbg_x, dbg_y => dbg_y, dbg_acc => dbg_acc
        );

    process
    begin
        wait for 40 ns;
        rst <= '0';

        -- Cargar imagen simple: todos los pixeles en 1.
        for i in 0 to IMG_DEPTH-1 loop
            wait until rising_edge(clk);
            in_we <= '1';
            in_addr <= i;
            in_din <= to_signed(1, 8);
        end loop;
        wait until rising_edge(clk);
        in_we <= '0';

        -- Ejecutar Conv1.
        wait until rising_edge(clk);
        start <= '1';
        wait until rising_edge(clk);
        start <= '0';

        wait until done = '1';
        wait for 40 ns;

        -- Con los archivos .hex incluidos de ejemplo, todos los pesos son cero.
        -- Si copias pesos reales, este assert se debe reemplazar por el esperado
        -- generado desde Python para esa imagen y esos pesos.
        out_addr <= 0;
        wait for 20 ns;
        assert out_data = to_signed(0, 8)
            report "ERROR CONV1: con pesos dummy cero, la primera salida debe ser 0"
            severity failure;

        report "OK CONV1: assert superado con pesos dummy cero" severity note;
        wait;
    end process;
end architecture;
