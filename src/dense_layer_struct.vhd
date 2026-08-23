library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.package_cnn.all;

entity dense_layer_struct is
    generic(
        IN_SIZE     : integer := 400;
        OUT_SIZE    : integer := 32;
        SHIFT_VALUE : integer := 7;
        APPLY_RELU  : boolean := true;
        WEIGHT_FILE : string  := "mem/dense1_kernel_int8.hex";
        BIAS_FILE   : string  := "mem/dense1_bias_int8.hex"
    );
    port(
        clk         : in  std_logic;
        rst         : in  std_logic;
        start       : in  std_logic;
        busy        : out std_logic;
        done        : out std_logic;

        in_we       : in  std_logic;
        in_addr     : in  integer range 0 to IN_SIZE-1;
        in_din      : in  s8_t;

        out_rd_addr : in  integer range 0 to OUT_SIZE-1;
        out_dout    : out s8_t;

        dbg_neuron  : out integer range 0 to OUT_SIZE-1;
        dbg_acc     : out acc_t
    );
end entity;

architecture structural of dense_layer_struct is
    constant WEIGHT_DEPTH : integer := IN_SIZE*OUT_SIZE;

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

    signal input_mem  : s8_array_t(0 to IN_SIZE-1)  := (others => (others => '0'));
    signal output_mem : s8_array_t(0 to OUT_SIZE-1) := (others => (others => '0'));
    signal weights    : s8_array_t(0 to WEIGHT_DEPTH-1) := init_s8_hex(WEIGHT_FILE, WEIGHT_DEPTH);
    signal bias       : s8_array_t(0 to OUT_SIZE-1)     := init_s8_hex(BIAS_FILE, OUT_SIZE);

    type state_t is (S_IDLE, S_CLEAR, S_MAC, S_STORE, S_NEXT, S_DONE);
    signal state : state_t := S_IDLE;

    signal neuron : integer range 0 to OUT_SIZE-1 := 0;
    signal idx    : integer range 0 to IN_SIZE-1  := 0;

    signal mac_clear : std_logic := '0';
    signal mac_en    : std_logic := '0';
    signal mac_x     : s8_t := (others => '0');
    signal mac_w     : s8_t := (others => '0');
    signal mac_acc   : acc_t;

    function weight_index(i : integer; n : integer) return integer is
    begin
        -- Orden Keras/TensorFlow Dense: kernel[input][output]
        return i*OUT_SIZE + n;
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

    out_dout <= output_mem(out_rd_addr);
    busy <= '1' when state /= S_IDLE and state /= S_DONE else '0';
    done <= '1' when state = S_DONE else '0';
    dbg_neuron <= neuron;
    dbg_acc <= mac_acc;

    process(clk)
        variable acc_with_bias : acc_t;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state <= S_IDLE;
                neuron <= 0;
                idx <= 0;
                mac_clear <= '0';
                mac_en <= '0';
            else
                if in_we = '1' then
                    input_mem(in_addr) <= in_din;
                end if;

                mac_clear <= '0';
                mac_en <= '0';

                case state is
                    when S_IDLE =>
                        if start = '1' then
                            neuron <= 0;
                            idx <= 0;
                            state <= S_CLEAR;
                        end if;

                    when S_CLEAR =>
                        mac_clear <= '1';
                        idx <= 0;
                        state <= S_MAC;

                    when S_MAC =>
                        mac_x <= input_mem(idx);
                        mac_w <= weights(weight_index(idx, neuron));
                        mac_en <= '1';
                        if idx < IN_SIZE-1 then
                            idx <= idx + 1;
                        else
                            state <= S_STORE;
                        end if;

                    when S_STORE =>
                        acc_with_bias := mac_acc + resize(bias(neuron), 32);
                        if APPLY_RELU then
                            output_mem(neuron) <= relu_clip_shift(acc_with_bias, SHIFT_VALUE);
                        else
                            output_mem(neuron) <= signed_clip_shift(acc_with_bias, SHIFT_VALUE);
                        end if;
                        state <= S_NEXT;

                    when S_NEXT =>
                        if neuron < OUT_SIZE-1 then
                            neuron <= neuron + 1;
                            state <= S_CLEAR;
                        else
                            state <= S_DONE;
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
