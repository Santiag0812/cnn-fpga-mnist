library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package package_cnn is
    -- ================================================================
    --  Paquete general para CNN MNIST estructural
    --  Formato propuesto:
    --    - pesos y activaciones: int8 signed
    --    - acumuladores MAC: int32 signed
    -- ================================================================

    subtype s8_t  is signed(7 downto 0);
    subtype acc_t is signed(31 downto 0);

    type s8_array_t  is array (natural range <>) of s8_t;
    type acc_array_t is array (natural range <>) of acc_t;

    -- Dimensiones de la red entrenada
    constant IMG_W      : integer := 28;
    constant IMG_H      : integer := 28;
    constant IMG_CH     : integer := 1;

    constant CONV1_OUT_CH : integer := 8;
    constant CONV1_OUT_W  : integer := 26;
    constant CONV1_OUT_H  : integer := 26;

    constant POOL1_OUT_W  : integer := 13;
    constant POOL1_OUT_H  : integer := 13;
    constant POOL1_CH     : integer := 8;

    constant CONV2_OUT_CH : integer := 16;
    constant CONV2_OUT_W  : integer := 11;
    constant CONV2_OUT_H  : integer := 11;

    constant POOL2_OUT_W  : integer := 5;
    constant POOL2_OUT_H  : integer := 5;
    constant POOL2_CH     : integer := 16;

    constant FLAT_SIZE    : integer := 400;
    constant DENSE1_SIZE  : integer := 32;
    constant LOGITS_SIZE  : integer := 10;

    constant IMG_DEPTH    : integer := 28*28*1;
    constant C1_DEPTH     : integer := 26*26*8;
    constant P1_DEPTH     : integer := 13*13*8;
    constant C2_DEPTH     : integer := 11*11*16;
    constant P2_DEPTH     : integer := 5*5*16;

    -- Shifts de requantización. Se ajustan con validación Python/ModelSim.
    constant SHIFT_CONV1  : integer := 7;
    constant SHIFT_CONV2  : integer := 7;
    constant SHIFT_DENSE1 : integer := 7;
    constant SHIFT_LOGITS : integer := 7;

    -- Estados globales simplificados para monitoreo externo
    constant ST_IDLE      : std_logic_vector(3 downto 0) := "0000";
    constant ST_CONV1     : std_logic_vector(3 downto 0) := "0001";
    constant ST_POOL1     : std_logic_vector(3 downto 0) := "0010";
    constant ST_CONV2     : std_logic_vector(3 downto 0) := "0011";
    constant ST_POOL2     : std_logic_vector(3 downto 0) := "0100";
    constant ST_DENSE1    : std_logic_vector(3 downto 0) := "0101";
    constant ST_LOGITS    : std_logic_vector(3 downto 0) := "0110";
    constant ST_ARGMAX    : std_logic_vector(3 downto 0) := "0111";
    constant ST_DONE      : std_logic_vector(3 downto 0) := "1000";

    function clip_s8(v : integer) return s8_t;
    function relu_clip_shift(x : acc_t; shift : integer) return s8_t;
    function signed_clip_shift(x : acc_t; shift : integer) return s8_t;

end package;

package body package_cnn is

    function clip_s8(v : integer) return s8_t is
        variable tmp : integer;
    begin
        tmp := v;
        if tmp > 127 then
            tmp := 127;
        elsif tmp < -128 then
            tmp := -128;
        end if;
        return to_signed(tmp, 8);
    end function;

    function relu_clip_shift(x : acc_t; shift : integer) return s8_t is
        variable val : integer;
        variable divv : integer;
    begin
        val := to_integer(x);
        if val < 0 then
            val := 0;
        end if;
        divv := 1;
        for i in 1 to shift loop
            divv := divv * 2;
        end loop;
        val := val / divv;
        if val > 127 then
            val := 127;
        end if;
        return to_signed(val, 8);
    end function;

    function signed_clip_shift(x : acc_t; shift : integer) return s8_t is
        variable val : integer;
        variable divv : integer;
    begin
        val := to_integer(x);
        divv := 1;
        for i in 1 to shift loop
            divv := divv * 2;
        end loop;
        val := val / divv;
        return clip_s8(val);
    end function;

end package body;
