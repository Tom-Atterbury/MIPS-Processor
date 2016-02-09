-------------------------------------------------------------------------
-- Tom Atterbury
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- alu_control.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains the logic for a MIPS ALU control unit.
--
--
-- NOTES:
-- 11/05/2014 created.
-------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.mips32.all;

entity alu_control is
  port (ALU_op   : in  m32_2bits;
        func     : in  m32_6bits;
        alu_code : out m32_4bits;
        alu_src  : out m32_1bit;
        j_src    : out m32_1bit);
end alu_control;

architecture rom of alu_control is

  signal full_code : m32_byte;
  signal code_val  : integer := 0;
  
  subtype code_t is m32_vector(3 downto 0);
  type rom_t is array (0 to 255) of code_t;
  
  -- The ROM content
  signal rom : rom_t := (
    128    => "1000",  -- SLL
    
    32     => "0010",  -- ADD
    144    => "0010",
    160    => "0010",  
    176    => "0010",
    
    130    => "0110",  -- SUB
    146    => "0110",  
    162    => "0110",  
    178    => "0110",  
    
    132    => "0000",  -- AND
    148    => "0000",  
    164    => "0000",  
    180    => "0000",  
    
    133    => "0001",   -- OR
    149    => "0001",   
    165    => "0001",   
    181    => "0001",   
    
    138    => "0111",  -- SLT
    154    => "0111",  
    170    => "0111",  
    186    => "0111",  
    
    167    => "1100",  -- NOR
    
    others => "0000"); -- AND
  
begin
  
  full_code <= ALU_op & func;
  code_val <= to_integer(unsigned(full_code));
  
  with code_val select
    alu_src <= '1' when 128,      -- SLL
               '0' when others; -- No SLL
  
  with code_val select
    j_src <= '1' when 136,    -- JR
             '0' when others; -- No JR
  
  with code_val select
    alu_code <= rom(160) when 0  to 63,    -- ADD
                rom(130) when 64 to 127,   -- SUB
                rom(code_val) when others; -- Func defined

end rom;

