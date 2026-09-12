
library IEEE;
library qdi_framework;
use qdi_framework.MACRO_CONFIG.all;

use IEEE.STD_LOGIC_1164.ALL;

library UNISIM;
use UNISIM.VComponents.all;

entity completion_loop is
	generic (
		max_gate_inputs : integer := 4;
		negated_out     : boolean := true;
		mark_ko         : boolean := false;
		width           : integer := 1
	);
	port (
		ko_vector : in std_logic_vector (width - 1 downto 0);
		ko : out std_logic
	);
end completion_loop;

architecture Structural of completion_loop is
	
	constant owidth : integer := (width - (width mod max_gate_inputs)) / max_gate_inputs + (width mod max_gate_inputs);
	constant ngates : integer := (width - (width mod max_gate_inputs)) / max_gate_inputs;
begin

	assert max_gate_inputs = 4 or max_gate_inputs = 5 report "Please select 4 or 5-input gates" severity FAILURE;
	
	multi: if width > max_gate_inputs generate
		signal next_stage : std_logic_vector(owidth - 1 downto 0);
	begin

		n: entity qdi_framework.completion_loop
			generic map (
				width           => owidth,
				max_gate_inputs => max_gate_inputs,
				negated_out     => negated_out,
				mark_ko         => mark_ko
			) port map (
				ko_vector => next_stage,
				ko => ko
			);
		
		gates: for ii in ngates - 1 downto 0 generate
			g4: if max_gate_inputs = 4 generate
				gate: entity qdi_framework.fb_4
					generic map (
						ASSERT_SET => A5 and B5 and C5 and D5
					) port map (
						A => ko_vector(4 * ii),
						B => ko_vector(4 * ii + 1),
						C => ko_vector(4 * ii + 2),
						D => ko_vector(4 * ii + 3),
						Z => next_stage(ii)
					);
			end generate;
			
			g5: if max_gate_inputs = 5 generate
				gate: entity qdi_framework.fb_5
					generic map (
						ASSERT_SET => A5 and B5 and C5 and D5 and E5
					) port map (
						A => ko_vector(5 * ii),
						B => ko_vector(5 * ii + 1),
						C => ko_vector(5 * ii + 2),
						D => ko_vector(5 * ii + 3),
						E => ko_vector(5 * ii + 4),
						Z => next_stage(ii)
					);
			end generate;
		end generate;
		
		remainder: if width mod max_gate_inputs /= 0 generate
			next_stage(owidth - 1 downto ngates) <= ko_vector(width - 1 downto ngates * max_gate_inputs);
		end generate;
	end generate;
	
	g5: if width = 5 and max_gate_inputs = 5 generate
		signal ko_neg : std_logic;
	begin

		mark: if mark_ko generate
			attribute NCL_WIRE_TYPE : string;
			attribute NCL_WIRE_TYPE of ko_mark : label is "ACK";
			
			attribute DONT_TOUCH : boolean;
			attribute DONT_TOUCH of ko_mark : label is true;
		begin
			ko_mark: LUT1
				generic map (
					INIT => "10"
				) port map (
					I0 => ko_neg
				);
		end generate;
			
		ko <= not ko_neg when negated_out else ko_neg;
	
		gate: entity qdi_framework.fb_5
			generic map (
				ASSERT_SET => A5 and B5 and C5 and D5 and E5
			) port map (
				A => ko_vector(0),
				B => ko_vector(1),
				C => ko_vector(2),
				D => ko_vector(3),
				E => ko_vector(4),
				Z => ko_neg
			);
	end generate;
	
	g4: if width = 4 generate
		signal ko_neg : std_logic;
	begin

		mark: if mark_ko generate
			attribute NCL_WIRE_TYPE : string;
			attribute NCL_WIRE_TYPE of ko_mark : label is "ACK";
			
			attribute DONT_TOUCH : boolean;
			attribute DONT_TOUCH of ko_mark : label is true;
		begin
			ko_mark: LUT1
				generic map (
					INIT => "10"
				) port map (
					I0 => ko_neg
				);
		end generate;
			
		ko <= not ko_neg when negated_out else ko_neg;
	
		gate: entity qdi_framework.fb_4
			generic map (
				ASSERT_SET => A5 and B5 and C5 and D5
			) port map (
				A => ko_vector(0),
				B => ko_vector(1),
				C => ko_vector(2),
				D => ko_vector(3),
				Z => ko_neg
			);
	end generate;
	
	g3: if width = 3 generate
		signal ko_neg : std_logic;
	begin

		mark: if mark_ko generate
			attribute NCL_WIRE_TYPE : string;
			attribute NCL_WIRE_TYPE of ko_mark : label is "ACK";
			
			attribute DONT_TOUCH : boolean;
			attribute DONT_TOUCH of ko_mark : label is true;
		begin
			ko_mark: LUT1
				generic map (
					INIT => "10"
				) port map (
					I0 => ko_neg
				);
		end generate;
			
		ko <= not ko_neg when negated_out else ko_neg;
	
		gate: entity qdi_framework.fb_3
			generic map (
				ASSERT_SET => A5 and B5 and C5
			) port map (
				A => ko_vector(0),
				B => ko_vector(1),
				C => ko_vector(2),
				Z => ko_neg
			);
	end generate;
	
	g2: if width = 2 generate
		signal ko_neg : std_logic;
	begin

		mark: if mark_ko generate
			attribute NCL_WIRE_TYPE : string;
			attribute NCL_WIRE_TYPE of ko_mark : label is "ACK";
			
			attribute DONT_TOUCH : boolean;
			attribute DONT_TOUCH of ko_mark : label is true;
		begin
			ko_mark: LUT1
				generic map (
					INIT => "10"
				) port map (
					I0 => ko_neg
				);
		end generate;
			
		ko <= not ko_neg when negated_out else ko_neg;
	
		gate: entity qdi_framework.fb_2
			generic map (
				ASSERT_SET => A5 and B5
			) port map (
				A => ko_vector(0),
				B => ko_vector(1),
				Z => ko_neg
			);
	end generate;
	
	g1: if width = 1 generate
		mark: if mark_ko generate
			attribute NCL_WIRE_TYPE : string;
			attribute NCL_WIRE_TYPE of ko_mark : label is "ACK";
			
			attribute DONT_TOUCH : boolean;
			attribute DONT_TOUCH of ko_mark : label is true;
		begin
			ko_mark: LUT1
				generic map (
					INIT => "10"
				) port map (
					I0 => ko_vector(0)
				);
		end generate;
			
		ko <= not ko_vector(0) when negated_out else ko_vector(0);
	end generate;
end Structural;
