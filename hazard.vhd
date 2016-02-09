-------------------------------------------------------------------------
-- Tom Atterbury
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- hazard.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains an implementation of a MIPS pipelined
-- data hazard detection unit.
--
--
-- NOTES:
-- 12/11/2013 created.
-------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.mips32.all;

entity hazard is
  port (IF_ID_IR      : in  m32_word;
        ID_EX_IR      : in  m32_word;
        ID_EX_Control : in  m32_vector(11 downto 0);
        Nop           : out m32_1bit);
end hazard;

architecture hdu of hazard is

  -- EX Stage signals
  signal ID_EX_Mem_Read       : m32_1bit;
  signal ID_EX_Rt             : m32_5bits;

  -- ID Stage signals
  signal IF_ID_Rt             : m32_5bits;
  signal IF_ID_Rs             : m32_5bits;
  
  -- Intermediate comparison signals
  signal IF_ID_Rs_Compare     : m32_5bits;
  signal IF_ID_Rs_Is_ID_EX_Rt : m32_1bit;

  signal IF_ID_Rt_Compare     : m32_5bits;
  signal IF_ID_Rt_Is_ID_EX_Rt : m32_1bit;

begin

  -----------------
  -- Stall Logic
  -----------------

  -- Check if instruction is a load
  ID_EX_Mem_Read <= ID_EX_Control(7);

  -- Check if next instruction uses the register the load is writing to
  IF_ID_Rs <= IF_ID_IR(25 downto 21);
  IF_ID_Rt <= IF_ID_IR(20 downto 16);

  ID_EX_Rt <= ID_EX_IR(20 downto 16);

  -- Compare ID stage Rs to EX stage Rt
  IF_ID_Rs_Compare <= ID_EX_Rt XOR IF_ID_Rs;
  IF_ID_Rs_Is_ID_EX_Rt <= '1' when (IF_ID_Rs_Compare = (IF_ID_Rs_Compare'range => '0')) else '0';

  -- Compare ID stage Rt to EX stage Rt
  IF_ID_Rt_Compare <= ID_EX_Rt XOR IF_ID_Rt;
  IF_ID_Rt_Is_ID_EX_Rt <= '1' when (IF_ID_Rt_Compare = (IF_ID_Rt_Compare'range => '0')) else '0';

  -- Determine if a stall is necessary
  Nop <= ID_EX_Mem_Read AND (IF_ID_Rt_Is_ID_EX_Rt OR IF_ID_Rs_Is_ID_EX_Rt);

end hdu;

