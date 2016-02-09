-------------------------------------------------------------------------
-- Zhao Zhang
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- mips32.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains a package of data types for a MIPS
-- 32-bit processor.
--
--
-- NOTES:
-- 10/21/2013 created.
-------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;

package MIPS32 is
  -- Half Cycle Time of the clock signal
  constant HCT : time := 50 ns;
  
  -- Clock Cycle Time of the clock signal
  constant CCT : time := 2 * HCT;
  
  -- MIPS32 logic type
  subtype m32_logic is std_logic;
  
  -- MIPS32 logic vector type
  subtype m32_vector is std_logic_vector;
  
  -- Word type, for register values, memory word contents, and 
  -- memory address
  subtype m32_word is m32_vector(31 downto 0);  
  
  -- Halfword, byte, and bit fields of varying size
  subtype m32_halfword is m32_vector(15 downto 0);
  subtype m32_byte is m32_vector(7 downto 0);
  subtype m32_1bit is m32_logic;
  subtype m32_2bits is m32_vector(1 downto 0);
  subtype m32_3bits is m32_vector(2 downto 0);
  subtype m32_4bits is m32_vector(3 downto 0);
  subtype m32_5bits is m32_vector(4 downto 0);
  subtype m32_6bits is m32_vector(5 downto 0);
  subtype m32_26bits is m32_vector(25 downto 0);
   
  -- Register value array type
  type m32_regval_array is array (31 downto 0) of m32_word;
  
  -- Conversion functions for debugging
  function dec(vec : m32_vector) return string;
  function hex(vec : m32_vector) return string;
  -- function bin(vec : m32_vector) return string;

end MIPS32;

package body MIPS32 is
  -- Convert m32_vector to dec
  function dec(vec : m32_vector) return string is
    use std.textio.all;
    use IEEE.std_logic_textio.all;
    variable buf : line;
  begin
    write (buf, vec);
    return buf.all;
  end dec;
  
  -- Convert m32_vector to dec
  function hex(vec : m32_vector) return string is
    use std.textio.all;
    use IEEE.std_logic_textio.all;
    variable buf : line;
  begin
    hwrite (buf, vec);
    return buf.all;
  end hex;
  
  -- TODO Write the bin function
  
end MIPS32;  
