library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.package_cnn.all;

entity conv3x3_layer_struct is
    generic(
        IN_W        : integer := 28;
        IN_H        : integer := 28;
        IN_CH       : integer := 1;
        OUT_CH      : integer := 8;
        SHIFT_VALUE : integer := 7;
        WEIGHT_FILE : string  := "mem/conv1_kernel_int8.hex";
        BIAS_FILE   : string  := "mem/conv1_bias_int8.hex"
    );
    port(
        clk         : in  std_logic;
        rst         : in  std_logic;
        start       : in  std_logic;
        busy        : out std_logic;
        done        : out std_logic;

        -- Puerto de escritura para cargar la memoria de entrada de esta capa
        in_we       : in  std_logic;
        in_addr     : in  integer range 0 to IN_W*IN_H*IN_CH-1;
        in_din      : in  s8_t;

        -- Puerto de lectura de la memoria de salida de esta capa
        out_rd_addr : in  integer range 0 to (IN_W-2)*(IN_H-2)*OUT_CH-1;
        out_dout    : out s8_t;

        -- Señales de depuración para waveform/RTL
        dbg_oc      : out integer range 0 to OUT_CH-1;
        dbg_x       : out integer range 0 to IN_W-3;
        dbg_y       : out integer range 0 to IN_H-3;
        dbg_acc     : out acc_t
    );
end entity;

architecture structural of conv3x3_layer_struct is
    constant OUT_W        : integer := IN_W - 2;
    constant OUT_H        : integer := IN_H - 2;
    constant INPUT_DEPTH  : integer := IN_W*IN_H*IN_CH;
    constant OUTPUT_DEPTH : integer := OUT_W*OUT_H*OUT_CH;
    constant WEIGHT_DEPTH : integer := 3*3*IN_CH*OUT_CH;

    impure function init_s8_hex(file_name : string; depth : natural) return s8_array_t is
        file f       : text open read_mode is file_name;
        variable l   : line;
        variable slv : std_logic_vector(7 downto 0);
        variable mem : s8_array_t(0 to depth-1) := (others => (others => '0'));
    begin
        for i in 0 to integer(depth)-1 loop
            if not endfile(f) then
                readline(f, l);
                hread(l, slv);
                mem(i) := signed(slv);
            else
                mem(i) := (others => '0');
            end if;
        end loop;
        return mem;
    end function;

    signal input_mem  : s8_array_t(0 to INPUT_DEPTH-1)  := (others => (others => '0'));
    signal output_mem : s8_array_t(0 to OUTPUT_DEPTH-1) := (others => (others => '0'));
    signal weights    : s8_array_t(0 to WEIGHT_DEPTH-1) := init_s8_hex(WEIGHT_FILE, WEIGHT_DEPTH);
    signal bias       : s8_array_t(0 to OUT_CH-1)       := init_s8_hex(BIAS_FILE, OUT_CH);

    type state_t is (S_IDLE, S_CLEAR, S_MAC, S_STORE, S_NEXT, S_DONE);
    signal state : state_t := S_IDLE;

    signal ox : integer range 0 to OUT_W-1 := 0;
    signal oy : integer range 0 to OUT_H-1 := 0;
    signal oc : integer range 0 to OUT_CH-1 := 0;
    signal ic : integer range 0 to IN_CH-1 := 0;
    signal kx : integer range 0 to 2 := 0;
    signal ky : integer range 0 to 2 := 0;

    signal mac_clear : std_logic := '0';
    signal mac_en    : std_logic := '0';
    signal mac_x     : s8_t := (others => '0');
    signal mac_w     : s8_t := (others => '0');
    signal mac_acc   : acc_t;
    signal relu_in   : acc_t := (others => '0');
    signal relu_out  : s8_t;

    function input_index(y : integer; x : integer; ch : integer) return integer is
    begin
        return ((y * IN_W + x) * IN_CH) + ch;
    end function;

    function weight_index(ky_i : integer; kx_i : integer; ic_i : integer; oc_i : integer) return integer is
    begin
        -- Orden compatible con Keras/TensorFlow: kernel[ky][kx][in_ch][out_ch]
        return (((ky_i * 3 + kx_i) * IN_CH + ic_i) * OUT_CH) + oc_i;
    end function;

    function output_index(y : integer; x : integer; ch : integer) return integer is
    begin
        return ((y * OUT_W + x) * OUT_CH) + ch;
    end function;

begin
    u_mac : entity work.mac_unit
        port map(
            clk       => clk,
            rst       => rst,
            clear_acc => mac_clear,
            enable    => mac_en,
            x_in      => mac_x,
            w_in      => mac_w,
            acc_out   => mac_acc
        );

    u_relu : entity work.relu_unit
        generic map(SHIFT_VALUE => SHIFT_VALUE)
        port map(
            x_in  => relu_in,
            y_out => relu_out
        );

    out_dout <= output_mem(out_rd_addr);
    busy     <= '1' when state /= S_IDLE and state /= S_DONE else '0';
    done     <= '1' when state = S_DONE else '0';
    dbg_oc   <= oc;
    dbg_x    <= ox;
    dbg_y    <= oy;
    dbg_acc  <= mac_acc;

    process(clk)
        variable acc_with_bias : acc_t;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= S_IDLE;
                ox <= 0; oy <= 0; oc <= 0; ic <= 0; kx <= 0; ky <= 0;
                mac_clear <= '0';
                mac_en <= '0';
                relu_in <= (others => '0');
            else
                if in_we = '1' then
                    input_mem(in_addr) <= in_din;
                end if;

                mac_clear <= '0';
                mac_en <= '0';

                case state is
                    when S_IDLE =>
                        if start = '1' then
                            ox <= 0; oy <= 0; oc <= 0; ic <= 0; kx <= 0; ky <= 0;
                            state <= S_CLEAR;
                        end if;

                    when S_CLEAR =>
                        mac_clear <= '1';
                        state <= S_MAC;

                    when S_MAC =>
                        mac_x <= input_mem(input_index(oy + ky, ox + kx, ic));
                        mac_w <= weights(weight_index(ky, kx, ic, oc));
                        mac_en <= '1';

                        -- Avance de indices de la ventana 3x3xIN_CH
                        if kx < 2 then
                            kx <= kx + 1;
                        else
                            kx <= 0;
                            if ky < 2 then
                                ky <= ky + 1;
                            else
                                ky <= 0;
                                if ic < IN_CH-1 then
                                    ic <= ic + 1;
                                else
                                    ic <= 0;
                                    state <= S_STORE;
                                end if;
                            end if;
                        end if;

                    when S_STORE =>
                        acc_with_bias := mac_acc + resize(bias(oc), 32);
                        relu_in <= acc_with_bias;
                        output_mem(output_index(oy, ox, oc)) <= relu_clip_shift(acc_with_bias, SHIFT_VALUE);
                        state <= S_NEXT;

                    when S_NEXT =>
                        if oc < OUT_CH-1 then
                            oc <= oc + 1;
                            state <= S_CLEAR;
                        else
                            oc <= 0;
                            if ox < OUT_W-1 then
                                ox <= ox + 1;
                                state <= S_CLEAR;
                            else
                                ox <= 0;
                                if oy < OUT_H-1 then
                                    oy <= oy + 1;
                                    state <= S_CLEAR;
                                else
                                    state <= S_DONE;
                                end if;
                            end if;
                        end if;

                    when S_DONE =>
                        if start = '0' then
                            state <= S_IDLE;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
