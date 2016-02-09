-------------------------------------------------------------------------
-- Zhao Zhang, Tom Atterbury
-- Department of Electrical and Computer Engineering
-- Iowa State University
-------------------------------------------------------------------------


-- cpu.vhd
-------------------------------------------------------------------------
-- DESCRIPTION: This file contains a Single-cycle implementaion of a MIPS
-- 32-bit processor. It connects to:
-- 1) an instruction memory
-- 2) a data memory
-- 3) an external clock source
--
--
-- NOTES:
-- 10/21/2013 created.
-- 11/05/2014 Modified for single-cycle implmentation and additional
--            instructions (e.g. addi, slti, jal, etc.)
-------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.mips32.all;

entity cpu is
  port (imem_addr   : out m32_word;     -- Instruction memory address
        inst        : in  m32_word;     -- Instruction
        dmem_addr   : out m32_word;     -- Data memory address
        dmem_read   : out m32_1bit;     -- Data memory read?
        dmem_write  : out m32_1bit;     -- Data memory write?
        dmem_wmask  : out m32_4bits;    -- Data memory write mask
        dmem_rdata  : in  m32_word;     -- Data memory read data
        dmem_wdata  : out m32_word;     -- Data memory write data
        reset       : in  m32_1bit;     -- Reset signal
        clock       : in  m32_1bit);    -- System clock
end cpu;

-- This architecture of CPU must be dominantly structural, with no bahavior 
-- modeling, and only data flow statements to copy/split/merge signals or 
-- with a single level of basic logic gates.
architecture structure of cpu is
  
  -- The ALU
  component alu is
    port(rdata1      : in  m32_word;
         rdata2      : in  m32_word;
         alu_code    : in  m32_4bits;
         result      : out m32_word;
         zero        : out m32_1bit);
  end component;

  -- The Adder
  component adder is
    port(src1    : in  m32_word;
         src2    : in  m32_word;
         result  : out m32_word);
  end component;
  
  -- The Main Controller
  component control is
    port(op_code     : in  m32_6bits;
         signals     : out m32_vector(11 downto 0));
  end component;

  -- ALU Controller
  component alu_control is
    port(ALU_op    : in  m32_2bits;
         func      : in  m32_6bits;
         alu_code  : out m32_4bits;
         alu_src   : out m32_1bit;
         j_src     : out m32_1bit);
  end component;
  
  -- Sign Extender
  component extend16 is
    port(i_sign  : in  m32_1bit;
         i_16bit : in  m32_halfword;
         o_32bit : out m32_word);
  end component;
  
  -- Right Shifter
  component RShift32 is
    port(input  : in  m32_word;
         shamt  : in  m32_5bits;
         arith  : in  m32_1bit;
         result : out m32_word);
  end component;

  -- The register file
  component regfile is
     port(src1      : in  m32_5bits;
          src2      : in  m32_5bits;
          dst       : in  m32_5bits;
          wdata     : in  m32_word;
          rdata1    : out m32_word;
          rdata2    : out m32_word;
          WE        : in  m32_1bit;
          reset     : in  m32_1bit;
          clock     : in  m32_1bit);
  end component;
  
  -- 2-to-1 MUX
  component mux2to1 is
    generic (M : integer := 1);    -- Number of bits in the inputs and output
    port(i_A : in  m32_vector(M-1 downto 0);
         i_B : in  m32_vector(M-1 downto 0);
         i_S : in  m32_1bit;
         o_F : out m32_vector(M-1 downto 0));
  end component;

  -- 4-to-1 MUX
  component mux4to1 is
    generic (M : integer := 1);
    port(i_A : in  m32_vector(M-1 downto 0);
         i_B : in  m32_vector(M-1 downto 0);
         i_C : in  m32_vector(M-1 downto 0);
         i_D : in  m32_vector(M-1 downto 0);
         i_S : in  m32_2bits;
         o_F : out m32_vector(M-1 downto 0));
  end component;
  
  -- Register
  component reg is
    generic (M : integer:= 32);
    port(D      : in  m32_vector(M-1 downto 0);
         Q      : out m32_vector(M-1 downto 0);
         WE     : in  m32_1bit;                
         reset  : in  m32_1bit;                
         clock  : in  m32_1bit);
  end component;

  -- Forwarding Unit
  component forward is
    port(ID_EX_IR       : in  m32_word;
         EX_MEM_IR      : in  m32_word;
		 EX_MEM_Rd      : in  m32_5bits;
         MEM_WB_Rd      : in  m32_5bits;
         MEM_WB_Jmp_Src : in  m32_1bit;
         EX_MEM_Control : in  m32_vector(11 downto 0);
         MEM_WB_Control : in  m32_vector(11 downto 0);
         Fwd_A_Code     : out m32_2bits;
         Fwd_B_Code     : out m32_2bits);
  end component;

  -- Hazard Detection Unit
  component hazard is
    port(IF_ID_IR      : in  m32_word;
         ID_EX_IR      : in  m32_word;
         ID_EX_Control : in  m32_vector(11 downto 0);
         Nop           : out m32_1bit);
  end component;
          
  ------------------------
  -- Signals in the CPU --
  ------------------------
  
  -- Constant signals
  signal Ra         : m32_5bits := "11111";
  signal Empty_Word : m32_word  := "00000000000000000000000000000000";

  -- IF Stage signals
  signal IF_PC      : m32_word := "00000000000000000000000000000000";           -- PC
  signal plus_4     : m32_word := std_logic_vector(to_signed(4, IF_PC'length)); -- 4 to add to PC
  signal IF_PC4     : m32_word;                                                 -- PC+4
  signal IF_Br      : m32_word;                                                 -- Branch Taken/Not-Taken Address
  signal IF_Br_Jmp  : m32_word;                                                 -- Branch or Jump Selected Address
  signal IF_Next_PC : m32_word;                                                 -- Next Instruction Address

  -- IF/ID Register signals
  signal IF_ID_Reg_in  : m32_vector(64 downto 0); -- Input to IF/ID pipeline register
  signal IF_ID_Reg_out : m32_vector(64 downto 0); -- Output of IF/ID pipeline register  
  
  -- ID Stage signals
  signal IF_ID_IR           : m32_word;                -- Instruction
  signal IF_ID_PC4          : m32_word;                -- PC+4
  signal IF_ID_Flush        : m32_1bit;                -- Denotes a flush is needed
  signal IF_ID_Opcode       : m32_6bits;               -- OpCode
  signal IF_ID_Rs           : m32_5bits;               -- Register s Address
  signal IF_ID_Rt           : m32_5bits;               -- Register t Address
  signal IF_ID_Imm          : m32_halfword;            -- Immediate Value
  signal ID_Control         : m32_vector(11 downto 0); -- CPU Controller Signals
  signal ID_Control_Pass    : m32_vector(11 downto 0); -- Muxed CPU Control Signals for stall
  signal ID_Nop             : m32_1bit;                -- Select whether we are inserting a stall or not
  signal ID_Stall_Flush     : m32_1bit;                -- Select whether to stall or flush
  signal ID_Reg_Write_Stall : m32_1bit;                -- Inverted stall selection
  signal ID_Rs_Data         : m32_word;                -- Register s Data
  signal ID_Rt_Data         : m32_word;                -- Register t Data
  signal ID_Imm_Ext         : m32_word;                -- Sign Extended Immediate Value

  -- ID/EX Register signals
  signal ID_EX_Reg_in  : m32_vector(171 downto 0); -- Input to ID/EX pipeline register
  signal ID_EX_Reg_out : m32_vector(171 downto 0); -- Output of ID/EX pipeline register

  -- EX Stage signals
  signal ID_EX_IR           : m32_word;                -- Instruction
  signal ID_EX_PC4          : m32_word;                -- PC+4
  signal ID_EX_Control      : m32_vector(11 downto 0); -- CPU Controller Signals
  signal ID_EX_Control_Pass : m32_vector(11 downto 0); -- Muxed CPU Control Signals for flush
  signal ID_EX_Rs_Data      : m32_word;                -- Register s Data
  signal ID_EX_Rt_Data      : m32_word;                -- Register t Data
  signal ID_EX_Imm_Ext      : m32_word;                -- Sign Extended Immediate Value
  signal ID_EX_OpCode       : m32_6bits;               -- Instruction OpCode
  signal ID_EX_J_Offset     : m32_26bits;              -- Jump Offset Amount
  signal ID_EX_Rt           : m32_5bits;               -- Register t Address
  signal ID_EX_Rd           : m32_5bits;               -- Register d Address
  signal ID_EX_ShAmt        : m32_5bits;               -- Shift Amount for SLL
  signal ID_EX_Func         : m32_6bits;               -- Function Code for ALU Controller
  signal ID_EX_Reg_Dst      : m32_1bit;                -- Destination Register Selection Bit
  signal ID_EX_ALU_B_Src    : m32_1bit;                -- Second ALU Operand Selection Bit
  signal ID_EX_Jump         : m32_1bit;                -- Jump Instruction Selection Bit
  signal ID_EX_Slti_Src     : m32_1bit;                -- Function Code Source Selection Bit
  signal ID_EX_ALU_Op       : m32_2bits;               -- ALU Operation Type Selection Bits
  signal EX_Br_Offset       : m32_word;                -- Branch Offset Amount
  signal EX_Br_Target       : m32_word;                -- Branch Target Address
  signal EX_ALU_Con_Func    : m32_6bits;               -- ALU Function Code Input (Either Func or OpCode)
  signal EX_ALU_Code        : m32_4bits;               -- ALU Operation Code
  signal EX_ALU_A_Src       : m32_1bit;                -- First ALU Operand Selection Bit
  signal EX_J_Src           : m32_1bit;                -- Jump Register Selection Bit
  signal EX_ShAmt_Ext       : m32_word;                -- Zero Extended Shift Amount
  signal EX_ALU_A           : m32_word;                -- First Operand of the ALU
  signal EX_ALU_B           : m32_word;                -- Second Operand of the ALU
  signal EX_Fwd_A           : m32_2bits;               -- Forwarding selection for first ALU operand
  signal EX_Fwd_B           : m32_2bits;               -- Forwarding selection for second ALU operand
  signal EX_ALU_A_Fwd       : m32_word;                -- Forwarded first operand input to ALU
  signal EX_ALU_B_Fwd       : m32_word;                -- Forwarded second operand input to ALU
  signal EX_ALU_Result      : m32_word;                -- Result of the ALU Operation
  signal EX_ALU_Zero        : m32_1bit;                -- Zero Bit Result of ALU Operation
  signal EX_Rt_Rd           : m32_5bits;               -- Register Write Address for I or R Type Instructions
  signal EX_Rd              : m32_5bits;               -- Register Write Address for I/R or JAL Instructions
  signal EX_ALU_Con         : m32_6bits;               -- ALU Controller Signals
  signal EX_J_Target        : m32_word;                -- Jump Target Address
 
  -- EX/MEM Register Signals
  signal EX_MEM_Reg_in  : m32_vector(215 downto 0); -- Input to EX/MEM pipeline register
  signal EX_MEM_Reg_out : m32_vector(215 downto 0); -- Output of EX/MEM pipeline register

  -- MEM Stage signals
  signal EX_MEM_IR           : m32_word;                -- Instruction
  signal EX_MEM_PC4          : m32_word;                -- PC+4
  signal EX_MEM_Control      : m32_vector(11 downto 0); -- CPU Controller Signals
  signal EX_MEM_Rs_Data      : m32_word;                -- Register s Data
  signal EX_MEM_Rt_Data      : m32_word;                -- Register t Data
  signal EX_MEM_Rd           : m32_5bits;               -- Register d Address
  signal EX_MEM_ALU_Con      : m32_6bits;               -- ALU Controller Signals
  signal EX_MEM_ALU_Result   : m32_word;                -- Result of ALU Operation
  signal EX_MEM_ALU_Zero     : m32_1bit;                -- Zero Bit of the ALU Operation
  signal EX_MEM_Br_Target    : m32_word;                -- Branch Target Address
  signal EX_MEM_Mem_Read     : m32_1bit;                -- Data Memory Read Enable
  signal EX_MEM_Mem_Write    : m32_1bit;                -- Data Memory Write Enable
  signal EX_MEM_Branch       : m32_2bits;               -- CPU Controller Branch Selection Bits
  signal EX_MEM_J_Src        : m32_1bit;                -- ALU Controller Jump Selection Bit
  signal EX_MEM_Branch_Src   : m32_1bit;                -- Branch Taken/Not-Taken Selection Bit
  signal MEM_Mem_Read_Data   : m32_word;                -- Data Read from Data Memory

  -- MEM/WB Register Signals
  signal MEM_WB_Reg_in  : m32_vector(118 downto 0); -- Input to MEM/WB pipeline register
  signal MEM_WB_Reg_out : m32_vector(118 downto 0); -- Output of MEM/WB pipeline register

  -- WB Stage signals
  signal MEM_WB_PC4          : m32_word;                -- PC+4
  signal MEM_WB_Control      : m32_vector(11 downto 0); -- CPU Controller Signals
  signal MEM_WB_Rd           : m32_5bits;               -- Register d Address
  signal MEM_WB_ALU_Con      : m32_6bits;               -- ALU Controller Signals
  signal MEM_WB_ALU_Result   : m32_word;                -- Result of ALU Operation
  signal MEM_WB_Mem_Data     : m32_word;                -- Data Read from Data Memory
  signal MEM_WB_Mem_To_Reg   : m32_1bit;                -- Data Memory Data Write Enable Bit
  signal MEM_WB_Reg_Write    : m32_1bit;                -- Register Write Enable Bit
  signal MEM_WB_Jump         : m32_1bit;                -- CPU Controller Jump Selection Bit
  signal MEM_WB_J_Src        : m32_1bit;                -- ALU Controller Jump Selection Bit
  signal WB_ALU_Mem_Data     : m32_word;                -- Selected Data to Write to Register
  signal WB_Reg_Write_Enable : m32_1bit;                -- Register Write Enable Bit with Jal Correction
  signal WB_Rd_Data          : m32_word;                -- Data to Write to Register d

begin
  
  -- Write to all bytes in data memory
  dmem_wmask <= "1111";
  
  ----------------------------------------------------
  --                  IF STAGE                      --
  ----------------------------------------------------

  -- Branch Multiplexer
  br_mux: mux2to1
    generic map(M => 32)
    port map(IF_PC4, EX_MEM_Br_Target, EX_MEM_Branch_Src, IF_Br);
  
  -- Branch or Jump Multiplexer
  br_jmp: mux2to1
    generic map(M => 32)
    port map(IF_Br, EX_J_Target, ID_EX_Jump, IF_Br_Jmp);
    
  -- Jump Immediate/Branch or Jump Register
  jump_reg: mux2to1
    generic map(M => 32)
    port map(IF_Br_Jmp, EX_MEM_Rs_Data, EX_MEM_J_Src, IF_Next_PC);

  -- PC register
  PC_reg: reg
    generic map(M => 32)
    port map(IF_Next_PC, IF_PC, ID_Reg_Write_Stall, reset, clock);

  -- Calculate PC + 4
  PCp4: adder
    port map(IF_PC, plus_4, IF_PC4);

  -- Drive the I-mem address to match new pc
  imem_addr <= IF_PC;

  ---------------------------------------------
  -- Compact inputs to IF/ID pipeline register
  IF_ID_Reg_in <= inst & IF_PC4 & EX_MEM_Branch_Src;
	
  -- IF/ID register
  IFID_reg: reg
    generic map(M => 65)
    port map(IF_ID_Reg_in, IF_ID_Reg_out, ID_Reg_Write_Stall, reset, clock);

  ----------------------------------------------------
  --                  ID STAGE                      --
  ----------------------------------------------------  

  -- IF/ID register signals to use in ID stage
  IF_ID_IR    <= IF_ID_Reg_out(64 downto 33);
  IF_ID_PC4   <= IF_ID_Reg_out(32 downto  1);
  IF_ID_Flush <= IF_ID_Reg_out(0);

  -- Get instruction fields to be used in ID stage
  IF_ID_OpCode   <= IF_ID_IR(31 downto 26);
  IF_ID_Rs       <= IF_ID_IR(25 downto 21);
  IF_ID_Rt       <= IF_ID_IR(20 downto 16);
  IF_ID_Imm      <= IF_ID_IR(15 downto  0);

  -- Connect main CPU controller
  MC: control
    port map(IF_ID_OpCode, ID_Control);

  -- Connect the Hazard Detection Unit
  hdu: hazard
    port map(IF_ID_IR, ID_EX_IR, ID_EX_Control, ID_Nop);

  ID_Reg_Write_Stall <= NOT ID_Nop;

  -- Stall select mux
  ID_Stall_Flush <= ID_Nop OR EX_MEM_Branch_Src OR IF_ID_Flush;
  stall_mux: mux2to1
    generic map(M => 12)
    port map(ID_Control, "000000000000", ID_Stall_Flush, ID_Control_Pass);

  -- The register file
  REGFILE1 : regfile
    port map (IF_ID_Rs, IF_ID_Rt, MEM_WB_Rd, WB_Rd_Data, ID_Rs_Data, ID_Rt_Data, WB_Reg_Write_Enable, reset, clock);
  
  -- Immediate value sign extender
  Immediate: extend16
    port map(IF_ID_Imm(15), IF_ID_Imm, ID_Imm_Ext);

  ------------------------------------
  -- Compact inputs to ID/EX pipeline register
  ID_EX_Reg_in <= IF_ID_IR & IF_ID_PC4 & ID_Control_Pass & ID_Rs_Data & ID_Rt_Data & ID_Imm_Ext;

  -- ID/EX register
  IDEX_reg: reg
    generic map(M => 172)
    port map(ID_EX_Reg_in, ID_EX_Reg_out, '1', reset, clock);

  ----------------------------------------------------
  --                  EX STAGE                      --
  ----------------------------------------------------

  -- ID/EX register signals to use in EX stage
  ID_EX_IR      <= ID_EX_Reg_out(171 downto 140);
  ID_EX_PC4     <= ID_EX_Reg_out(139 downto 108);
  ID_EX_Control <= ID_EX_Reg_out(107 downto  96);
  ID_EX_Rs_Data <= ID_EX_Reg_out( 95 downto  64);
  ID_EX_Rt_Data <= ID_EX_Reg_out( 63 downto  32);
  ID_EX_Imm_Ext <= ID_EX_Reg_out( 31 downto   0);

  -- Setup control signals and fields
  ID_EX_OpCode    <= ID_EX_IR(31 downto 26);
  ID_EX_J_Offset  <= ID_EX_IR(25 downto  0);
  ID_EX_Rt        <= ID_EX_IR(20 downto 16);
  ID_EX_Rd        <= ID_EX_IR(15 downto 11);
  ID_EX_ShAmt     <= ID_EX_IR(10 downto  6);
  ID_EX_Func      <= ID_EX_IR( 5 downto  0);

  ID_EX_Reg_Dst   <= ID_EX_Control(11);
  ID_EX_ALU_B_Src <= ID_EX_Control(10);
  ID_EX_Jump      <= ID_EX_Control( 3);
  ID_EX_Slti_Src  <= ID_EX_Control( 2);
  ID_EX_ALU_Op    <= ID_EX_Control( 1 downto 0);

  -- Determine Branch target address
  EX_Br_Offset <= ID_EX_Imm_Ext(29 downto 0) & "00";

  Branch: adder
    port map(ID_EX_PC4, EX_Br_Offset, EX_Br_Target);

  -- ALU control function input select mux
  ALU_con_Mux: mux2to1
    generic map(M => 6)
	port map(ID_EX_Func, ID_EX_OpCode, ID_EX_Slti_Src, EX_ALU_Con_Func);

  -- Connect ALU controller
  ALU_con: alu_control
    port map(ID_EX_ALU_Op, EX_ALU_Con_Func, EX_ALU_Code, EX_ALU_A_Src, EX_J_Src);

  -- Extend shift amount for possible input to ALU
  EX_ShAmt_Ext <= "000000000000000000000000000" & ID_EX_ShAmt;

  -- ALU input A select mux
  ALU_MUX_A: mux2to1
    generic map (M => 32)
    port map(ID_EX_Rs_Data, EX_ShAmt_Ext, EX_ALU_A_Src, EX_ALU_A);  
  
  -- ALU input B select mux
  ALU_MUX_B: mux2to1
    generic map (M => 32)
    port map(ID_EX_Rt_Data, ID_EX_Imm_Ext, ID_EX_ALU_B_Src, EX_ALU_B);

  ----------------
  -- Forwarding
  ----------------

  -- Forwading Unit
  Fwd : forward
    port map(ID_EX_IR, EX_MEM_IR, EX_MEM_Rd, MEM_WB_Rd, MEM_WB_J_Src, EX_MEM_Control, MEM_WB_Control, EX_Fwd_A, EX_Fwd_B);

  -- ALU input A forwarding mux
  ALU_FWD_A: mux4to1
    generic map (M => 32)
    port map(EX_ALU_A, WB_Rd_Data, EX_MEM_ALU_Result, Empty_Word, EX_Fwd_A, EX_ALU_A_Fwd);

  -- ALU input B forwarding mux
  ALU_FWD_B: mux4to1
    generic map (M => 32)
    port map(EX_ALU_B, WB_Rd_Data, EX_MEM_ALU_Result, Empty_Word, EX_Fwd_B, EX_ALU_B_Fwd);

  -- Connect ALU
  CPU_ALU: alu
    port map(EX_ALU_A_Fwd, EX_ALU_B_Fwd, EX_ALU_Code, EX_ALU_Result, EX_ALU_Zero);

  -- The mux to choose Rt or Rd for register write address
  DST_MUX : mux2to1
    generic map (M => 5)
    port map (ID_EX_Rt, ID_EX_Rd, ID_EX_Reg_Dst, EX_Rt_Rd);

  -- Mux to determine if writing to specified register, or $ra
  DJump_Mux : mux2to1
    generic map(M => 5)
    port map (EX_Rt_Rd, Ra, ID_EX_Jump, EX_Rd);

  -- Jump target
  EX_J_Target <= ID_EX_PC4(31 downto 28) & ID_EX_J_Offset & "00";

  -----------------------------------------------------
  -- Compact ALU control signals for pipeline register
  EX_ALU_Con <= EX_ALU_Code & EX_ALU_A_Src & EX_J_Src;
  
    -- Branch Flush select mux
  EX_flush_mux: mux2to1
    generic map(M => 12)
    port map(ID_EX_Control, "000000000000", EX_MEM_Branch_Src, ID_EX_Control_Pass);

  -- Compact inputs to EX/MEM pipeline register
  EX_MEM_Reg_in <= ID_EX_IR & ID_EX_PC4 & ID_EX_Control_Pass & ID_EX_Rs_Data & ID_EX_Rt_Data & EX_Rd & EX_ALU_Con & EX_ALU_Result & EX_ALU_Zero & EX_Br_Target;

  -- EX/MEM register
  EXMEM_reg: reg
    generic map(M => 216)
    port map(EX_MEM_Reg_In, EX_MEM_Reg_Out, '1', reset, clock);

  ----------------------------------------------------
  --                 MEM STAGE                      --
  ----------------------------------------------------
  
  -- EX/MEM register signals to use in MEM stage
  EX_MEM_IR         <= EX_MEM_Reg_Out(215 downto 184);
  EX_MEM_PC4        <= EX_MEM_Reg_Out(183 downto 152);
  EX_MEM_Control    <= EX_MEM_Reg_Out(151 downto 140);
  EX_MEM_Rs_Data    <= EX_MEM_Reg_Out(139 downto 108);
  EX_MEM_Rt_Data    <= EX_MEM_Reg_Out(107 downto  76);
  EX_MEM_Rd         <= EX_MEM_Reg_Out( 75 downto  71);
  EX_MEM_ALU_Con    <= EX_MEM_Reg_Out( 70 downto  65);
  EX_MEM_ALU_Result <= EX_MEM_Reg_Out( 64 downto  33);
  EX_MEM_ALU_Zero   <= EX_MEM_Reg_Out(            32);
  EX_MEM_Br_Target  <= EX_MEM_Reg_Out( 31 downto   0);

  -- Setup control signals and fields for MEM stage
  EX_MEM_Mem_Read  <= EX_MEM_Control(7);
  EX_MEM_Mem_Write <= EX_MEM_Control(6);
  EX_MEM_Branch    <= EX_MEM_Control(5 downto 4);

  EX_MEM_J_Src     <= EX_MEM_ALU_Con(0);

  -- Branch taken/not-taken
  EX_MEM_Branch_Src <= EX_MEM_Branch(1) and (EX_MEM_Branch(0) xor EX_MEM_ALU_Zero);

  -- Data memory read/write enable signals
  dmem_write <= EX_MEM_Mem_Write;
  dmem_read  <= EX_MEM_Mem_Read;

  -- Data memory write
  dmem_addr  <= EX_MEM_ALU_Result;
  dmem_wdata <= EX_MEM_Rt_Data;

  -- Data memory read
  MEM_Mem_Read_Data <= dmem_rdata;

  ----------------------------------------------
  -- Compact inputs to MEM/WB pipeline register
  MEM_WB_Reg_In <= EX_MEM_PC4 & EX_MEM_Control & EX_MEM_Rd & EX_MEM_ALU_Con & EX_MEM_ALU_Result & MEM_Mem_Read_Data;

  -- MEM/WB register
  MEMWB_reg: reg
    generic map(M => 119)
    port map(MEM_WB_Reg_In, MEM_WB_Reg_Out, '1', reset, clock);

  ----------------------------------------------------
  --                  WB STAGE                      --
  ----------------------------------------------------

  -- EX/MEM register signals to use in MEM stage
  MEM_WB_PC4        <= MEM_WB_Reg_Out(118 downto 87);
  MEM_WB_Control    <= MEM_WB_Reg_Out( 86 downto 75);
  MEM_WB_Rd         <= MEM_WB_Reg_Out( 74 downto 70);
  MEM_WB_ALU_Con    <= MEM_WB_Reg_Out( 69 downto 64);
  MEM_WB_ALU_Result <= MEM_WB_Reg_Out( 63 downto 32);
  MEM_WB_Mem_Data   <= MEM_WB_Reg_Out( 31 downto  0);

  -- Setup control signals and fields for WB stage
  MEM_WB_Mem_To_Reg <= MEM_WB_Control(9);
  MEM_WB_Reg_Write  <= MEM_WB_Control(8);
  MEM_WB_Jump       <= MEM_WB_Control(3);

  MEM_WB_J_Src      <= MEM_WB_ALU_Con(0);

  -- Connect Register File write data port to ALU and Data Memory
  RegWrite_Mux: mux2to1
    generic map(M => 32)
    port map(MEM_WB_ALU_Result, MEM_WB_Mem_Data, MEM_WB_Mem_To_Reg, WB_ALU_Mem_Data);

  -- Disable write for jr
  WB_Reg_Write_Enable <= MEM_WB_Reg_Write AND (NOT MEM_WB_J_Src);

  -- Select to store either data, or pc+4
  JAL_RD_Data_Mux: mux2to1
    generic map(M => 32)
    port map(WB_ALU_Mem_Data, MEM_WB_PC4, MEM_WB_Jump, WB_Rd_Data);
  
end structure;

