-------------------------------------------------------------------------
-- Tom Atterbury
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- forward.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains an implementation of a MIPS pipeline
-- forwarding unit.
--
--
-- NOTES:
-- 12/10/2013 created.
-------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.mips32.all;

entity forward is
  port (ID_EX_IR       : in  m32_word;
        EX_MEM_IR      : in  m32_word;
		EX_MEM_Rd      : in  m32_5bits;
        MEM_WB_Rd      : in  m32_5bits;
        MEM_WB_Jmp_Src : in  m32_1bit;
        EX_MEM_Control : in  m32_vector(11 downto 0);
        MEM_WB_Control : in  m32_vector(11 downto 0);
        Fwd_A_Code     : out m32_2bits;
        Fwd_B_Code     : out m32_2bits);
end forward;

architecture fu of forward is

  -- EX Stage Signals
  signal EX_MEM_Reg_Write_En   : m32_1bit;
  signal EX_MEM_Func           : m32_6bits;
  signal EX_MEM_Reg_Write      : m32_1bit;
  signal EX_MEM_Jmp_Src        : m32_1bit;
  signal EX_MEM_ALU_Op         : m32_2bits; 
  signal EX_MEM_ALU_Full_Code  : m32_byte;
  signal EX_MEM_Rd_Non_Zero    : m32_1bit;
  signal ID_EX_Rs_Is_EX_MEM_Rd : m32_1bit;
  signal ID_EX_Rt_Is_EX_MEM_Rd : m32_1bit;
  signal ALU_A_EX_Compare      : m32_5bits;
  signal ALU_B_EX_Compare      : m32_5bits;

  -- MEM Stage Signals
  signal MEM_WB_Reg_Write_En   : m32_1bit;
  signal MEM_WB_Reg_Write      : m32_1bit;
  signal MEM_WB_Rd_Non_Zero    : m32_1bit;
  signal ID_EX_Rs_Is_MEM_WB_Rd : m32_1bit;
  signal ID_EX_Rt_Is_MEM_WB_Rd : m32_1bit;
  signal ALU_A_MEM_Compare     : m32_5bits;
  signal ALU_B_MEM_Compare     : m32_5bits;

  -- Others
  signal EX_A_Hazard           : m32_1bit;
  signal EX_B_Hazard           : m32_1bit;
  signal ID_EX_Rt              : m32_5bits;
  signal ID_EX_Rs              : m32_5bits;  

begin

  ----------------------
  -- Forwarding Logic
  ----------------------

  -- Check if instruction in EX stage will write to a register
  EX_MEM_Reg_Write_En <= EX_MEM_Reg_Write AND (NOT EX_MEM_Jmp_Src);

  -- Determine if instruction in EX stage is a jr instruction
  EX_MEM_Func <= EX_MEM_IR( 5 downto  0);

  EX_MEM_Reg_Write <= EX_MEM_Control(8);
  EX_MEM_ALU_Op    <= EX_MEM_Control( 1 downto 0);

  EX_MEM_ALU_Full_Code <= EX_MEM_ALU_Op & EX_MEM_Func;

  with EX_MEM_ALU_Full_Code select
    EX_MEM_Jmp_Src <= '1' when "10000100", -- JR
                      '0' when others;   -- No JR


  -- Check if instruction in MEM stage will write to a register
  MEM_WB_Reg_Write <= MEM_WB_Control(8);
  MEM_WB_Reg_Write_En <= MEM_WB_Reg_Write AND (NOT MEM_WB_Jmp_Src);

  -- Check if destination register in EX stage is non-zero
  EX_MEM_Rd_Non_Zero <= '0' when (EX_MEM_Rd = (EX_MEM_Rd'range => '0')) else '1';


  -- Check if destination register in MEM stage is non-zero
  MEM_WB_Rd_Non_Zero <= '0' when (MEM_WB_Rd = (MEM_WB_Rd'range => '0')) else '1';


  -- Check if ALU A source register in ID stage matches destination register in EX stage
  ID_EX_Rs <= ID_EX_IR(25 downto 21);

  ALU_A_EX_Compare <= ID_EX_Rs XOR EX_MEM_Rd;
  ID_EX_Rs_Is_EX_MEM_Rd <= '1' when (ALU_A_EX_Compare = (ALU_A_EX_Compare'range => '0')) else '0';

  -- Check if ALU A source register in ID stage matches destination register in MEM stage
  ALU_A_MEM_Compare <= ID_EX_Rs XOR MEM_WB_Rd;
  ID_EX_Rs_Is_MEM_WB_Rd <= '1' when (ALU_A_MEM_Compare = (ALU_A_MEM_Compare'range => '0')) else '0';


  -- Check if ALU B source register in ID stage matches destination register in EX stage
  ID_EX_Rt <= ID_EX_IR(20 downto 16);

  ALU_B_EX_Compare <= ID_EX_Rt XOR EX_MEM_Rd;
  ID_EX_Rt_Is_EX_MEM_Rd <= '1' when (ALU_B_EX_Compare = (ALU_B_EX_Compare'range => '0')) else '0';

  -- Check if ALU B source register in ID stage matches destination register in MEM stage
  ALU_B_MEM_Compare <= ID_EX_Rt XOR MEM_WB_Rd;
  ID_EX_Rt_Is_MEM_WB_Rd <= '1' when (ALU_B_MEM_Compare = (ALU_B_MEM_Compare'range => '0')) else '0';


  -- Determine if ALU A data hazard exists in EX stage or MEM stages
  EX_A_Hazard   <= EX_MEM_Reg_Write_En AND EX_MEM_Rd_Non_Zero AND ID_EX_Rs_Is_EX_MEM_Rd;
  Fwd_A_Code(1) <= EX_A_Hazard;
  Fwd_A_Code(0) <= MEM_WB_Reg_Write_En AND MEM_WB_Rd_Non_Zero AND ID_EX_Rs_Is_MEM_WB_Rd AND (NOT EX_A_Hazard);

  -- Determine if ALU B data hazard exists in EX stage or MEM stages
  EX_B_Hazard   <= EX_MEM_Reg_Write_En AND EX_MEM_Rd_Non_Zero AND ID_EX_Rt_Is_EX_MEM_Rd;
  Fwd_B_Code(1) <= EX_B_Hazard;
  Fwd_B_Code(0) <= MEM_WB_Reg_Write_En AND MEM_WB_Rd_Non_Zero AND ID_EX_Rt_Is_MEM_WB_Rd AND (NOT EX_B_Hazard);

end fu;

