--------------------------------------------------------------------------------
-- Jednostka obliczeniowa cos(x) – CORDIC + diagnostyka błędów
-- Błędy:
--   ERR_RANGE – |x| > Q_COS_ARG_LIMIT (7.0) lub redukcja kąta nie zbiega
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ask_types_pkg.all;
use work.cordic_pkg.all;

entity cos_unit is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        start    : in  std_logic;
        arg_in   : in  word128_t;
        result   : out word128_t;
        done     : out std_logic;
        busy     : out std_logic;
        err      : out std_logic;
        errcode  : out word128_t
    );
end entity cos_unit;

architecture rtl of cos_unit is

    type state_t is (
        ST_IDLE,
        ST_CHECK,
        ST_REDUCE_POS,
        ST_REDUCE_NEG,
        ST_QUAD,
        ST_INIT,
        ST_ITER,
        ST_DONE
    );
    signal state : state_t := ST_IDLE;

    signal x_reg, y_reg, z_reg : word128_t;
    signal angle               : word128_t;
    signal iter_i              : integer range 0 to CORDIC_ITERS := 0;
    signal reduce_cnt          : integer range 0 to 31 := 0;
    signal sign_neg            : std_logic;
    signal done_r              : std_logic := '0';
    signal busy_r              : std_logic := '0';
    signal err_r               : std_logic := '0';
    signal errcode_r           : word128_t := ERR_OK;
    signal result_r            : word128_t := (others => '0');

    constant REDUCE_MAX : integer := 16;

    function asr(v : word128_t; i : natural) return word128_t is
    begin
        if i = 0 then
            return v;
        else
            return shift_right(v, i);
        end if;
    end function;

begin

    done    <= done_r;
    busy    <= busy_r;
    err     <= err_r;
    errcode <= errcode_r;
    result  <= result_r;

    process (clk)
        variable x_n, y_n, z_n : word128_t;
        variable di_pos        : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state      <= ST_IDLE;
                done_r     <= '0';
                busy_r     <= '0';
                err_r      <= '0';
                errcode_r  <= ERR_OK;
                result_r   <= (others => '0');
                x_reg      <= (others => '0');
                y_reg      <= (others => '0');
                z_reg      <= (others => '0');
                angle      <= (others => '0');
                iter_i     <= 0;
                reduce_cnt <= 0;
                sign_neg   <= '0';
            else
                case state is
                    when ST_IDLE =>
                        done_r <= '0';
                        err_r  <= '0';
                        if start = '1' then
                            busy_r     <= '1';
                            errcode_r  <= ERR_OK;
                            angle      <= arg_in;
                            sign_neg   <= '0';
                            reduce_cnt <= 0;
                            state      <= ST_CHECK;
                        end if;

                    when ST_CHECK =>
                        if abs_q124(angle) > Q_COS_ARG_LIMIT then
                            err_r     <= '1';
                            errcode_r <= ERR_RANGE;
                            result_r  <= Q_ZERO;
                            state     <= ST_DONE;
                        else
                            state <= ST_REDUCE_POS;
                        end if;

                    when ST_REDUCE_POS =>
                        if angle >= Q_PI then
                            if reduce_cnt = REDUCE_MAX then
                                err_r     <= '1';
                                errcode_r <= ERR_RANGE;
                                result_r  <= Q_ZERO;
                                state     <= ST_DONE;
                            else
                                angle      <= angle - Q_TWO_PI;
                                reduce_cnt <= reduce_cnt + 1;
                            end if;
                        else
                            reduce_cnt <= 0;
                            state      <= ST_REDUCE_NEG;
                        end if;

                    when ST_REDUCE_NEG =>
                        if angle < -Q_PI then
                            if reduce_cnt = REDUCE_MAX then
                                err_r     <= '1';
                                errcode_r <= ERR_RANGE;
                                result_r  <= Q_ZERO;
                                state     <= ST_DONE;
                            else
                                angle      <= angle + Q_TWO_PI;
                                reduce_cnt <= reduce_cnt + 1;
                            end if;
                        else
                            state <= ST_QUAD;
                        end if;

                    when ST_QUAD =>
                        if angle > Q_HALF_PI then
                            angle    <= Q_PI - angle;
                            sign_neg <= '1';
                            state    <= ST_INIT;
                        elsif angle < -Q_HALF_PI then
                            angle    <= -Q_PI - angle;
                            sign_neg <= '1';
                            state    <= ST_INIT;
                        else
                            state <= ST_INIT;
                        end if;

                    when ST_INIT =>
                        x_reg  <= CORDIC_INV_K;
                        y_reg  <= Q_ZERO;
                        z_reg  <= angle;
                        iter_i <= 0;
                        state  <= ST_ITER;

                    when ST_ITER =>
                        di_pos := (z_reg >= 0);
                        if di_pos then
                            x_n := x_reg - asr(y_reg, iter_i);
                            y_n := y_reg + asr(x_reg, iter_i);
                            z_n := z_reg - CORDIC_ATAN(iter_i);
                        else
                            x_n := x_reg + asr(y_reg, iter_i);
                            y_n := y_reg - asr(x_reg, iter_i);
                            z_n := z_reg + CORDIC_ATAN(iter_i);
                        end if;
                        x_reg <= x_n;
                        y_reg <= y_n;
                        z_reg <= z_n;

                        if iter_i = CORDIC_ITERS - 1 then
                            if sign_neg = '1' then
                                result_r <= -x_n;
                            else
                                result_r <= x_n;
                            end if;
                            err_r     <= '0';
                            errcode_r <= ERR_OK;
                            state     <= ST_DONE;
                        else
                            iter_i <= iter_i + 1;
                        end if;

                    when ST_DONE =>
                        done_r <= '1';
                        busy_r <= '0';
                        state  <= ST_IDLE;

                    when others =>
                        state <= ST_IDLE;
                end case;
            end if;
        end if;
    end process;

end architecture rtl;
