library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.package_cnn.all;

entity controlador_cnn_struct is
    port(
        clk   : in  std_logic;
        rst   : in  std_logic;
        start : in  std_logic;

        -- Señales done de cada bloque de procesamiento
        c1_done : in std_logic;
        p1_done : in std_logic;
        c2_done : in std_logic;
        p2_done : in std_logic;
        d1_done : in std_logic;
        lg_done : in std_logic;

        -- Pulsos start hacia cada bloque
        c1_start : out std_logic;
        p1_start : out std_logic;
        c2_start : out std_logic;
        p2_start : out std_logic;
        d1_start : out std_logic;
        lg_start : out std_logic;

        -- Copia Conv1 -> Pool1
        c1_out_addr : out integer range 0 to C1_DEPTH-1;
        p1_in_we    : out std_logic;
        p1_in_addr  : out integer range 0 to C1_DEPTH-1;

        -- Copia Pool1 -> Conv2
        p1_out_addr : out integer range 0 to P1_DEPTH-1;
        c2_in_we    : out std_logic;
        c2_in_addr  : out integer range 0 to P1_DEPTH-1;

        -- Copia Conv2 -> Pool2
        c2_out_addr : out integer range 0 to C2_DEPTH-1;
        p2_in_we    : out std_logic;
        p2_in_addr  : out integer range 0 to C2_DEPTH-1;

        -- Copia Pool2 -> Dense1
        p2_out_addr : out integer range 0 to P2_DEPTH-1;
        d1_in_we    : out std_logic;
        d1_in_addr  : out integer range 0 to P2_DEPTH-1;

        -- Copia Dense1 -> Logits
        d1_out_addr : out integer range 0 to DENSE1_SIZE-1;
        lg_in_we    : out std_logic;
        lg_in_addr  : out integer range 0 to DENSE1_SIZE-1;

        -- Lectura de logits finales
        lg_out_addr : out integer range 0 to LOGITS_SIZE-1;
        logits_we   : out std_logic;
        logits_addr : out integer range 0 to LOGITS_SIZE-1;

        -- Estado general
        done        : out std_logic;
        debug_state : out std_logic_vector(3 downto 0)
    );
end entity;

architecture structural_rtl of controlador_cnn_struct is

    type top_state_t is (
        T_IDLE,

        T_START_C1,
        T_WAIT_C1,
        T_COPY_C1_ADDR,
        T_COPY_C1_WRITE,

        T_START_P1,
        T_WAIT_P1,
        T_COPY_P1_ADDR,
        T_COPY_P1_WRITE,

        T_START_C2,
        T_WAIT_C2,
        T_COPY_C2_ADDR,
        T_COPY_C2_WRITE,

        T_START_P2,
        T_WAIT_P2,
        T_COPY_P2_ADDR,
        T_COPY_P2_WRITE,

        T_START_D1,
        T_WAIT_D1,
        T_COPY_D1_ADDR,
        T_COPY_D1_WRITE,

        T_START_LOGITS,
        T_WAIT_LOGITS,
        T_READ_LOGITS_ADDR,
        T_READ_LOGITS_SAVE,

        T_ARGMAX,
        T_DONE
    );

    signal state : top_state_t := T_IDLE;

    -- Se usa el mayor tamaño de memoria intermedia.
    signal copy_idx : integer range 0 to C1_DEPTH-1 := 0;

begin

    done <= '1' when state = T_DONE else '0';

    process(state)
    begin
        case state is
            when T_IDLE =>
                debug_state <= ST_IDLE;

            when T_START_C1 | T_WAIT_C1 | T_COPY_C1_ADDR | T_COPY_C1_WRITE =>
                debug_state <= ST_CONV1;

            when T_START_P1 | T_WAIT_P1 | T_COPY_P1_ADDR | T_COPY_P1_WRITE =>
                debug_state <= ST_POOL1;

            when T_START_C2 | T_WAIT_C2 | T_COPY_C2_ADDR | T_COPY_C2_WRITE =>
                debug_state <= ST_CONV2;

            when T_START_P2 | T_WAIT_P2 | T_COPY_P2_ADDR | T_COPY_P2_WRITE =>
                debug_state <= ST_POOL2;

            when T_START_D1 | T_WAIT_D1 | T_COPY_D1_ADDR | T_COPY_D1_WRITE =>
                debug_state <= ST_DENSE1;

            when T_START_LOGITS | T_WAIT_LOGITS | T_READ_LOGITS_ADDR | T_READ_LOGITS_SAVE =>
                debug_state <= ST_LOGITS;

            when T_ARGMAX =>
                debug_state <= ST_ARGMAX;

            when T_DONE =>
                debug_state <= ST_DONE;
        end case;
    end process;

    process(clk)
    begin
        if rising_edge(clk) then

            if rst = '1' then
                state    <= T_IDLE;
                copy_idx <= 0;

                c1_start <= '0';
                p1_start <= '0';
                c2_start <= '0';
                p2_start <= '0';
                d1_start <= '0';
                lg_start <= '0';

                p1_in_we  <= '0';
                c2_in_we  <= '0';
                p2_in_we  <= '0';
                d1_in_we  <= '0';
                lg_in_we  <= '0';
                logits_we <= '0';

                c1_out_addr <= 0;
                p1_in_addr  <= 0;
                p1_out_addr <= 0;
                c2_in_addr  <= 0;
                c2_out_addr <= 0;
                p2_in_addr  <= 0;
                p2_out_addr <= 0;
                d1_in_addr  <= 0;
                d1_out_addr <= 0;
                lg_in_addr  <= 0;
                lg_out_addr <= 0;
                logits_addr <= 0;

            else

                -- Valores por defecto: todos los pulsos duran 1 ciclo.
                c1_start <= '0';
                p1_start <= '0';
                c2_start <= '0';
                p2_start <= '0';
                d1_start <= '0';
                lg_start <= '0';

                p1_in_we  <= '0';
                c2_in_we  <= '0';
                p2_in_we  <= '0';
                d1_in_we  <= '0';
                lg_in_we  <= '0';
                logits_we <= '0';

                case state is

                    when T_IDLE =>
                        copy_idx <= 0;
                        if start = '1' then
                            state <= T_START_C1;
                        end if;

                    -- ====================================================
                    -- Conv1
                    -- ====================================================
                    when T_START_C1 =>
                        c1_start <= '1';
                        state <= T_WAIT_C1;

                    when T_WAIT_C1 =>
                        if c1_done = '1' then
                            copy_idx <= 0;
                            state <= T_COPY_C1_ADDR;
                        end if;

                    when T_COPY_C1_ADDR =>
                        c1_out_addr <= copy_idx;
                        p1_in_addr  <= copy_idx;
                        state <= T_COPY_C1_WRITE;

                    when T_COPY_C1_WRITE =>
                        p1_in_we <= '1';

                        if copy_idx < C1_DEPTH-1 then
                            copy_idx <= copy_idx + 1;
                            state <= T_COPY_C1_ADDR;
                        else
                            copy_idx <= 0;
                            state <= T_START_P1;
                        end if;

                    -- ====================================================
                    -- Pool1
                    -- ====================================================
                    when T_START_P1 =>
                        p1_start <= '1';
                        state <= T_WAIT_P1;

                    when T_WAIT_P1 =>
                        if p1_done = '1' then
                            copy_idx <= 0;
                            state <= T_COPY_P1_ADDR;
                        end if;

                    when T_COPY_P1_ADDR =>
                        p1_out_addr <= copy_idx;
                        c2_in_addr  <= copy_idx;
                        state <= T_COPY_P1_WRITE;

                    when T_COPY_P1_WRITE =>
                        c2_in_we <= '1';

                        if copy_idx < P1_DEPTH-1 then
                            copy_idx <= copy_idx + 1;
                            state <= T_COPY_P1_ADDR;
                        else
                            copy_idx <= 0;
                            state <= T_START_C2;
                        end if;

                    -- ====================================================
                    -- Conv2
                    -- ====================================================
                    when T_START_C2 =>
                        c2_start <= '1';
                        state <= T_WAIT_C2;

                    when T_WAIT_C2 =>
                        if c2_done = '1' then
                            copy_idx <= 0;
                            state <= T_COPY_C2_ADDR;
                        end if;

                    when T_COPY_C2_ADDR =>
                        c2_out_addr <= copy_idx;
                        p2_in_addr  <= copy_idx;
                        state <= T_COPY_C2_WRITE;

                    when T_COPY_C2_WRITE =>
                        p2_in_we <= '1';

                        if copy_idx < C2_DEPTH-1 then
                            copy_idx <= copy_idx + 1;
                            state <= T_COPY_C2_ADDR;
                        else
                            copy_idx <= 0;
                            state <= T_START_P2;
                        end if;

                    -- ====================================================
                    -- Pool2
                    -- ====================================================
                    when T_START_P2 =>
                        p2_start <= '1';
                        state <= T_WAIT_P2;

                    when T_WAIT_P2 =>
                        if p2_done = '1' then
                            copy_idx <= 0;
                            state <= T_COPY_P2_ADDR;
                        end if;

                    when T_COPY_P2_ADDR =>
                        p2_out_addr <= copy_idx;
                        d1_in_addr  <= copy_idx;
                        state <= T_COPY_P2_WRITE;

                    when T_COPY_P2_WRITE =>
                        d1_in_we <= '1';

                        if copy_idx < P2_DEPTH-1 then
                            copy_idx <= copy_idx + 1;
                            state <= T_COPY_P2_ADDR;
                        else
                            copy_idx <= 0;
                            state <= T_START_D1;
                        end if;

                    -- ====================================================
                    -- Dense1
                    -- ====================================================
                    when T_START_D1 =>
                        d1_start <= '1';
                        state <= T_WAIT_D1;

                    when T_WAIT_D1 =>
                        if d1_done = '1' then
                            copy_idx <= 0;
                            state <= T_COPY_D1_ADDR;
                        end if;

                    when T_COPY_D1_ADDR =>
                        d1_out_addr <= copy_idx;
                        lg_in_addr  <= copy_idx;
                        state <= T_COPY_D1_WRITE;

                    when T_COPY_D1_WRITE =>
                        lg_in_we <= '1';

                        if copy_idx < DENSE1_SIZE-1 then
                            copy_idx <= copy_idx + 1;
                            state <= T_COPY_D1_ADDR;
                        else
                            copy_idx <= 0;
                            state <= T_START_LOGITS;
                        end if;

                    -- ====================================================
                    -- Logits
                    -- ====================================================
                    when T_START_LOGITS =>
                        lg_start <= '1';
                        state <= T_WAIT_LOGITS;

                    when T_WAIT_LOGITS =>
                        if lg_done = '1' then
                            copy_idx <= 0;
                            state <= T_READ_LOGITS_ADDR;
                        end if;

                    when T_READ_LOGITS_ADDR =>
                        lg_out_addr <= copy_idx;
                        logits_addr <= copy_idx;
                        state <= T_READ_LOGITS_SAVE;

                    when T_READ_LOGITS_SAVE =>
                        logits_we <= '1';

                        if copy_idx < LOGITS_SIZE-1 then
                            copy_idx <= copy_idx + 1;
                            state <= T_READ_LOGITS_ADDR;
                        else
                            copy_idx <= 0;
                            state <= T_ARGMAX;
                        end if;

                    -- ====================================================
                    -- Argmax y finalización
                    -- ====================================================
                    when T_ARGMAX =>
                        state <= T_DONE;

                    when T_DONE =>
                        if start = '0' then
                            state <= T_IDLE;
                        end if;

                end case;
            end if;
        end if;
    end process;

end architecture;