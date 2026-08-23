library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.package_cnn.all;

entity maxpool_layer_struct is
    generic(
        IN_W  : integer := 26;
        IN_H  : integer := 26;
        CH    : integer := 8
    );
    port(
        clk         : in  std_logic;
        rst         : in  std_logic;
        start       : in  std_logic;
        busy        : out std_logic;
        done        : out std_logic;

        in_we       : in  std_logic;
        in_addr     : in  integer range 0 to IN_W*IN_H*CH-1;
        in_din      : in  s8_t;

        out_rd_addr : in  integer range 0 to (IN_W/2)*(IN_H/2)*CH-1;
        out_dout    : out s8_t;

        dbg_x       : out integer range 0 to (IN_W/2)-1;
        dbg_y       : out integer range 0 to (IN_H/2)-1
    );
end entity;

architecture structural of maxpool_layer_struct is

    constant OUT_W        : integer := IN_W/2;
    constant OUT_H        : integer := IN_H/2;
    constant INPUT_DEPTH  : integer := IN_W*IN_H*CH;
    constant OUTPUT_DEPTH : integer := OUT_W*OUT_H*CH;

    signal input_mem  : s8_array_t(0 to INPUT_DEPTH-1)  := (others => (others => '0'));
    signal output_mem : s8_array_t(0 to OUTPUT_DEPTH-1) := (others => (others => '0'));

    type state_t is (S_IDLE, S_POOL, S_WAIT_MAX, S_STORE, S_DONE);
    signal state : state_t := S_IDLE;

    signal ox : integer range 0 to OUT_W-1 := 0;
    signal oy : integer range 0 to OUT_H-1 := 0;

    -- IMPORTANTE:
    -- No se puede llamar "ch" porque el generic se llama "CH".
    -- VHDL no diferencia mayúsculas/minúsculas.
    signal channel_idx : integer range 0 to CH-1 := 0;

    signal p_a : s8_t := (others => '0');
    signal p_b : s8_t := (others => '0');
    signal p_c : s8_t := (others => '0');
    signal p_d : s8_t := (others => '0');
    signal p_y : s8_t := (others => '0');

    function input_index(y : integer; x : integer; channel : integer) return integer is
    begin
        return ((y * IN_W + x) * CH) + channel;
    end function;

    function output_index(y : integer; x : integer; channel : integer) return integer is
    begin
        return ((y * OUT_W + x) * CH) + channel;
    end function;

begin

    -- Bloque estructural reutilizable de MaxPooling 2x2.
    U_MAXPOOL2X2 : entity work.maxpool2x2
        port map(
            a     => p_a,
            b     => p_b,
            c     => p_c,
            d     => p_d,
            y_out => p_y
        );

    out_dout <= output_mem(out_rd_addr);

    busy <= '1' when state /= S_IDLE and state /= S_DONE else '0';
    done <= '1' when state = S_DONE else '0';

    dbg_x <= ox;
    dbg_y <= oy;

    process(clk)
    begin
        if rising_edge(clk) then

            if rst = '1' then
                state       <= S_IDLE;
                ox          <= 0;
                oy          <= 0;
                channel_idx <= 0;

            else

                -- Escritura externa de datos de entrada.
                -- cnn_top usa esto para pasar la salida de Conv hacia Pool.
                if in_we = '1' then
                    input_mem(in_addr) <= in_din;
                end if;

                case state is

                    when S_IDLE =>
                        if start = '1' then
                            ox          <= 0;
                            oy          <= 0;
                            channel_idx <= 0;
                            state       <= S_POOL;
                        end if;

                    when S_POOL =>
                        -- Lectura de la ventana 2x2.
                        p_a <= input_mem(input_index(2*oy,     2*ox,     channel_idx));
                        p_b <= input_mem(input_index(2*oy,     2*ox + 1, channel_idx));
                        p_c <= input_mem(input_index(2*oy + 1, 2*ox,     channel_idx));
                        p_d <= input_mem(input_index(2*oy + 1, 2*ox + 1, channel_idx));

                        -- Se da un ciclo para que p_y se actualice por el maxpool2x2.
                        state <= S_WAIT_MAX;

                    when S_WAIT_MAX =>
                        state <= S_STORE;

                    when S_STORE =>
                        output_mem(output_index(oy, ox, channel_idx)) <= p_y;

                        if channel_idx < CH-1 then
                            channel_idx <= channel_idx + 1;
                            state <= S_POOL;
                        else
                            channel_idx <= 0;

                            if ox < OUT_W-1 then
                                ox <= ox + 1;
                                state <= S_POOL;
                            else
                                ox <= 0;

                                if oy < OUT_H-1 then
                                    oy <= oy + 1;
                                    state <= S_POOL;
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