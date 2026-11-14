--------------------------------------------------------------------------------
-- Pierwiastek kwadratowy – metoda cyfrowa (digit-by-digit) dla Q4.124
-- Wynik również w Q4.124; wejście musi być >= 0
--------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.ask_types_pkg.all;
use work.cordic_pkg.all;

entity sqrt_unit is
    port (
        clk      : in  std_logic;
        rst      : in  std_logic;
        start    : in  std_logic;
        arg_in   : in  word128_t;
        result   : out word128_t;
        done     : out std_logic;
        busy     : out std_logic
    );
end entity sqrt_unit;

architecture rtl of sqrt_unit is

    type state_t is (ST_IDLE, ST_ITER, ST_ALIGN, ST_DONE);
    signal state : state_t := ST_IDLE;

    -- Pracujemy na wartości przeskalowanej: arg * 2^FRAC, pierwiastek w dziedzinie
    -- całkowitej, potem wynik Q = root (już z FRAC/2... używamy Newtona w Q).
    -- Prostsze: Newton-Raphson w Q4.124:
    --   y_{n+1} = (y_n + x/y_n) / 2
    signal y_reg   : word128_t;
    signal x_reg   : word128_t;
    signal iter_i  : integer range 0 to 31 := 0;
    signal done_r  : std_logic := '0';
    signal busy_r  : std_logic := '0';
    signal result_r: word128_t := (others => '0');

    constant NEWTON_ITERS : integer := 16;

    -- Dzielenie Q4.124 / Q4.124 -> Q4.124 (przybliżone, 128-bit)
    function div_q124(num, den : word128_t) return word128_t is
        variable n : signed(2 * DATA_WIDTH - 1 downto 0);
        variable d : word128_t;
        variable q : signed(2 * DATA_WIDTH - 1 downto 0);
    begin
        if den = 0 then
            return Q_ONE;
        end if;
        d := den;
        -- num/den w Q: (num << FRAC) / den
        n := resize(num, 2 * DATA_WIDTH);
        n := shift_left(n, FRAC_BITS);
        q := n / d;
        return q(DATA_WIDTH - 1 downto 0);
    end function;

begin

    done   <= done_r;
    busy   <= busy_r;
    result <= result_r;

    process (clk)
        variable y_next : word128_t;
        variable quot   : word128_t;
    begin
        if rising_edge(clk) then
            if rst = '1' then
                state    <= ST_IDLE;
                done_r   <= '0';
                busy_r   <= '0';
                result_r <= (others => '0');
                y_reg    <= (others => '0');
                x_reg    <= (others => '0');
                iter_i   <= 0;
            else
                case state is
                    when ST_IDLE =>
                        done_r <= '0';
                        if start = '1' then
                            busy_r <= '1';
                            x_reg  <= arg_in;
                            -- Start Newtona: y0 = 1 (dobre dla x w [0, 1] przy arcsin)
                            -- Dla ogólnego x: y0 = max(x, 1) w przybliżeniu
                            if arg_in = 0 then
                                result_r <= Q_ZERO;
                                state    <= ST_DONE;
                            elsif arg_in > Q_ONE then
                                y_reg  <= arg_in;  -- zgrubne
                                iter_i <= 0;
                                state  <= ST_ITER;
                            else
                                y_reg  <= Q_ONE;
                                iter_i <= 0;
                                state  <= ST_ITER;
                            end if;
                        end if;

                    when ST_ITER =>
                        quot   := div_q124(x_reg, y_reg);
                        y_next := shift_right(y_reg + quot, 1);
                        y_reg  <= y_next;
                        if iter_i = NEWTON_ITERS - 1 then
                            result_r <= y_next;
                            state    <= ST_DONE;
                        else
                            iter_i <= iter_i + 1;
                        end if;

                    when ST_ALIGN =>
                        state <= ST_DONE;

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
