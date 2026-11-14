--------------------------------------------------------------------------------
-- Jednostka arctan(y/x) – CORDIC w trybie wektorowania (circular vectoring)
-- Używana do arcsin(w) = arctan(w / sqrt(1-w^2))
-- Wejścia x,y oraz wynik kąta: Q4.124
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ask_types_pkg.all;
use work.cordic_pkg.all;

entity atan_unit is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        start    : in  std_logic;
        x_in     : in  word128_t;
        y_in     : in  word128_t;
        result   : out word128_t;
        done     : out std_logic;
        busy     : out std_logic
    );
end entity atan_unit;

architecture rtl of atan_unit is

    type state_t is (ST_IDLE, ST_QUAD, ST_ITER, ST_DONE);
    signal state : state_t := ST_IDLE;

    signal x_reg, y_reg, z_reg : word128_t;
    signal iter_i              : integer range 0 to CORDIC_ITERS := 0;
    signal adjust_pi           : std_logic;
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
        variable y_neg         : boolean;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state      <= ST_IDLE;
                done_r     <= '0';
                busy_r     <= '0';
                result_r   <= (others => '0');
                x_reg      <= (others => '0');
                y_reg      <= (others => '0');
                z_reg      <= (others => '0');
                iter_i     <= 0;
                adjust_pi  <= '0';
            else
                case state is
                    when ST_IDLE =>
                        done_r <= '0';
                        if start = '1' then
                            busy_r    <= '1';
                            x_reg     <= x_in;
                            y_reg     <= y_in;
                            z_reg     <= Q_ZERO;
                            adjust_pi <= '0';
                            iter_i    <= 0;
                            state     <= ST_QUAD;
                        end if;

                    -- Upewnij się, że x >= 0 (CORDIC vectoring wymaga x>0)
                    when ST_QUAD =>
                        if x_reg < 0 then
                            -- II/III ćwiartka: odbij i dodaj +/- pi na końcu
                            x_reg     <= -x_reg;
                            y_reg     <= -y_reg;
                            adjust_pi <= '1';
                        end if;
                        state <= ST_ITER;

                    when ST_ITER =>
                        y_neg := (y_reg < 0);

                        if y_neg then
                            -- di = +1: obrót w lewo, aby y -> 0
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
                            if adjust_pi = '1' then
                                -- Po odbiciu: kąt += pi * sign(oryginalnego y)
                                -- Po negacji obu: z ma znak przeciwny do oczekiwanego w II/III
                                -- Przy x<0, y>=0 (II): atan = pi + atan(y/x_neg_fixed)...
                                -- Prościej: po negacji x,y zaczynamy od I/IV; wynik z;
                                -- oryginalny kąt = z + pi (gdy oryg. y >= 0 przed? )
                                -- Przed odbiciem zapisaliśmy: x:=-x, y:=-y. Znak y się odwrócił.
                                -- Oryginalny y_in: jeśli y_in >= 0 i x_in < 0 -> II -> wynik = pi + z'
                                -- gdzie z' jest kątem po odbiciu (y stało się ujemne...).
                                -- Po x=-x, y=-y: nowy kąt = stary - pi (lub +pi).
                                -- Wracamy: result = z + pi  jeśli y_in było >=0 przed odbiciem?
                                -- Bezpieczniej: result = z_n + Q_PI, z ograniczeniem do (-pi,pi]
                                result_r <= z_n + Q_PI;
                            else
                                result_r <= z_n;
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
