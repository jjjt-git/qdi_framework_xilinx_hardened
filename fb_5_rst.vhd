library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VComponents.all;

entity fb_5_rst is
	generic (
		RST_VALUE   : bit;
		CLEAR_SET   : bit_vector(31 downto 0) := x"0000_0001";
		ASSERT_SET  : bit_vector(31 downto 0)
	);
	port (
		A, B, C, D, E, R : in std_logic;
		Z : out std_logic
	);
end fb_5_rst;

architecture Structural of fb_5_rst is
begin
	assert false report "Hardened primitive for fb_5_rst is not available!" severity FAILURE;
end Structural;
