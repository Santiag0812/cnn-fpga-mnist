library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.package_cnn.all;

entity cnn_top is
    port(
        clk         : in  std_logic;
        rst         : in  std_logic;
        start       : in  std_logic;

        -- Carga externa de imagen 28x28, un pixel por ciclo.
        img_we      : in  std_logic;
        img_addr    : in  integer range 0 to IMG_DEPTH-1;
        img_din     : in  s8_t;

        done        : out std_logic;
        digit_out   : out std_logic_vector(3 downto 0);
        debug_state : out std_logic_vector(3 downto 0)
    );
end entity;

architecture structural of cnn_top is

    -- ================================================================
    -- Señales de control entre el controlador y las capas
    -- ================================================================

    signal c1_start, c1_busy, c1_done : std_logic := '0';
    signal p1_start, p1_busy, p1_done : std_logic := '0';
    signal c2_start, c2_busy, c2_done : std_logic := '0';
    signal p2_start, p2_busy, p2_done : std_logic := '0';
    signal d1_start, d1_busy, d1_done : std_logic := '0';
    signal lg_start, lg_busy, lg_done : std_logic := '0';

    -- ================================================================
    -- Conv1 -> Pool1
    -- ================================================================

    signal c1_out_addr : integer range 0 to C1_DEPTH-1 := 0;
    signal c1_out_data : s8_t := (others => '0');

    signal p1_in_we   : std_logic := '0';
    signal p1_in_addr : integer range 0 to C1_DEPTH-1 := 0;
    signal p1_in_data : s8_t := (others => '0');

    -- ================================================================
    -- Pool1 -> Conv2
    -- ================================================================

    signal p1_out_addr : integer range 0 to P1_DEPTH-1 := 0;
    signal p1_out_data : s8_t := (others => '0');

    signal c2_in_we   : std_logic := '0';
    signal c2_in_addr : integer range 0 to P1_DEPTH-1 := 0;
    signal c2_in_data : s8_t := (others => '0');

    -- ================================================================
    -- Conv2 -> Pool2
    -- ================================================================

    signal c2_out_addr : integer range 0 to C2_DEPTH-1 := 0;
    signal c2_out_data : s8_t := (others => '0');

    signal p2_in_we   : std_logic := '0';
    signal p2_in_addr : integer range 0 to C2_DEPTH-1 := 0;
    signal p2_in_data : s8_t := (others => '0');

    -- ================================================================
    -- Pool2 -> Dense1
    -- ================================================================

    signal p2_out_addr : integer range 0 to P2_DEPTH-1 := 0;
    signal p2_out_data : s8_t := (others => '0');

    signal d1_in_we   : std_logic := '0';
    signal d1_in_addr : integer range 0 to P2_DEPTH-1 := 0;
    signal d1_in_data : s8_t := (others => '0');

    -- ================================================================
    -- Dense1 -> Logits
    -- ================================================================

    signal d1_out_addr : integer range 0 to DENSE1_SIZE-1 := 0;
    signal d1_out_data : s8_t := (others => '0');

    signal lg_in_we   : std_logic := '0';
    signal lg_in_addr : integer range 0 to DENSE1_SIZE-1 := 0;
    signal lg_in_data : s8_t := (others => '0');

    -- ================================================================
    -- Logits -> Argmax
    -- ================================================================

    signal lg_out_addr : integer range 0 to LOGITS_SIZE-1 := 0;
    signal lg_out_data : s8_t := (others => '0');

    signal logits_local : s8_array_t(0 to LOGITS_SIZE-1) := (others => (others => '0'));
    signal logits_we    : std_logic := '0';
    signal logits_addr  : integer range 0 to LOGITS_SIZE-1 := 0;

    signal digit_int : std_logic_vector(3 downto 0);

    -- ================================================================
    -- Señales de depuración internas.
    -- Sirven para ModelSim/waveform, pero no son salidas externas.
    -- ================================================================

    signal c1_dbg_acc : acc_t;
    signal c2_dbg_acc : acc_t;
    signal d1_dbg_acc : acc_t;
    signal lg_dbg_acc : acc_t;

    signal c1_dbg_oc : integer range 0 to CONV1_OUT_CH-1;
    signal c2_dbg_oc : integer range 0 to CONV2_OUT_CH-1;

    signal c1_dbg_x  : integer range 0 to CONV1_OUT_W-1;
    signal c1_dbg_y  : integer range 0 to CONV1_OUT_H-1;
    signal c2_dbg_x  : integer range 0 to CONV2_OUT_W-1;
    signal c2_dbg_y  : integer range 0 to CONV2_OUT_H-1;

    signal p1_dbg_x  : integer range 0 to POOL1_OUT_W-1;
    signal p1_dbg_y  : integer range 0 to POOL1_OUT_H-1;
    signal p2_dbg_x  : integer range 0 to POOL2_OUT_W-1;
    signal p2_dbg_y  : integer range 0 to POOL2_OUT_H-1;

    signal d1_dbg_neuron : integer range 0 to DENSE1_SIZE-1;
    signal lg_dbg_neuron : integer range 0 to LOGITS_SIZE-1;

begin

    -- ================================================================
    -- Data path simple entre bloques.
    -- El controlador solo mueve direcciones y enables.
    -- Los datos se conectan aquí de forma estructural.
    -- ================================================================

    p1_in_data <= c1_out_data;
    c2_in_data <= p1_out_data;
    p2_in_data <= c2_out_data;
    d1_in_data <= p2_out_data;
    lg_in_data <= d1_out_data;

    digit_out <= digit_int;

    -- Registro local de los 10 logits finales para Argmax.
    process(clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                logits_local <= (others => (others => '0'));
            elsif logits_we = '1' then
                logits_local(logits_addr) <= lg_out_data;
            end if;
        end if;
    end process;

    -- ================================================================
    -- CONTROLADOR GENERAL DE LA CNN
    -- Este bloque reemplaza la FSM que antes estaba dentro de cnn_top.
    -- Así el top queda más estructural y más limpio.
    -- ================================================================

    u_ctrl : entity work.controlador_cnn_struct
        port map(
            clk   => clk,
            rst   => rst,
            start => start,

            c1_done => c1_done,
            p1_done => p1_done,
            c2_done => c2_done,
            p2_done => p2_done,
            d1_done => d1_done,
            lg_done => lg_done,

            c1_start => c1_start,
            p1_start => p1_start,
            c2_start => c2_start,
            p2_start => p2_start,
            d1_start => d1_start,
            lg_start => lg_start,

            c1_out_addr => c1_out_addr,
            p1_in_we    => p1_in_we,
            p1_in_addr  => p1_in_addr,

            p1_out_addr => p1_out_addr,
            c2_in_we    => c2_in_we,
            c2_in_addr  => c2_in_addr,

            c2_out_addr => c2_out_addr,
            p2_in_we    => p2_in_we,
            p2_in_addr  => p2_in_addr,

            p2_out_addr => p2_out_addr,
            d1_in_we    => d1_in_we,
            d1_in_addr  => d1_in_addr,

            d1_out_addr => d1_out_addr,
            lg_in_we    => lg_in_we,
            lg_in_addr  => lg_in_addr,

            lg_out_addr => lg_out_addr,
            logits_we   => logits_we,
            logits_addr => logits_addr,

            done        => done,
            debug_state => debug_state
        );

    -- ================================================================
    -- CAPA 1: CONVOLUCIÓN 3x3, 8 FILTROS + ReLU
    -- Entrada: 28x28x1
    -- Salida : 26x26x8
    -- ================================================================

    u_conv1 : entity work.conv3x3_layer_struct
        generic map(
            IN_W        => 28,
            IN_H        => 28,
            IN_CH       => 1,
            OUT_CH      => 8,
            SHIFT_VALUE => SHIFT_CONV1,
            WEIGHT_FILE => "mem/conv1_kernel_int8.hex",
            BIAS_FILE   => "mem/conv1_bias_int8.hex"
        )
        port map(
            clk         => clk,
            rst         => rst,
            start       => c1_start,
            busy        => c1_busy,
            done        => c1_done,

            in_we       => img_we,
            in_addr     => img_addr,
            in_din      => img_din,

            out_rd_addr => c1_out_addr,
            out_dout    => c1_out_data,

            dbg_oc      => c1_dbg_oc,
            dbg_x       => c1_dbg_x,
            dbg_y       => c1_dbg_y,
            dbg_acc     => c1_dbg_acc
        );

    -- ================================================================
    -- POOLING 1: MaxPooling 2x2
    -- Entrada: 26x26x8
    -- Salida : 13x13x8
    -- ================================================================

    u_pool1 : entity work.maxpool_layer_struct
        generic map(
            IN_W => 26,
            IN_H => 26,
            CH   => 8
        )
        port map(
            clk         => clk,
            rst         => rst,
            start       => p1_start,
            busy        => p1_busy,
            done        => p1_done,

            in_we       => p1_in_we,
            in_addr     => p1_in_addr,
            in_din      => p1_in_data,

            out_rd_addr => p1_out_addr,
            out_dout    => p1_out_data,

            dbg_x       => p1_dbg_x,
            dbg_y       => p1_dbg_y
        );

    -- ================================================================
    -- CAPA 2: CONVOLUCIÓN 3x3, 16 FILTROS + ReLU
    -- Entrada: 13x13x8
    -- Salida : 11x11x16
    -- ================================================================

    u_conv2 : entity work.conv3x3_layer_struct
        generic map(
            IN_W        => 13,
            IN_H        => 13,
            IN_CH       => 8,
            OUT_CH      => 16,
            SHIFT_VALUE => SHIFT_CONV2,
            WEIGHT_FILE => "mem/conv2_kernel_int8.hex",
            BIAS_FILE   => "mem/conv2_bias_int8.hex"
        )
        port map(
            clk         => clk,
            rst         => rst,
            start       => c2_start,
            busy        => c2_busy,
            done        => c2_done,

            in_we       => c2_in_we,
            in_addr     => c2_in_addr,
            in_din      => c2_in_data,

            out_rd_addr => c2_out_addr,
            out_dout    => c2_out_data,

            dbg_oc      => c2_dbg_oc,
            dbg_x       => c2_dbg_x,
            dbg_y       => c2_dbg_y,
            dbg_acc     => c2_dbg_acc
        );

    -- ================================================================
    -- POOLING 2: MaxPooling 2x2
    -- Entrada: 11x11x16
    -- Salida : 5x5x16
    -- ================================================================

    u_pool2 : entity work.maxpool_layer_struct
        generic map(
            IN_W => 11,
            IN_H => 11,
            CH   => 16
        )
        port map(
            clk         => clk,
            rst         => rst,
            start       => p2_start,
            busy        => p2_busy,
            done        => p2_done,

            in_we       => p2_in_we,
            in_addr     => p2_in_addr,
            in_din      => p2_in_data,

            out_rd_addr => p2_out_addr,
            out_dout    => p2_out_data,

            dbg_x       => p2_dbg_x,
            dbg_y       => p2_dbg_y
        );

    -- ================================================================
    -- DENSE 1: 400 -> 32 + ReLU
    -- ================================================================

    u_dense1 : entity work.dense_layer_struct
        generic map(
            IN_SIZE     => 400,
            OUT_SIZE    => 32,
            SHIFT_VALUE => SHIFT_DENSE1,
            APPLY_RELU  => true,
            WEIGHT_FILE => "mem/dense1_kernel_int8.hex",
            BIAS_FILE   => "mem/dense1_bias_int8.hex"
        )
        port map(
            clk         => clk,
            rst         => rst,
            start       => d1_start,
            busy        => d1_busy,
            done        => d1_done,

            in_we       => d1_in_we,
            in_addr     => d1_in_addr,
            in_din      => d1_in_data,

            out_rd_addr => d1_out_addr,
            out_dout    => d1_out_data,

            dbg_neuron  => d1_dbg_neuron,
            dbg_acc     => d1_dbg_acc
        );

    -- ================================================================
    -- LOGITS: 32 -> 10
    -- No usa ReLU. La salida se compara con Argmax.
    -- ================================================================

    u_logits : entity work.dense_layer_struct
        generic map(
            IN_SIZE     => 32,
            OUT_SIZE    => 10,
            SHIFT_VALUE => SHIFT_LOGITS,
            APPLY_RELU  => false,
            WEIGHT_FILE => "mem/logits_kernel_int8.hex",
            BIAS_FILE   => "mem/logits_bias_int8.hex"
        )
        port map(
            clk         => clk,
            rst         => rst,
            start       => lg_start,
            busy        => lg_busy,
            done        => lg_done,

            in_we       => lg_in_we,
            in_addr     => lg_in_addr,
            in_din      => lg_in_data,

            out_rd_addr => lg_out_addr,
            out_dout    => lg_out_data,

            dbg_neuron  => lg_dbg_neuron,
            dbg_acc     => lg_dbg_acc
        );

    -- ================================================================
    -- ARGMAX FINAL
    -- Recibe los 10 logits y entrega el dígito ganador.
    -- ================================================================

    u_argmax : entity work.argmax10
        port map(
            logit0 => logits_local(0),
            logit1 => logits_local(1),
            logit2 => logits_local(2),
            logit3 => logits_local(3),
            logit4 => logits_local(4),
            logit5 => logits_local(5),
            logit6 => logits_local(6),
            logit7 => logits_local(7),
            logit8 => logits_local(8),
            logit9 => logits_local(9),
            digit  => digit_int
        );

end architecture;