--------------------------------------------------------------------------------
-- Jednostka obliczeniowa sin(x) – algorytm CORDIC (tryb rotacji kołowej)
-- Argument i wynik: signed Q4.124 (128 bitów)
-- Wejście: kąt w radianach; wyjście: sin(x) w [-1, 1]
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ask_types_pkg.all;
use work.cordic_pkg.all;

entity sin_unit is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        start    : in  std_logic;
        arg_in   : in  word128_t;
        result   : out word128_t;
        done     : out std_logic;
        busy     : out std_logic
    );
end entity sin_unit;

architecture rtl of sin_unit is

    type state_t is (
        ST_IDLE,
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
    signal sign_neg            : std_logic;
    signal done_r              : std_logic := '0';
    signal busy_r              : std_logic := '0';
    signal result_r            : word128_t := (others => '0');

    function asr(v : word128_t; i : natural) return word128_t is
    begin
        if i = 0 then
            return v;
        else
            return shift_right(v, i);
        end if;
    end function;

begin

    done   <= done_r;
    busy   <= busy_r;
    result <= result_r;

    process (clk)
        variable x_n, y_n, z_n : word128_t;
        variable di_pos        : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state     <= ST_IDLE;
                done_r    <= '0';
                busy_r    <= '0';
                result_r  <= (others => '0');
                x_reg     <= (others => '0');
                y_reg     <= (others => '0');
                z_reg     <= (others => '0');
                angle     <= (others => '0');
                iter_i    <= 0;
                sign_neg  <= '0';
            else
                case state is
                    when ST_IDLE =>
                        done_r <= '0';
                        if start = '1' then
                            busy_r   <= '1';
                            angle    <= arg_in;
                            sign_neg <= '0';
                            state    <= ST_REDUCE_POS;
                        end if;

                    -- a := a - 2*pi  dopóki a >= pi
                    when ST_REDUCE_POS =>
                        if angle >= Q_PI then
                            angle <= angle - Q_TWO_PI;
                        else
                            state <= ST_REDUCE_NEG;
                        end if;

                    -- a := a + 2*pi  dopóki a < -pi
                    when ST_REDUCE_NEG =>
                        if angle < -Q_PI then
                            angle <= angle + Q_TWO_PI;
                        else
                            state <= ST_QUAD;
                        end if;

                    -- Sprowadzenie do [-pi/2, pi/2]
                    when ST_QUAD =>
                        if angle > Q_HALF_PI then
                            -- sin(pi - a) = sin(a), a in (pi/2, pi]
                            angle <= Q_PI - angle;
                            state <= ST_INIT;
                        elsif angle < -Q_HALF_PI then
                            -- a in [-pi, -pi/2): sin(a) = -sin(a + pi), a+pi in [0, pi/2]
                            angle    <= angle + Q_PI;
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
                                result_r <= -y_n;
                            else
                                result_r <= y_n;
                            end if;
                            state <= ST_DONE;
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
