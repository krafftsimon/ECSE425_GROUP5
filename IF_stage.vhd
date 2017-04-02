library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity IF_stage is
  port(
    clock : in std_logic;
    reset : in std_logic;
    stall : in std_logic;
    start : in std_logic;   --program is ready to start (program fully transfered to i_memory)
    branch : in std_logic;  -- enable branching
    branch_adr : in integer; --branch address
    fetched_instruction : in std_logic_vector(31 downto 0);
    branch_outcome : in std_logic := '0';
    btb_index : in integer := 0;
    mispredicted : in std_logic := '0';
    i_memread : out std_logic := '0';
    i_memwrite : out std_logic := '0';
    pc : out integer := 0;
    cancel_stall : out std_logic := '0';
    predict_taken : out std_logic := '0'
  );
end IF_stage;

architecture IF_arch of IF_stage is
signal program_counter : integer := 0;
signal previous_pc : integer := 0;
signal next_pc : integer := 0;
signal predict_branch : std_logic;
signal cancel_stall_intermediate : std_logic := '0';
signal cancel_stall_final : std_logic := '0';
signal before_branch_pc : integer := 0;

type one_bit_btb is array(7 downto 0) of std_logic;
signal btb1: one_bit_btb := (others => '0');
type two_bit_btb is array(7 downto 0) of std_logic_vector(1 downto 0);
signal btb2: two_bit_btb := (others =>(others =>'0'));
  
begin
  
  predict_branch <= '1' when fetched_instruction(31 downto 26) = "000100" or fetched_instruction(31 downto 26) = "000101" else
                    '0';
  next_pc <= to_integer(unsigned(fetched_instruction(15 downto 0)));
  
  
  update_btb: process(branch_outcome)
  begin
    if branch_outcome'event then
      btb1(btb_index) <= branch_outcome;
    end if;
  end process;     
      
  update_before_branch_pc: process(predict_branch)
  begin
    if rising_edge(predict_branch) then
      before_branch_pc <= program_counter;
    end if;  
  end process;  
      
  instruction_fecth: process(clock, branch, stall, mispredicted)
  begin
      if start = '1' then
        
        
        
        if rising_edge(clock) then
          cancel_stall_final <= cancel_stall_intermediate;
          cancel_stall_intermediate <= '0';
        end if;
       
        if predict_branch = '1' and falling_edge(clock) then
            if btb1(to_integer(unsigned(fetched_instruction(2 downto 0)))) = '1' then
              pc <= next_pc;
              program_counter <= next_pc;
              cancel_stall_intermediate <= '1';
              predict_taken <= '1';
              previous_pc <= program_counter;
              predict_taken <= '1';
            else
              pc <= program_counter + 1;
              program_counter <= program_counter +1;
              predict_taken <= '0';
              previous_pc <= program_counter;
              predict_taken <= '0';
            end if;
        
        elsif rising_edge(mispredicted) then
          pc <= before_branch_pc;
          program_counter <= before_branch_pc;
          
        elsif (clock = '1' or rising_edge(branch)) and cancel_stall_final = '0' and stall = '0' then
          i_memread <= '1';
          i_memwrite <= '0';
          
          if branch = '1' then
            if program_counter = branch_adr then 
              pc <= program_counter;
              previous_pc <= program_counter;
              program_counter <= program_counter;
            else
              pc <= branch_adr;
              previous_pc <= program_counter;
              program_counter <= branch_adr;
            end if;
            
          else
            pc <= program_counter + 1;
            previous_pc <= program_counter;
            program_counter <= program_counter +1;
          end if;
          
        elsif rising_edge(stall) then
          previous_pc <= previous_pc;
          program_counter <= previous_pc;
          pc <= previous_pc;
          i_memread <= '1';
          i_memwrite <= '0';
        end if;
              
        if falling_edge(clock) then
          i_memread <= '0';
          i_memwrite <= '0';
        end if;
        
      end if;
  end process;

cancel_stall <= cancel_stall_final;  
          
end IF_arch;
        
    
  
  
  