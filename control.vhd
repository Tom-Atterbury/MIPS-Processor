-------------------------------------------------------------------------
-- Tom Atterbury
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- control.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains an implementation of a MIPS main 
-- control unit.
--
--
-- NOTES:
-- 10/21/2013 created.
-- 11/05/2014 Added functionallity for jal, slti, addi, bne, etc.
-- 11/19/2014 Modified to compact control signals into one string.
-------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.mips32.all;

entity control is
  port (op_code     : in  m32_6bits;
        signals     : out m32_vector(11 downto 0));
end control;

architecture rom of control is
  subtype code_t is m32_vector(11 downto 0);
  type rom_t is array (0 to 63) of code_t;
  
  -- The ROM content
  -- Format: reg_dst, alu_src, mem_to_reg, reg_write, mem_read, 
  -- mem_write, branch(1), branch(0), jump, slti, alu_op(1), alu_op(0)
  signal rom : rom_t := (
    0      => "100100000010",  -- R-format (ALU)
    2      => "000000001000",  -- j
    3      => "000100001000",  -- jal
    4      => "000000100001",  -- beq
    5      => "000000110001",  -- bne
    8      => "010100000000",  -- addi
    10     => "010100000110",  -- slti
    35     => "011110000000",  -- I-format (lw)
    43     => "010001000000",  -- I-format (sw)
    others => "000000000000"); -- noop

begin
  signals <= rom(to_integer(unsigned(op_code)));
end rom;

