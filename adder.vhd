-------------------------------------------------------------------------
-- Zhao Zhang
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- adder.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains Adder logic for caluclating PC-plus-4
-- and branch targets.
--
--
-- NOTES:
-- 10/21/2013 created.
-------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.mips32.all;

entity adder is
  port (src1    : in  m32_word;
        src2    : in  m32_word;
        result  : out m32_word);
end entity;

-- Behavior modeling of ADDER
architecture behavior of adder is
begin
  ADD : process (src1, src2)
    variable a : integer;
    variable b : integer;
    variable c : integer;
  begin
    -- Pre-calculate
    a := to_integer(signed(src1));
    b := to_integer(signed(src2));
    c := a + b;
    
    -- Convert integer to 32-bit signal
    result <= std_logic_vector(to_signed(c, result'length));
  end process;
end behavior;
