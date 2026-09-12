library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity fb_4_rst is
	generic (
		RST_VALUE   : bit;
		CLEAR_SET   : bit_vector(31 downto 0) := x"0000_0001";
		ASSERT_SET  : bit_vector(31 downto 0)
	);
	port (
		A, B, C, D, R : in std_logic;
		Z : out std_logic
	);
end fb_4_rst;

architecture Structural of fb_4_rst is
	attribute DONT_TOUCH                         : boolean;
	attribute DONT_TOUCH of NCL_GATE_HARDENED_FN : label is true;
	attribute DONT_TOUCH of NCL_GATE_HARDENED_FB : label is true;

	attribute HLUTNM                        : string;
	attribute HLUTNM of NCL_GATE_HARDENED_FN : label is "gate";
	attribute HLUTNM of NCL_GATE_HARDENED_FB : label is "gate";

	attribute RLOC : string;
	attribute RLOC of NCL_GATE_HARDENED_FN : label is "X0Y0";
	attribute RLOC of NCL_GATE_HARDENED_FB : label is "X0Y0";


	attribute KEEP_HIERARCHY : string;
	attribute KEEP_HIERARCHY of Structural : architecture is "SOFT";

	constant FB_VALUE     : bit_vector(31 downto 0) := x"FFFF0000"; -- I4 FB
	constant CLEAR_F_SET  : bit_vector(31 downto 0) := CLEAR_SET(15 downto 0) & CLEAR_SET(15 downto 0);
	constant ASSERT_F_SET : bit_vector(31 downto 0) := ASSERT_SET(15 downto 0) & ASSERT_SET(15 downto 0);


	constant FUNC : bit_vector(31 downto 0) := ASSERT_F_SET or (not CLEAR_F_SET and FB_VALUE);

	constant CONFIG : bit_vector(31 downto 0) := FUNC;

	signal output, output_r, output_p : std_logic;
begin

	output_p <= transport output_r after 1 ns;

	NCL_GATE_HARDENED_FN: LUT5
		generic map (
			INIT => CONFIG
		) port map (
			I0 => A,
			I1 => B,
			I2 => C,
			I3 => D,
			I4 => output_p,
			O  => output
		);

	NCL_GATE_HARDENED_FB: LUT1
		generic map (
			INIT => "10"
		) port map (
			I0 => output_p,
			O  => Z
		);

	RESET_N: if RST_VALUE = '0' generate
		attribute DONT_TOUCH of RST : label is true;
		attribute RLOC       of RST : label is "X0Y0";
	begin
		RST : LDCE
			port map (
				D => output,
				Q => output_r,

				CLR => R,

				G  => '1',
				GE => '1'
			);
	end generate;

	RESET_D: if RST_VALUE = '1' generate
		attribute DONT_TOUCH of RST : label is true;
		attribute RLOC       of RST : label is "X0Y0";
	begin
		RST : LDPE
			port map (
				D => output,
				Q => output_r,

				PRE => R,

				G  => '1',
				GE => '1'
			);
	end generate;

end Structural;
