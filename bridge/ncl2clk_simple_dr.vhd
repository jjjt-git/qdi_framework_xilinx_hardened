library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

library qdi_framework;

entity ncl2clk_simple_dr is
	generic (
		dr_width: integer := 2
	);
	port (
		clk, rst: in std_logic;
		dri_0, dri_1: in std_logic_vector(dr_width - 1 downto 0);
		ko: out std_logic;
		valid: out std_logic;
		stall: in  std_logic;
		dro: out std_logic_vector(dr_width - 1 downto 0)
	);
end ncl2clk_simple_dr;

architecture Behavioural of ncl2clk_simple_dr is
	attribute NCL_WIRE_TYPE : string;
	attribute DONT_TOUCH    : boolean;
	attribute ASYNC_REG     : boolean;
	
	attribute KEEP_HIERARCHY : string;
	attribute KEEP_HIERARCHY of Behavioural : architecture is "TRUE";
	attribute KEEP_HIERARCHY of comp        : label is "SOFT";
	
	signal ki, ki_p, ki_s, ki_sp : std_logic;
	
	attribute ASYNC_REG of ki_rm : label is true;
	attribute ASYNC_REG of ki_fs : label is true;
	attribute ASYNC_REG of ki_rs : label is true;
	
	signal ki_vec: std_logic_vector(dr_width - 1 downto 0);
	
	signal ce, ko_int, valid_p: std_logic;
	
	attribute NCL_WIRE_TYPE of ko_mark : label is "NCL_CLK";
	attribute DONT_TOUCH    of ko_mark : label is true;
begin

	ki_vec <= dri_0 or dri_1;
	
	comp: entity qdi_framework.completion_loop
		generic map (
			width => dr_width
		) port map (
			ko_vector => ki_vec,
			ko => ki
		);
	
	di: process(clk) begin
		if rising_edge(clk) then
			if ki_s = '1' and ki_sp = '1' then
				dro <= dri_1;
			end if;
		end if;
	end process di;
	
	ki_rm: FDSE
		port map (
			S  => rst,
			C  => clk,
			CE => ce,
			
			D => ki,
			Q => ki_p
		);
	
	ki_fs: FDSE
		port map (
			S  => rst,
			C  => clk,
			CE => ce,
			
			D => ki_p,
			Q => ki_s
		);
		
	ki_rs: FDSE
		port map (
			S  => rst,
			C  => clk,
			CE => ce,
			
			D => ki_s,
			Q => ki_sp
		);
	
	ko_mark: LUT1
		generic map (
			INIT => "10"
		) port map (
			I0 => ko_int,
			O  => ko
		);
	
	ko_int <= ki_s and ki_sp;
	
	ce <= not valid_p or not stall;
	
	valid <= valid_p;
	valid_p <= ki_sp and not ki_s;
end Behavioural;
