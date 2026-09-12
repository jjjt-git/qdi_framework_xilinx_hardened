library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity fb_2_rst is
	generic (
		CLEAR_SET   : bit_vector(31 downto 0) := x"0000_0001";
		ASSERT_SET  : bit_vector(31 downto 0)
	);
	port (
		A, B : in std_logic;
		Z : out std_logic
	);
end fb_2_rst;

architecture Structural of fb_2_rst is
	attribute DONT_TOUCH                         : boolean;
	attribute DONT_TOUCH of NCL_GATE_HARDENED_FN : label is true;
	attribute DONT_TOUCH of NCL_GATE_HARDENED_FB : label is true;

	attribute HLUTNM                        : string;
	attribute HLUTNM of NCL_GATE_HARDENED_FN : label is "gate";
	attribute HLUTNM of NCL_GATE_HARDENED_FB : label is "gate";

	attribute KEEP_HIERARCHY : string;
	attribute KEEP_HIERARCHY of Structural : architecture is "SOFT";

	constant FB_VALUE     : bit_vector(7 downto 0) := x"F0"; -- I2 is FB
	constant CLEAR_F_SET  : bit_vector(7 downto 0) := CLEAR_SET(3 downto 0) & CLEAR_SET(3 downto 0);
	constant ASSERT_F_SET : bit_vector(7 downto 0) := ASSERT_SET(3 downto 0) & ASSERT_SET(3 downto 0);

	constant FUNC : bit_vector(7 downto 0) := ASSERT_F_SET or (not CLEAR_F_SET and FB_VALUE);

	constant CONFIG : bit_vector(7 downto 0) := FUNC;

	signal output, output_p : std_logic;
begin

	output_p <= transport output after 1 ns;

	NCL_GATE_HARDENED_FN: LUT3
		generic map (
			INIT => CONFIG
		) port map (
			I0 => A,
			I1 => B,
			I2 => output_p,
			O  => output
		);

	NCL_GATE_HARDENED_FB: LUT1
		generic map (
			INIT => "10"
		) port map (
			I0 => output_p,
			O  => Z
		);

end Structural;
