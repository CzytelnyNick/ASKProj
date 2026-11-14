--------------------------------------------------------------------------------
-- Jednostka arccos(x) z rozbudowaną diagnostyką błędów
-- Błędy:
--   ERR_DOMAIN   – |x| > 1
--   ERR_INTERNAL – 1-x^2 < 0 (niespójność numeryczna)
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ask_types_pkg.all;
use work.cordic_pkg.all;

entity arccos_unit is
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
end entity arccos_unit;

architecture rtl of arccos_unit is

    type state_t is (
        ST_IDLE,
        ST_CHECK,
        ST_EDGE,
        ST_SQ,
        ST_ONE_MINUS,
        ST_SQRT_START,
        ST_SQRT_WAIT,
        ST_ATAN_START,
        ST_ATAN_WAIT,
        ST_NORM,
        ST_DONE
    );
    signal state : state_t := ST_IDLE;

    signal arg_r       : word128_t;
    signal x2          : word128_t;
    signal one_m       : word128_t;
    signal sqrt_arg    : word128_t;
    signal sqrt_res    : word128_t;
    signal atan_res    : word128_t;

    signal sqrt_start  : std_logic := '0';
    signal sqrt_done   : std_logic;
    signal sqrt_busy   : std_logic;
    signal atan_start  : std_logic := '0';
    signal atan_done   : std_logic;
    signal atan_busy   : std_logic;

    signal done_r      : std_logic := '0';
    signal busy_r      : std_logic := '0';
    signal err_r       : std_logic := '0';
    signal errcode_r   : word128_t := ERR_OK;
    signal result_r    : word128_t := (others => '0');

begin

    done    <= done_r;
    busy    <= busy_r;
    err     <= err_r;
    errcode <= errcode_r;
    result  <= result_r;

    u_sqrt : entity work.sqrt_unit
        port map (
            clk    => clk,
            rst    => rst,
            start  => sqrt_start,
            arg_in => sqrt_arg,
            result => sqrt_res,
            done   => sqrt_done,
            busy   => sqrt_busy
        );

    u_atan : entity work.atan_unit
        port map (
            clk    => clk,
            rst    => rst,
            start  => atan_start,
            x_in   => arg_r,
            y_in   => sqrt_res,
            result => atan_res,
            done   => atan_done,
            busy   => atan_busy
        );

    process (clk)
        variable ang : word128_t;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state      <= ST_IDLE;
                done_r     <= '0';
                busy_r     <= '0';
                err_r      <= '0';
                errcode_r  <= ERR_OK;
                result_r   <= (others => '0');
                arg_r      <= (others => '0');
                x2         <= (others => '0');
                one_m      <= (others => '0');
                sqrt_arg   <= (others => '0');
                sqrt_start <= '0';
                atan_start <= '0';
            else
                sqrt_start <= '0';
                atan_start <= '0';

                case state is
                    when ST_IDLE =>
                        done_r <= '0';
                        err_r  <= '0';
                        if start = '1' then
                            busy_r    <= '1';
                            errcode_r <= ERR_OK;
                            arg_r     <= arg_in;
                            state     <= ST_CHECK;
                        end if;

                    when ST_CHECK =>
                        -- Główny błąd dziedziny: arccos tylko dla [-1, 1]
                        if abs_q124(arg_r) > Q_ONE then
                            err_r     <= '1';
                            errcode_r <= ERR_DOMAIN;
                            result_r  <= Q_ZERO;
                            state     <= ST_DONE;
                        elsif abs_q124(arg_r) = Q_ONE then
                            state <= ST_EDGE;
                        else
                            state <= ST_SQ;
                        end if;

                    when ST_EDGE =>
                        if arg_r < 0 then
                            result_r <= Q_PI;
                        else
                            result_r <= Q_ZERO;
                        end if;
                        err_r     <= '0';
                        errcode_r <= ERR_OK;
                        state     <= ST_DONE;

                    when ST_SQ =>
                        x2    <= mul_q124(arg_r, arg_r);
                        state <= ST_ONE_MINUS;

                    when ST_ONE_MINUS =>
                        one_m <= Q_ONE - x2;
                        if (Q_ONE - x2) < 0 then
                            err_r     <= '1';
                            errcode_r <= ERR_INTERNAL;
                            result_r  <= Q_ZERO;
                            state     <= ST_DONE;
                        else
                            sqrt_arg <= Q_ONE - x2;
                            state    <= ST_SQRT_START;
                        end if;

                    when ST_SQRT_START =>
                        sqrt_start <= '1';
                        state      <= ST_SQRT_WAIT;

                    when ST_SQRT_WAIT =>
                        if sqrt_done = '1' then
                            state <= ST_ATAN_START;
                        end if;

                    when ST_ATAN_START =>
                        atan_start <= '1';
                        state      <= ST_ATAN_WAIT;

                    when ST_ATAN_WAIT =>
                        if atan_done = '1' then
                            state <= ST_NORM;
                        end if;

                    when ST_NORM =>
                        ang := atan_res;
                        if ang < 0 then
                            ang := ang + Q_TWO_PI;
                        end if;
                        if ang > Q_PI then
                            ang := Q_TWO_PI - ang;
                        end if;
                        result_r  <= ang;
                        err_r     <= '0';
                        errcode_r <= ERR_OK;
                        state     <= ST_DONE;

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
