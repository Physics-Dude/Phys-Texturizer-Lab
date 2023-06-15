if not CLIENT then return end
--[[--------------------------------------------------------------------------------------------------------------------------
--
-- want to add your own textures to the spawnmenu post processing tab? use lines like this.
-- list.Set( "TexturizeMaterials", "TITLETEXT", { Material = "path/in/materials.png", Icon = "path/in/materials.png" } )
--
]]----------------------------------------------------------------------------------------------------------------------------
local addonName = "Phys' Texture Lab"
local folderInData = "phys_texture_lab/"

local entropy = CreateClientConVar("physTextureLab_entropy", "100", false, false, "Roughly defines how many colors will be generated", 0, 100)
local contrast = CreateClientConVar("physTextureLab_contrast", "128", false, false, "Roughly defines how different/similar each color is to the next", 0, 255)
local method = CreateClientConVar("physTextureLab_method", "0", false, false, "Choose a color generation algorithm", 0, 255)
local inversions = CreateClientConVar("physTextureLab_inversions", "0", false, false, "Choose which channels get inverted", 0, 7)

local defaultArray = {
    0, 29, 41, 26,
    0, 36, 66, 92,
    0, 53, 71,114,
    0, 75, 66, 98,
    0, 65, 116, 137,
    0, 149, 216, 205,
    0, 188, 147, 204,
    0, 255, 255, 255
}
local CGAp0 = {
    0, 0x00, 0x00, 0x00,
    0, 0x00, 0x00, 0x00,
    0, 0x55, 0xFF, 0x55,
    0, 0x55, 0xFF, 0x55,
    0, 0xFF, 0x55, 0x55,
    0, 0xFF, 0x55, 0x55,
    0, 0xFF, 0xFF, 0x55,
    0, 0xFF, 0xFF, 0x55,
}
local CGAp1 = {
    0, 0x00, 0x00, 0x00,
    0, 0x00, 0x00, 0x00,
    0, 0x55, 0xFF, 0xFF,
    0, 0x55, 0xFF, 0xFF,
    0, 0xFF, 0x55, 0xFF,
    0, 0xFF, 0x55, 0xFF,
    0, 0xFF, 0xFF, 0xFF,
    0, 0xFF, 0xFF, 0xFF,
}

local fullArray = defaultArray
local lastFullColor = {}
local col = {}
local inversionsGetInt = 0
local historyPanelOpen = false
local colorPanelOpen = false
local phystexturelab = phystexturelab or {}
local oldColorPanelPosX, oldColorPanelPosY = 0,0

--[[--
This addon uses code from LibDeflate 1.0.2-release to create the compressed zlib block in a png.
https://github.com/SafeteeWoW/LibDeflate
--]]

---v--- collapse here ---v---
local LibDeflate do 
do
  -- Semantic version. all lowercase.
  -- Suffix can be alpha1, alpha2, beta1, beta2, rc1, rc2, etc.
  -- NOTE: Two version numbers needs to modify.
  -- 1. On the top of LibDeflate.lua
  -- 2. _VERSION
  -- 3. _MINOR

  -- version to store the official version of LibDeflate
  local _VERSION = "1.0.2-release"

  -- When MAJOR is changed, I should name it as LibDeflate2
  local _MAJOR = "LibDeflate"

  -- Update this whenever a new version, for LibStub version registration.
  -- 0 : v0.x
  -- 1 : v1.0.0
  -- 2 : v1.0.1
  -- 3 : v1.0.2
  local _MINOR = 3

  local _COPYRIGHT = "LibDeflate " .. _VERSION ..
					   " Copyright (C) 2018-2021 Haoqian He." ..
					   " Licensed under the zlib License"

  -- Register in the World of Warcraft library "LibStub" if detected.
  if LibStub then
	local lib, minor = LibStub:GetLibrary(_MAJOR, true)
	if lib and minor and minor >= _MINOR then -- No need to update.
	  return lib
	else -- Update or first time register
	  LibDeflate = LibStub:NewLibrary(_MAJOR, _MINOR)
	  -- NOTE: It is important that new version has implemented
	  -- all exported APIs and tables in the old version,
	  -- so the old library is fully garbage collected,
	  -- and we 100% ensure the backward compatibility.
	end
  else -- "LibStub" is not detected.
	LibDeflate = {}
  end

  LibDeflate._VERSION = _VERSION
  LibDeflate._MAJOR = _MAJOR
  LibDeflate._MINOR = _MINOR
  LibDeflate._COPYRIGHT = _COPYRIGHT
end

-- localize Lua api for faster access.
local assert = assert
local error = error
local pairs = pairs
local string_byte = string.byte
local string_char = string.char
local string_find = string.find
local string_gsub = string.gsub
local string_sub = string.sub
local table_concat = table.concat
local table_sort = table.sort
local tostring = tostring
local type = type

-- Converts i to 2^i, (0<=i<=32)
-- This is used to implement bit left shift and bit right shift.
-- "x >> y" in C:   "(x-x%_pow2[y])/_pow2[y]" in Lua
-- "x << y" in C:   "x*_pow2[y]" in Lua
local _pow2 = {}

-- Converts any byte to a character, (0<=byte<=255)
local _byte_to_char = {}

-- _reverseBitsTbl[len][val] stores the bit reverse of
-- the number with bit length "len" and value "val"
-- For example, decimal number 6 with bits length 5 is binary 00110
-- It's reverse is binary 01100,
-- which is decimal 12 and 12 == _reverseBitsTbl[5][6]
-- 1<=len<=9, 0<=val<=2^len-1
-- The reason for 1<=len<=9 is that the max of min bitlen of huffman code
-- of a huffman alphabet is 9?
local _reverse_bits_tbl = {}

-- Convert a LZ77 length (3<=len<=258) to
-- a deflate literal/LZ77_length code (257<=code<=285)
local _length_to_deflate_code = {}

-- convert a LZ77 length (3<=len<=258) to
-- a deflate literal/LZ77_length code extra bits.
local _length_to_deflate_extra_bits = {}

-- Convert a LZ77 length (3<=len<=258) to
-- a deflate literal/LZ77_length code extra bit length.
local _length_to_deflate_extra_bitlen = {}

-- Convert a small LZ77 distance (1<=dist<=256) to a deflate code.
local _dist256_to_deflate_code = {}

-- Convert a small LZ77 distance (1<=dist<=256) to
-- a deflate distance code extra bits.
local _dist256_to_deflate_extra_bits = {}

-- Convert a small LZ77 distance (1<=dist<=256) to
-- a deflate distance code extra bit length.
local _dist256_to_deflate_extra_bitlen = {}

-- Convert a literal/LZ77_length deflate code to LZ77 base length
-- The key of the table is (code - 256), 257<=code<=285
local _literal_deflate_code_to_base_len =
  {
	3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67,
	83, 99, 115, 131, 163, 195, 227, 258
  }

-- Convert a literal/LZ77_length deflate code to base LZ77 length extra bits
-- The key of the table is (code - 256), 257<=code<=285
local _literal_deflate_code_to_extra_bitlen =
  {
	0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5,
	5, 5, 5, 0
  }

-- Convert a distance deflate code to base LZ77 distance. (0<=code<=29)
local _dist_deflate_code_to_base_dist = {
  [0] = 1,
  2,
  3,
  4,
  5,
  7,
  9,
  13,
  17,
  25,
  33,
  49,
  65,
  97,
  129,
  193,
  257,
  385,
  513,
  769,
  1025,
  1537,
  2049,
  3073,
  4097,
  6145,
  8193,
  12289,
  16385,
  24577
}

-- Convert a distance deflate code to LZ77 bits length. (0<=code<=29)
local _dist_deflate_code_to_extra_bitlen =
  {
	[0] = 0,
	0,
	0,
	0,
	1,
	1,
	2,
	2,
	3,
	3,
	4,
	4,
	5,
	5,
	6,
	6,
	7,
	7,
	8,
	8,
	9,
	9,
	10,
	10,
	11,
	11,
	12,
	12,
	13,
	13
  }

-- The code order of the first huffman header in the dynamic deflate block.
-- See the page 12 of RFC1951
local _rle_codes_huffman_bitlen_order = {
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15
}

-- The following tables are used by fixed deflate block.
-- The value of these tables are assigned at the bottom of the source.

-- The huffman code of the literal/LZ77_length deflate codes,
-- in fixed deflate block.
local _fix_block_literal_huffman_code

-- Convert huffman code of the literal/LZ77_length to deflate codes,
-- in fixed deflate block.
local _fix_block_literal_huffman_to_deflate_code

-- The bit length of the huffman code of literal/LZ77_length deflate codes,
-- in fixed deflate block.
local _fix_block_literal_huffman_bitlen

-- The count of each bit length of the literal/LZ77_length deflate codes,
-- in fixed deflate block.
local _fix_block_literal_huffman_bitlen_count

-- The huffman code of the distance deflate codes,
-- in fixed deflate block.
local _fix_block_dist_huffman_code

-- Convert huffman code of the distance to deflate codes,
-- in fixed deflate block.
local _fix_block_dist_huffman_to_deflate_code

-- The bit length of the huffman code of the distance deflate codes,
-- in fixed deflate block.
local _fix_block_dist_huffman_bitlen

-- The count of each bit length of the huffman code of
-- the distance deflate codes,
-- in fixed deflate block.
local _fix_block_dist_huffman_bitlen_count

for i = 0, 255 do _byte_to_char[i] = string_char(i) end

do
  local pow = 1
  for i = 0, 32 do
	_pow2[i] = pow
	pow = pow * 2
  end
end

for i = 1, 9 do
  _reverse_bits_tbl[i] = {}
  for j = 0, _pow2[i + 1] - 1 do
	local reverse = 0
	local value = j
	for _ = 1, i do
	  -- The following line is equivalent to "res | (code %2)" in C.
	  reverse = reverse - reverse % 2 +
				  (((reverse % 2 == 1) or (value % 2) == 1) and 1 or 0)
	  value = (value - value % 2) / 2
	  reverse = reverse * 2
	end
	_reverse_bits_tbl[i][j] = (reverse - reverse % 2) / 2
  end
end

-- The source code is written according to the pattern in the numbers
-- in RFC1951 Page10.
do
  local a = 18
  local b = 16
  local c = 265
  local bitlen = 1
  for len = 3, 258 do
	if len <= 10 then
	  _length_to_deflate_code[len] = len + 254
	  _length_to_deflate_extra_bitlen[len] = 0
	elseif len == 258 then
	  _length_to_deflate_code[len] = 285
	  _length_to_deflate_extra_bitlen[len] = 0
	else
	  if len > a then
		a = a + b
		b = b * 2
		c = c + 4
		bitlen = bitlen + 1
	  end
	  local t = len - a - 1 + b / 2
	  _length_to_deflate_code[len] = (t - (t % (b / 8))) / (b / 8) + c
	  _length_to_deflate_extra_bitlen[len] = bitlen
	  _length_to_deflate_extra_bits[len] = t % (b / 8)
	end
  end
end

-- The source code is written according to the pattern in the numbers
-- in RFC1951 Page11.
do
  _dist256_to_deflate_code[1] = 0
  _dist256_to_deflate_code[2] = 1
  _dist256_to_deflate_extra_bitlen[1] = 0
  _dist256_to_deflate_extra_bitlen[2] = 0

  local a = 3
  local b = 4
  local code = 2
  local bitlen = 0
  for dist = 3, 256 do
	if dist > b then
	  a = a * 2
	  b = b * 2
	  code = code + 2
	  bitlen = bitlen + 1
	end
	_dist256_to_deflate_code[dist] = (dist <= a) and code or (code + 1)
	_dist256_to_deflate_extra_bitlen[dist] = (bitlen < 0) and 0 or bitlen
	if b >= 8 then
	  _dist256_to_deflate_extra_bits[dist] = (dist - b / 2 - 1) % (b / 4)
	end
  end
end

--- Calculate the Adler-32 checksum of the string. <br>
-- See RFC1950 Page 9 https://tools.ietf.org/html/rfc1950 for the
-- definition of Adler-32 checksum.
-- @param str [string] the input string to calcuate its Adler-32 checksum.
-- @return [integer] The Adler-32 checksum, which is greater or equal to 0,
-- and less than 2^32 (4294967296).
function LibDeflate:Adler32(str)
  -- This function is loop unrolled by better performance.
  --
  -- Here is the minimum code:
  --
  -- local a = 1
  -- local b = 0
  -- for i=1, #str do
  -- 		local s = string.byte(str, i, i)
  -- 		a = (a+s)%65521
  -- 		b = (b+a)%65521
  -- 		end
  -- return b*65536+a
  if type(str) ~= "string" then
	error(("Usage: LibDeflate:Adler32(str):" ..
			" 'str' - string expected got '%s'."):format(type(str)), 2)
  end
  local strlen = #str

  local i = 1
  local a = 1
  local b = 0
  while i <= strlen - 15 do
	local x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15, x16 =
	  string_byte(str, i, i + 15)
	b =
	  (b + 16 * a + 16 * x1 + 15 * x2 + 14 * x3 + 13 * x4 + 12 * x5 + 11 * x6 +
		10 * x7 + 9 * x8 + 8 * x9 + 7 * x10 + 6 * x11 + 5 * x12 + 4 * x13 + 3 *
		x14 + 2 * x15 + x16) % 65521
	a =
	  (a + x1 + x2 + x3 + x4 + x5 + x6 + x7 + x8 + x9 + x10 + x11 + x12 + x13 +
		x14 + x15 + x16) % 65521
	i = i + 16
  end
  while (i <= strlen) do
	local x = string_byte(str, i, i)
	a = (a + x) % 65521
	b = (b + a) % 65521
	i = i + 1
  end
  return (b * 65536 + a) % 4294967296
end

-- Compare adler32 checksum.
-- adler32 should be compared with a mod to avoid sign problem
-- 4072834167 (unsigned) is the same adler32 as -222133129
local function IsEqualAdler32(actual, expected)
  return (actual % 4294967296) == (expected % 4294967296)
end

--- Create a preset dictionary.
--
-- This function is not fast, and the memory consumption of the produced
-- dictionary is about 50 times of the input string. Therefore, it is suggestted
-- to run this function only once in your program.
--
-- It is very important to know that if you do use a preset dictionary,
-- compressors and decompressors MUST USE THE SAME dictionary. That is,
-- dictionary must be created using the same string. If you update your program
-- with a new dictionary, people with the old version won't be able to transmit
-- data with people with the new version. Therefore, changing the dictionary
-- must be very careful.
--
-- The parameters "strlen" and "adler32" add a layer of verification to ensure
-- the parameter "str" is not modified unintentionally during the program
-- development.
--
-- @usage local dict_str = "1234567890"
--
-- -- print(dict_str:len(), LibDeflate:Adler32(dict_str))
-- -- Hardcode the print result below to verify it to avoid acciently
-- -- modification of 'str' during the program development.
-- -- string length: 10, Adler-32: 187433486,
-- -- Don't calculate string length and its Adler-32 at run-time.
--
-- local dict = LibDeflate:CreateDictionary(dict_str, 10, 187433486)
--
-- @param str [string] The string used as the preset dictionary. <br>
-- You should put stuffs that frequently appears in the dictionary
-- string and preferablely put more frequently appeared stuffs toward the end
-- of the string. <br>
-- Empty string and string longer than 32768 bytes are not allowed.
-- @param strlen [integer] The length of 'str'. Please pass in this parameter
-- as a hardcoded constant, in order to verify the content of 'str'. The value
-- of this parameter should be known before your program runs.
-- @param adler32 [integer] The Adler-32 checksum of 'str'. Please pass in this
-- parameter as a hardcoded constant, in order to verify the content of 'str'.
-- The value of this parameter should be known before your program runs.
-- @return  [table] The dictionary used for preset dictionary compression and
-- decompression.
-- @raise error if 'strlen' does not match the length of 'str',
-- or if 'adler32' does not match the Adler-32 checksum of 'str'.
function LibDeflate:CreateDictionary(str, strlen, adler32)
  if type(str) ~= "string" then
	error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):" ..
			" 'str' - string expected got '%s'."):format(type(str)), 2)
  end
  if type(strlen) ~= "number" then
	error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):" ..
			" 'strlen' - number expected got '%s'."):format(type(strlen)), 2)
  end
  if type(adler32) ~= "number" then
	error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):" ..
			" 'adler32' - number expected got '%s'."):format(type(adler32)), 2)
  end
  if strlen ~= #str then
	error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):" ..
			" 'strlen' does not match the actual length of 'str'." ..
			" 'strlen': %u, '#str': %u ." ..
			" Please check if 'str' is modified unintentionally."):format(
			strlen, #str))
  end
  if strlen == 0 then
	error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):" ..
			" 'str' - Empty string is not allowed."), 2)
  end
  if strlen > 32768 then
	error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):" ..
			" 'str' - string longer than 32768 bytes is not allowed." ..
			" Got %d bytes."):format(strlen), 2)
  end
  local actual_adler32 = self:Adler32(str)
  if not IsEqualAdler32(adler32, actual_adler32) then
	error(("Usage: LibDeflate:CreateDictionary(str, strlen, adler32):" ..
			" 'adler32' does not match the actual adler32 of 'str'." ..
			" 'adler32': %u, 'Adler32(str)': %u ." ..
			" Please check if 'str' is modified unintentionally."):format(
			adler32, actual_adler32))
  end

  local dictionary = {}
  dictionary.adler32 = adler32
  dictionary.hash_tables = {}
  dictionary.string_table = {}
  dictionary.strlen = strlen
  local string_table = dictionary.string_table
  local hash_tables = dictionary.hash_tables
  string_table[1] = string_byte(str, 1, 1)
  string_table[2] = string_byte(str, 2, 2)
  if strlen >= 3 then
	local i = 1
	local hash = string_table[1] * 256 + string_table[2]
	while i <= strlen - 2 - 3 do
	  local x1, x2, x3, x4 = string_byte(str, i + 2, i + 5)
	  string_table[i + 2] = x1
	  string_table[i + 3] = x2
	  string_table[i + 4] = x3
	  string_table[i + 5] = x4
	  hash = (hash * 256 + x1) % 16777216
	  local t = hash_tables[hash]
	  if not t then
		t = {};
		hash_tables[hash] = t
	  end
	  t[#t + 1] = i - strlen
	  i = i + 1
	  hash = (hash * 256 + x2) % 16777216
	  t = hash_tables[hash]
	  if not t then
		t = {};
		hash_tables[hash] = t
	  end
	  t[#t + 1] = i - strlen
	  i = i + 1
	  hash = (hash * 256 + x3) % 16777216
	  t = hash_tables[hash]
	  if not t then
		t = {};
		hash_tables[hash] = t
	  end
	  t[#t + 1] = i - strlen
	  i = i + 1
	  hash = (hash * 256 + x4) % 16777216
	  t = hash_tables[hash]
	  if not t then
		t = {};
		hash_tables[hash] = t
	  end
	  t[#t + 1] = i - strlen
	  i = i + 1
	end
	while i <= strlen - 2 do
	  local x = string_byte(str, i + 2)
	  string_table[i + 2] = x
	  hash = (hash * 256 + x) % 16777216
	  local t = hash_tables[hash]
	  if not t then
		t = {};
		hash_tables[hash] = t
	  end
	  t[#t + 1] = i - strlen
	  i = i + 1
	end
  end
  return dictionary
end

-- Check if the dictionary is valid.
-- @param dictionary The preset dictionary for compression and decompression.
-- @return true if valid, false if not valid.
-- @return if not valid, the error message.
local function IsValidDictionary(dictionary)
  if type(dictionary) ~= "table" then
	return false,
		   ("'dictionary' - table expected got '%s'."):format(type(dictionary))
  end
  if type(dictionary.adler32) ~= "number" or type(dictionary.string_table) ~=
	"table" or type(dictionary.strlen) ~= "number" or dictionary.strlen <= 0 or
	dictionary.strlen > 32768 or dictionary.strlen ~= #dictionary.string_table or
	type(dictionary.hash_tables) ~= "table" then
	return false,
		   ("'dictionary' - corrupted dictionary."):format(type(dictionary))
  end
  return true, ""
end

--[[
	key of the configuration table is the compression level,
	and its value stores the compression setting.
	These numbers come from zlib source code.

	Higher compression level usually means better compression.
	(Because LibDeflate uses a simplified version of zlib algorithm,
	there is no guarantee that higher compression level does not create
	bigger file than lower level, but I can say it's 99% likely)

	Be careful with the high compression level. This is a pure lua
	implementation compressor/decompressor, which is significant slower than
	a C/C++ equivalant compressor/decompressor. Very high compression level
	costs significant more CPU time, and usually compression size won't be
	significant smaller when you increase compression level by 1, when the
	level is already very high. Benchmark yourself if you can afford it.

	See also https://github.com/madler/zlib/blob/master/doc/algorithm.txt,
	https://github.com/madler/zlib/blob/master/deflate.c for more information.

	The meaning of each field:
	@field 1 use_lazy_evaluation:
		true/false. Whether the program uses lazy evaluation.
		See what is "lazy evaluation" in the link above.
		lazy_evaluation improves ratio, but relatively slow.
	@field 2 good_prev_length:
		Only effective if lazy is set, Only use 1/4 of max_chain,
		if prev length of lazy match is above this.
	@field 3 max_insert_length/max_lazy_match:
		If not using lazy evaluation,
		insert new strings in the hash table only if the match length is not
		greater than this length.
		If using lazy evaluation, only continue lazy evaluation,
		if previous match length is strictly smaller than this value.
	@field 4 nice_length:
		Number. Don't continue to go down the hash chain,
		if match length is above this.
	@field 5 max_chain:
		Number. The maximum number of hash chains we look.
--]]
local _compression_level_configs = {
  [0] = {false, nil, 0, 0, 0}, -- level 0, no compression
  [1] = {false, nil, 4, 8, 4}, -- level 1, similar to zlib level 1
  [2] = {false, nil, 5, 18, 8}, -- level 2, similar to zlib level 2
  [3] = {false, nil, 6, 32, 32}, -- level 3, similar to zlib level 3
  [4] = {true, 4, 4, 16, 16}, -- level 4, similar to zlib level 4
  [5] = {true, 8, 16, 32, 32}, -- level 5, similar to zlib level 5
  [6] = {true, 8, 16, 128, 128}, -- level 6, similar to zlib level 6
  [7] = {true, 8, 32, 128, 256}, -- (SLOW) level 7, similar to zlib level 7
  [8] = {true, 32, 128, 258, 1024}, -- (SLOW) level 8,similar to zlib level 8
  [9] = {true, 32, 258, 258, 4096}
  -- (VERY SLOW) level 9, similar to zlib level 9
}

-- Check if the compression/decompression arguments is valid
-- @param str The input string.
-- @param check_dictionary if true, check if dictionary is valid.
-- @param dictionary The preset dictionary for compression and decompression.
-- @param check_configs if true, check if config is valid.
-- @param configs The compression configuration table
-- @return true if valid, false if not valid.
-- @return if not valid, the error message.
local function IsValidArguments(str, check_dictionary, dictionary,
								check_configs, configs)

  if type(str) ~= "string" then
	return false, ("'str' - string expected got '%s'."):format(type(str))
  end
  if check_dictionary then
	local dict_valid, dict_err = IsValidDictionary(dictionary)
	if not dict_valid then return false, dict_err end
  end
  if check_configs then
	local type_configs = type(configs)
	if type_configs ~= "nil" and type_configs ~= "table" then
	  return false, ("'configs' - nil or table expected got '%s'."):format(
			   type(configs))
	end
	if type_configs == "table" then
	  for k, v in pairs(configs) do
		if k ~= "level" and k ~= "strategy" then
		  return false,
				 ("'configs' - unsupported table key in the configs: '%s'."):format(
				   k)
		elseif k == "level" and not _compression_level_configs[v] then
		  return false,
				 ("'configs' - unsupported 'level': %s."):format(tostring(v))
		elseif k == "strategy" and v ~= "fixed" and v ~= "huffman_only" and v ~=
		  "dynamic" then
		  -- random_block_type is for testing purpose
		  return false, ("'configs' - unsupported 'strategy': '%s'."):format(
				   tostring(v))
		end
	  end
	end
  end
  return true, ""
end

--[[ --------------------------------------------------------------------------
	Compress code
--]] --------------------------------------------------------------------------

-- partial flush to save memory
local _FLUSH_MODE_MEMORY_CLEANUP = 0
-- full flush with partial bytes
local _FLUSH_MODE_OUTPUT = 1
-- write bytes to get to byte boundary
local _FLUSH_MODE_BYTE_BOUNDARY = 2
-- no flush, just get num of bits written so far
local _FLUSH_MODE_NO_FLUSH = 3

--[[
	Create an empty writer to easily write stuffs as the unit of bits.
	Return values:
	1. WriteBits(code, bitlen):
	2. WriteString(str):
	3. Flush(mode):
--]]
local function CreateWriter()
  local buffer_size = 0
  local cache = 0
  local cache_bitlen = 0
  local total_bitlen = 0
  local buffer = {}
  -- When buffer is big enough, flush into result_buffer to save memory.
  local result_buffer = {}

  -- Write bits with value "value" and bit length of "bitlen" into writer.
  -- @param value: The value being written
  -- @param bitlen: The bit length of "value"
  -- @return nil
  local function WriteBits(value, bitlen)
	cache = cache + value * _pow2[cache_bitlen]
	cache_bitlen = cache_bitlen + bitlen
	total_bitlen = total_bitlen + bitlen
	-- Only bulk to buffer every 4 bytes. This is quicker.
	if cache_bitlen >= 32 then
	  buffer_size = buffer_size + 1
	  buffer[buffer_size] = _byte_to_char[cache % 256] ..
							  _byte_to_char[((cache - cache % 256) / 256 % 256)] ..
							  _byte_to_char[((cache - cache % 65536) / 65536 %
								256)] ..
							  _byte_to_char[((cache - cache % 16777216) /
								16777216 % 256)]
	  local rshift_mask = _pow2[32 - cache_bitlen + bitlen]
	  cache = (value - value % rshift_mask) / rshift_mask
	  cache_bitlen = cache_bitlen - 32
	end
  end

  -- Write the entire string into the writer.
  -- @param str The string being written
  -- @return nil
  local function WriteString(str)
	for _ = 1, cache_bitlen, 8 do
	  buffer_size = buffer_size + 1
	  buffer[buffer_size] = string_char(cache % 256)
	  cache = (cache - cache % 256) / 256
	end
	cache_bitlen = 0
	buffer_size = buffer_size + 1
	buffer[buffer_size] = str
	total_bitlen = total_bitlen + #str * 8
  end

  -- Flush current stuffs in the writer and return it.
  -- This operation will free most of the memory.
  -- @param mode See the descrtion of the constant and the source code.
  -- @return The total number of bits stored in the writer right now.
  -- for byte boundary mode, it includes the padding bits.
  -- for output mode, it does not include padding bits.
  -- @return Return the outputs if mode is output.
  local function FlushWriter(mode)
	if mode == _FLUSH_MODE_NO_FLUSH then return total_bitlen end

	if mode == _FLUSH_MODE_OUTPUT or mode == _FLUSH_MODE_BYTE_BOUNDARY then
	  -- Full flush, also output cache.
	  -- Need to pad some bits if cache_bitlen is not multiple of 8.
	  local padding_bitlen = (8 - cache_bitlen % 8) % 8

	  if cache_bitlen > 0 then
		-- padding with all 1 bits, mainly because "\000" is not
		-- good to be tranmitted. I do this so "\000" is a little bit
		-- less frequent.
		cache = cache - _pow2[cache_bitlen] +
				  _pow2[cache_bitlen + padding_bitlen]
		for _ = 1, cache_bitlen, 8 do
		  buffer_size = buffer_size + 1
		  buffer[buffer_size] = _byte_to_char[cache % 256]
		  cache = (cache - cache % 256) / 256
		end

		cache = 0
		cache_bitlen = 0
	  end
	  if mode == _FLUSH_MODE_BYTE_BOUNDARY then
		total_bitlen = total_bitlen + padding_bitlen
		return total_bitlen
	  end
	end

	local flushed = table_concat(buffer)
	buffer = {}
	buffer_size = 0
	result_buffer[#result_buffer + 1] = flushed

	if mode == _FLUSH_MODE_MEMORY_CLEANUP then
	  return total_bitlen
	else
	  return total_bitlen, table_concat(result_buffer)
	end
  end

  return WriteBits, WriteString, FlushWriter
end

-- Push an element into a max heap
-- @param heap A max heap whose max element is at index 1.
-- @param e The element to be pushed. Assume element "e" is a table
--  and comparison is done via its first entry e[1]
-- @param heap_size current number of elements in the heap.
--  NOTE: There may be some garbage stored in
--  heap[heap_size+1], heap[heap_size+2], etc..
-- @return nil
local function MinHeapPush(heap, e, heap_size)
  heap_size = heap_size + 1
  heap[heap_size] = e
  local value = e[1]
  local pos = heap_size
  local parent_pos = (pos - pos % 2) / 2

  while (parent_pos >= 1 and heap[parent_pos][1] > value) do
	local t = heap[parent_pos]
	heap[parent_pos] = e
	heap[pos] = t
	pos = parent_pos
	parent_pos = (parent_pos - parent_pos % 2) / 2
  end
end

-- Pop an element from a max heap
-- @param heap A max heap whose max element is at index 1.
-- @param heap_size current number of elements in the heap.
-- @return the poped element
-- Note: This function does not change table size of "heap" to save CPU time.
local function MinHeapPop(heap, heap_size)
  local top = heap[1]
  local e = heap[heap_size]
  local value = e[1]
  heap[1] = e
  heap[heap_size] = top
  heap_size = heap_size - 1

  local pos = 1
  local left_child_pos = pos * 2
  local right_child_pos = left_child_pos + 1

  while (left_child_pos <= heap_size) do
	local left_child = heap[left_child_pos]
	if (right_child_pos <= heap_size and heap[right_child_pos][1] <
	  left_child[1]) then
	  local right_child = heap[right_child_pos]
	  if right_child[1] < value then
		heap[right_child_pos] = e
		heap[pos] = right_child
		pos = right_child_pos
		left_child_pos = pos * 2
		right_child_pos = left_child_pos + 1
	  else
		break
	  end
	else
	  if left_child[1] < value then
		heap[left_child_pos] = e
		heap[pos] = left_child
		pos = left_child_pos
		left_child_pos = pos * 2
		right_child_pos = left_child_pos + 1
	  else
		break
	  end
	end
  end

  return top
end

-- Deflate defines a special huffman tree, which is unique once the bit length
-- of huffman code of all symbols are known.
-- @param bitlen_count Number of symbols with a specific bitlen
-- @param symbol_bitlen The bit length of a symbol
-- @param max_symbol The max symbol among all symbols,
--		which is (number of symbols - 1)
-- @param max_bitlen The max huffman bit length among all symbols.
-- @return The huffman code of all symbols.
local function GetHuffmanCodeFromBitlen(bitlen_counts, symbol_bitlens,
										max_symbol, max_bitlen)
  local huffman_code = 0
  local next_codes = {}
  local symbol_huffman_codes = {}
  for bitlen = 1, max_bitlen do
	huffman_code = (huffman_code + (bitlen_counts[bitlen - 1] or 0)) * 2
	next_codes[bitlen] = huffman_code
  end
  for symbol = 0, max_symbol do
	local bitlen = symbol_bitlens[symbol]
	if bitlen then
	  huffman_code = next_codes[bitlen]
	  next_codes[bitlen] = huffman_code + 1

	  -- Reverse the bits of huffman code,
	  -- because most signifant bits of huffman code
	  -- is stored first into the compressed data.
	  -- @see RFC1951 Page5 Section 3.1.1
	  if bitlen <= 9 then -- Have cached reverse for small bitlen.
		symbol_huffman_codes[symbol] = _reverse_bits_tbl[bitlen][huffman_code]
	  else
		local reverse = 0
		for _ = 1, bitlen do
		  reverse = reverse - reverse % 2 +
					  (((reverse % 2 == 1) or (huffman_code % 2) == 1) and 1 or
						0)
		  huffman_code = (huffman_code - huffman_code % 2) / 2
		  reverse = reverse * 2
		end
		symbol_huffman_codes[symbol] = (reverse - reverse % 2) / 2
	  end
	end
  end
  return symbol_huffman_codes
end

-- A helper function to sort heap elements
-- a[1], b[1] is the huffman frequency
-- a[2], b[2] is the symbol value.
local function SortByFirstThenSecond(a, b)
  return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2])
end

-- Calculate the huffman bit length and huffman code.
-- @param symbol_count: A table whose table key is the symbol, and table value
--		is the symbol frenquency (nil means 0 frequency).
-- @param max_bitlen: See description of return value.
-- @param max_symbol: The maximum symbol
-- @return a table whose key is the symbol, and the value is the huffman bit
--		bit length. We guarantee that all bit length <= max_bitlen.
--		For 0<=symbol<=max_symbol, table value could be nil if the frequency
--		of the symbol is 0 or nil.
-- @return a table whose key is the symbol, and the value is the huffman code.
-- @return a number indicating the maximum symbol whose bitlen is not 0.
local function GetHuffmanBitlenAndCode(symbol_counts, max_bitlen, max_symbol)
  local heap_size
  local max_non_zero_bitlen_symbol = -1
  local leafs = {}
  local heap = {}
  local symbol_bitlens = {}
  local symbol_codes = {}
  local bitlen_counts = {}

  --[[
		tree[1]: weight, temporarily used as parent and bitLengths
		tree[2]: symbol
		tree[3]: left child
		tree[4]: right child
	--]]
  local number_unique_symbols = 0
  for symbol, count in pairs(symbol_counts) do
	number_unique_symbols = number_unique_symbols + 1
	leafs[number_unique_symbols] = {count, symbol}
  end

  if (number_unique_symbols == 0) then
	-- no code.
	return {}, {}, -1
  elseif (number_unique_symbols == 1) then
	-- Only one code. In this case, its huffman code
	-- needs to be assigned as 0, and bit length is 1.
	-- This is the only case that the return result
	-- represents an imcomplete huffman tree.
	local symbol = leafs[1][2]
	symbol_bitlens[symbol] = 1
	symbol_codes[symbol] = 0
	return symbol_bitlens, symbol_codes, symbol
  else
	table_sort(leafs, SortByFirstThenSecond)
	heap_size = number_unique_symbols
	for i = 1, heap_size do heap[i] = leafs[i] end

	while (heap_size > 1) do
	  -- Note: pop does not change table size of heap
	  local leftChild = MinHeapPop(heap, heap_size)
	  heap_size = heap_size - 1
	  local rightChild = MinHeapPop(heap, heap_size)
	  heap_size = heap_size - 1
	  local newNode = {leftChild[1] + rightChild[1], -1, leftChild, rightChild}
	  MinHeapPush(heap, newNode, heap_size)
	  heap_size = heap_size + 1
	end

	-- Number of leafs whose bit length is greater than max_len.
	local number_bitlen_overflow = 0

	-- Calculate bit length of all nodes
	local fifo = {heap[1], 0, 0, 0} -- preallocate some spaces.
	local fifo_size = 1
	local index = 1
	heap[1][1] = 0
	while (index <= fifo_size) do -- Breath first search
	  local e = fifo[index]
	  local bitlen = e[1]
	  local symbol = e[2]
	  local left_child = e[3]
	  local right_child = e[4]
	  if left_child then
		fifo_size = fifo_size + 1
		fifo[fifo_size] = left_child
		left_child[1] = bitlen + 1
	  end
	  if right_child then
		fifo_size = fifo_size + 1
		fifo[fifo_size] = right_child
		right_child[1] = bitlen + 1
	  end
	  index = index + 1

	  if (bitlen > max_bitlen) then
		number_bitlen_overflow = number_bitlen_overflow + 1
		bitlen = max_bitlen
	  end
	  if symbol >= 0 then
		symbol_bitlens[symbol] = bitlen
		max_non_zero_bitlen_symbol = (symbol > max_non_zero_bitlen_symbol) and
									   symbol or max_non_zero_bitlen_symbol
		bitlen_counts[bitlen] = (bitlen_counts[bitlen] or 0) + 1
	  end
	end

	-- Resolve bit length overflow
	-- @see ZLib/trees.c:gen_bitlen(s, desc), for reference
	if (number_bitlen_overflow > 0) then
	  repeat
		local bitlen = max_bitlen - 1
		while ((bitlen_counts[bitlen] or 0) == 0) do bitlen = bitlen - 1 end
		-- move one leaf down the tree
		bitlen_counts[bitlen] = bitlen_counts[bitlen] - 1
		-- move one overflow item as its brother
		bitlen_counts[bitlen + 1] = (bitlen_counts[bitlen + 1] or 0) + 2
		bitlen_counts[max_bitlen] = bitlen_counts[max_bitlen] - 1
		number_bitlen_overflow = number_bitlen_overflow - 2
	  until (number_bitlen_overflow <= 0)

	  index = 1
	  for bitlen = max_bitlen, 1, -1 do
		local n = bitlen_counts[bitlen] or 0
		while (n > 0) do
		  local symbol = leafs[index][2]
		  symbol_bitlens[symbol] = bitlen
		  n = n - 1
		  index = index + 1
		end
	  end
	end

	symbol_codes = GetHuffmanCodeFromBitlen(bitlen_counts, symbol_bitlens,
											max_symbol, max_bitlen)
	return symbol_bitlens, symbol_codes, max_non_zero_bitlen_symbol
  end
end

-- Calculate the first huffman header in the dynamic huffman block
-- @see RFC1951 Page 12
-- @param lcode_bitlen: The huffman bit length of literal/LZ77_length.
-- @param max_non_zero_bitlen_lcode: The maximum literal/LZ77_length symbol
--		whose huffman bit length is not zero.
-- @param dcode_bitlen: The huffman bit length of LZ77 distance.
-- @param max_non_zero_bitlen_dcode: The maximum LZ77 distance symbol
--		whose huffman bit length is not zero.
-- @return The run length encoded codes.
-- @return The extra bits. One entry for each rle code that needs extra bits.
--		(code == 16 or 17 or 18).
-- @return The count of appearance of each rle codes.
local function RunLengthEncodeHuffmanBitlen(lcode_bitlens,
											max_non_zero_bitlen_lcode,
											dcode_bitlens,
											max_non_zero_bitlen_dcode)
  local rle_code_tblsize = 0
  local rle_codes = {}
  local rle_code_counts = {}
  local rle_extra_bits_tblsize = 0
  local rle_extra_bits = {}
  local prev = nil
  local count = 0

  -- If there is no distance code, assume one distance code of bit length 0.
  -- RFC1951: One distance code of zero bits means that
  -- there are no distance codes used at all (the data is all literals).
  max_non_zero_bitlen_dcode = (max_non_zero_bitlen_dcode < 0) and 0 or
								max_non_zero_bitlen_dcode
  local max_code = max_non_zero_bitlen_lcode + max_non_zero_bitlen_dcode + 1

  for code = 0, max_code + 1 do
	local len = (code <= max_non_zero_bitlen_lcode) and
				  (lcode_bitlens[code] or 0) or ((code <= max_code) and
				  (dcode_bitlens[code - max_non_zero_bitlen_lcode - 1] or 0) or
				  nil)
	if len == prev then
	  count = count + 1
	  if len ~= 0 and count == 6 then
		rle_code_tblsize = rle_code_tblsize + 1
		rle_codes[rle_code_tblsize] = 16
		rle_extra_bits_tblsize = rle_extra_bits_tblsize + 1
		rle_extra_bits[rle_extra_bits_tblsize] = 3
		rle_code_counts[16] = (rle_code_counts[16] or 0) + 1
		count = 0
	  elseif len == 0 and count == 138 then
		rle_code_tblsize = rle_code_tblsize + 1
		rle_codes[rle_code_tblsize] = 18
		rle_extra_bits_tblsize = rle_extra_bits_tblsize + 1
		rle_extra_bits[rle_extra_bits_tblsize] = 127
		rle_code_counts[18] = (rle_code_counts[18] or 0) + 1
		count = 0
	  end
	else
	  if count == 1 then
		rle_code_tblsize = rle_code_tblsize + 1
		rle_codes[rle_code_tblsize] = prev
		rle_code_counts[prev] = (rle_code_counts[prev] or 0) + 1
	  elseif count == 2 then
		rle_code_tblsize = rle_code_tblsize + 1
		rle_codes[rle_code_tblsize] = prev
		rle_code_tblsize = rle_code_tblsize + 1
		rle_codes[rle_code_tblsize] = prev
		rle_code_counts[prev] = (rle_code_counts[prev] or 0) + 2
	  elseif count >= 3 then
		rle_code_tblsize = rle_code_tblsize + 1
		local rleCode = (prev ~= 0) and 16 or (count <= 10 and 17 or 18)
		rle_codes[rle_code_tblsize] = rleCode
		rle_code_counts[rleCode] = (rle_code_counts[rleCode] or 0) + 1
		rle_extra_bits_tblsize = rle_extra_bits_tblsize + 1
		rle_extra_bits[rle_extra_bits_tblsize] =
		  (count <= 10) and (count - 3) or (count - 11)
	  end

	  prev = len
	  if len and len ~= 0 then
		rle_code_tblsize = rle_code_tblsize + 1
		rle_codes[rle_code_tblsize] = len
		rle_code_counts[len] = (rle_code_counts[len] or 0) + 1
		count = 0
	  else
		count = 1
	  end
	end
  end

  return rle_codes, rle_extra_bits, rle_code_counts
end

-- Load the string into a table, in order to speed up LZ77.
-- Loop unrolled 16 times to speed this function up.
-- @param str The string to be loaded.
-- @param t The load destination
-- @param start str[index] will be the first character to be loaded.
-- @param end str[index] will be the last character to be loaded
-- @param offset str[index] will be loaded into t[index-offset]
-- @return t
local function LoadStringToTable(str, t, start, stop, offset)
  local i = start - offset
  while i <= stop - 15 - offset do
	t[i], t[i + 1], t[i + 2], t[i + 3], t[i + 4], t[i + 5], t[i + 6], t[i + 7], t[i +
	  8], t[i + 9], t[i + 10], t[i + 11], t[i + 12], t[i + 13], t[i + 14], t[i +
	  15] = string_byte(str, i + offset, i + 15 + offset)
	i = i + 16
  end
  while (i <= stop - offset) do
	t[i] = string_byte(str, i + offset, i + offset)
	i = i + 1
  end
  return t
end

-- Do LZ77 process. This function uses the majority of the CPU time.
-- @see zlib/deflate.c:deflate_fast(), zlib/deflate.c:deflate_slow()
-- @see https://github.com/madler/zlib/blob/master/doc/algorithm.txt
-- This function uses the algorithms used above. You should read the
-- algorithm.txt above to understand what is the hash function and the
-- lazy evaluation.
--
-- The special optimization used here is hash functions used here.
-- The hash function is just the multiplication of the three consective
-- characters. So if the hash matches, it guarantees 3 characters are matched.
-- This optimization can be implemented because Lua table is a hash table.
--
-- @param level integer that describes compression level.
-- @param string_table table that stores the value of string to be compressed.
--			The index of this table starts from 1.
--			The caller needs to make sure all values needed by this function
--			are loaded.
--			Assume "str" is the origin input string into the compressor
--			str[block_start]..str[block_end+3] needs to be loaded into
--			string_table[block_start-offset]..string_table[block_end-offset]
--			If dictionary is presented, the last 258 bytes of the dictionary
--			needs to be loaded into sing_table[-257..0]
--			(See more in the description of offset.)
-- @param hash_tables. The table key is the hash value (0<=hash<=16777216=256^3)
--			The table value is an array0 that stores the indexes of the
--			input data string to be compressed, such that
--			hash == str[index]*str[index+1]*str[index+2]
--			Indexes are ordered in this array.
-- @param block_start The indexes of the input data string to be compressed.
--				that starts the LZ77 block.
-- @param block_end The indexes of the input data string to be compressed.
--				that stores the LZ77 block.
-- @param offset str[index] is stored in string_table[index-offset],
--			This offset is mainly an optimization to limit the index
--			of string_table, so lua can access this table quicker.
-- @param dictionary See LibDeflate:CreateDictionary
-- @return literal/LZ77_length deflate codes.
-- @return the extra bits of literal/LZ77_length deflate codes.
-- @return the count of each literal/LZ77 deflate code.
-- @return LZ77 distance deflate codes.
-- @return the extra bits of LZ77 distance deflate codes.
-- @return the count of each LZ77 distance deflate code.
local function GetBlockLZ77Result(level, string_table, hash_tables, block_start,
								  block_end, offset, dictionary)
  local config = _compression_level_configs[level]
  local config_use_lazy, config_good_prev_length, config_max_lazy_match,
		config_nice_length, config_max_hash_chain = config[1], config[2],
													config[3], config[4],
													config[5]

  local config_max_insert_length = (not config_use_lazy) and
									 config_max_lazy_match or 2147483646
  local config_good_hash_chain =
	(config_max_hash_chain - config_max_hash_chain % 4 / 4)

  local hash

  local dict_hash_tables
  local dict_string_table
  local dict_string_len = 0

  if dictionary then
	dict_hash_tables = dictionary.hash_tables
	dict_string_table = dictionary.string_table
	dict_string_len = dictionary.strlen
	assert(block_start == 1)
	if block_end >= block_start and dict_string_len >= 2 then
	  hash = dict_string_table[dict_string_len - 1] * 65536 +
			   dict_string_table[dict_string_len] * 256 + string_table[1]
	  local t = hash_tables[hash]
	  if not t then
		t = {};
		hash_tables[hash] = t
	  end
	  t[#t + 1] = -1
	end
	if block_end >= block_start + 1 and dict_string_len >= 1 then
	  hash =
		dict_string_table[dict_string_len] * 65536 + string_table[1] * 256 +
		  string_table[2]
	  local t = hash_tables[hash]
	  if not t then
		t = {};
		hash_tables[hash] = t
	  end
	  t[#t + 1] = 0
	end
  end

  local dict_string_len_plus3 = dict_string_len + 3

  hash = (string_table[block_start - offset] or 0) * 256 +
		   (string_table[block_start + 1 - offset] or 0)

  local lcodes = {}
  local lcode_tblsize = 0
  local lcodes_counts = {}
  local dcodes = {}
  local dcodes_tblsize = 0
  local dcodes_counts = {}

  local lextra_bits = {}
  local lextra_bits_tblsize = 0
  local dextra_bits = {}
  local dextra_bits_tblsize = 0

  local match_available = false
  local prev_len
  local prev_dist
  local cur_len = 0
  local cur_dist = 0

  local index = block_start
  local index_end = block_end + (config_use_lazy and 1 or 0)

  -- the zlib source code writes separate code for lazy evaluation and
  -- not lazy evaluation, which is easier to understand.
  -- I put them together, so it is a bit harder to understand.
  -- because I think this is easier for me to maintain it.
  while (index <= index_end) do
	local string_table_index = index - offset
	local offset_minus_three = offset - 3
	prev_len = cur_len
	prev_dist = cur_dist
	cur_len = 0

	hash = (hash * 256 + (string_table[string_table_index + 2] or 0)) % 16777216

	local chain_index
	local cur_chain
	local hash_chain = hash_tables[hash]
	local chain_old_size
	if not hash_chain then
	  chain_old_size = 0
	  hash_chain = {}
	  hash_tables[hash] = hash_chain
	  if dict_hash_tables then
		cur_chain = dict_hash_tables[hash]
		chain_index = cur_chain and #cur_chain or 0
	  else
		chain_index = 0
	  end
	else
	  chain_old_size = #hash_chain
	  cur_chain = hash_chain
	  chain_index = chain_old_size
	end

	if index <= block_end then hash_chain[chain_old_size + 1] = index end

	if (chain_index > 0 and index + 2 <= block_end and
	  (not config_use_lazy or prev_len < config_max_lazy_match)) then

	  local depth =
		(config_use_lazy and prev_len >= config_good_prev_length) and
		  config_good_hash_chain or config_max_hash_chain

	  local max_len_minus_one = block_end - index
	  max_len_minus_one = (max_len_minus_one >= 257) and 257 or
							max_len_minus_one
	  max_len_minus_one = max_len_minus_one + string_table_index
	  local string_table_index_plus_three = string_table_index + 3

	  while chain_index >= 1 and depth > 0 do
		local prev = cur_chain[chain_index]

		if index - prev > 32768 then break end
		if prev < index then
		  local sj = string_table_index_plus_three

		  if prev >= -257 then
			local pj = prev - offset_minus_three
			while (sj <= max_len_minus_one and string_table[pj] ==
			  string_table[sj]) do
			  sj = sj + 1
			  pj = pj + 1
			end
		  else
			local pj = dict_string_len_plus3 + prev
			while (sj <= max_len_minus_one and dict_string_table[pj] ==
			  string_table[sj]) do
			  sj = sj + 1
			  pj = pj + 1
			end
		  end
		  local j = sj - string_table_index
		  if j > cur_len then
			cur_len = j
			cur_dist = index - prev
		  end
		  if cur_len >= config_nice_length then break end
		end

		chain_index = chain_index - 1
		depth = depth - 1
		if chain_index == 0 and prev > 0 and dict_hash_tables then
		  cur_chain = dict_hash_tables[hash]
		  chain_index = cur_chain and #cur_chain or 0
		end
	  end
	end

	if not config_use_lazy then prev_len, prev_dist = cur_len, cur_dist end
	if ((not config_use_lazy or match_available) and
	  (prev_len > 3 or (prev_len == 3 and prev_dist < 4096)) and cur_len <=
	  prev_len) then
	  local code = _length_to_deflate_code[prev_len]
	  local length_extra_bits_bitlen = _length_to_deflate_extra_bitlen[prev_len]
	  local dist_code, dist_extra_bits_bitlen, dist_extra_bits
	  if prev_dist <= 256 then -- have cached code for small distance.
		dist_code = _dist256_to_deflate_code[prev_dist]
		dist_extra_bits = _dist256_to_deflate_extra_bits[prev_dist]
		dist_extra_bits_bitlen = _dist256_to_deflate_extra_bitlen[prev_dist]
	  else
		dist_code = 16
		dist_extra_bits_bitlen = 7
		local a = 384
		local b = 512

		while true do
		  if prev_dist <= a then
			dist_extra_bits = (prev_dist - (b / 2) - 1) % (b / 4)
			break
		  elseif prev_dist <= b then
			dist_extra_bits = (prev_dist - (b / 2) - 1) % (b / 4)
			dist_code = dist_code + 1
			break
		  else
			dist_code = dist_code + 2
			dist_extra_bits_bitlen = dist_extra_bits_bitlen + 1
			a = a * 2
			b = b * 2
		  end
		end
	  end
	  lcode_tblsize = lcode_tblsize + 1
	  lcodes[lcode_tblsize] = code
	  lcodes_counts[code] = (lcodes_counts[code] or 0) + 1

	  dcodes_tblsize = dcodes_tblsize + 1
	  dcodes[dcodes_tblsize] = dist_code
	  dcodes_counts[dist_code] = (dcodes_counts[dist_code] or 0) + 1

	  if length_extra_bits_bitlen > 0 then
		local lenExtraBits = _length_to_deflate_extra_bits[prev_len]
		lextra_bits_tblsize = lextra_bits_tblsize + 1
		lextra_bits[lextra_bits_tblsize] = lenExtraBits
	  end
	  if dist_extra_bits_bitlen > 0 then
		dextra_bits_tblsize = dextra_bits_tblsize + 1
		dextra_bits[dextra_bits_tblsize] = dist_extra_bits
	  end

	  for i = index + 1, index + prev_len - (config_use_lazy and 2 or 1) do
		hash = (hash * 256 + (string_table[i - offset + 2] or 0)) % 16777216
		if prev_len <= config_max_insert_length then
		  hash_chain = hash_tables[hash]
		  if not hash_chain then
			hash_chain = {}
			hash_tables[hash] = hash_chain
		  end
		  hash_chain[#hash_chain + 1] = i
		end
	  end
	  index = index + prev_len - (config_use_lazy and 1 or 0)
	  match_available = false
	elseif (not config_use_lazy) or match_available then
	  local code = string_table[config_use_lazy and (string_table_index - 1) or
					 string_table_index]
	  lcode_tblsize = lcode_tblsize + 1
	  lcodes[lcode_tblsize] = code
	  lcodes_counts[code] = (lcodes_counts[code] or 0) + 1
	  index = index + 1
	else
	  match_available = true
	  index = index + 1
	end
  end

  -- Write "end of block" symbol
  lcode_tblsize = lcode_tblsize + 1
  lcodes[lcode_tblsize] = 256
  lcodes_counts[256] = (lcodes_counts[256] or 0) + 1

  return lcodes, lextra_bits, lcodes_counts, dcodes, dextra_bits, dcodes_counts
end

-- Get the header data of dynamic block.
-- @param lcodes_count The count of each literal/LZ77_length codes.
-- @param dcodes_count The count of each Lz77 distance codes.
-- @return a lots of stuffs.
-- @see RFC1951 Page 12
local function GetBlockDynamicHuffmanHeader(lcodes_counts, dcodes_counts)
  local lcodes_huffman_bitlens, lcodes_huffman_codes, max_non_zero_bitlen_lcode =
	GetHuffmanBitlenAndCode(lcodes_counts, 15, 285)
  local dcodes_huffman_bitlens, dcodes_huffman_codes, max_non_zero_bitlen_dcode =
	GetHuffmanBitlenAndCode(dcodes_counts, 15, 29)

  local rle_deflate_codes, rle_extra_bits, rle_codes_counts =
	RunLengthEncodeHuffmanBitlen(lcodes_huffman_bitlens,
								 max_non_zero_bitlen_lcode,
								 dcodes_huffman_bitlens,
								 max_non_zero_bitlen_dcode)

  local rle_codes_huffman_bitlens, rle_codes_huffman_codes =
	GetHuffmanBitlenAndCode(rle_codes_counts, 7, 18)

  local HCLEN = 0
  for i = 1, 19 do
	local symbol = _rle_codes_huffman_bitlen_order[i]
	local length = rle_codes_huffman_bitlens[symbol] or 0
	if length ~= 0 then HCLEN = i end
  end

  HCLEN = HCLEN - 4
  local HLIT = max_non_zero_bitlen_lcode + 1 - 257
  local HDIST = max_non_zero_bitlen_dcode + 1 - 1
  if HDIST < 0 then HDIST = 0 end

  return HLIT, HDIST, HCLEN, rle_codes_huffman_bitlens, rle_codes_huffman_codes,
		 rle_deflate_codes, rle_extra_bits, lcodes_huffman_bitlens,
		 lcodes_huffman_codes, dcodes_huffman_bitlens, dcodes_huffman_codes
end

-- Get the size of dynamic block without writing any bits into the writer.
-- @param ... Read the source code of GetBlockDynamicHuffmanHeader()
-- @return the bit length of the dynamic block
local function GetDynamicHuffmanBlockSize(lcodes, dcodes, HCLEN,
										  rle_codes_huffman_bitlens,
										  rle_deflate_codes,
										  lcodes_huffman_bitlens,
										  dcodes_huffman_bitlens)

  local block_bitlen = 17 -- 1+2+5+5+4
  block_bitlen = block_bitlen + (HCLEN + 4) * 3

  for i = 1, #rle_deflate_codes do
	local code = rle_deflate_codes[i]
	block_bitlen = block_bitlen + rle_codes_huffman_bitlens[code]
	if code >= 16 then
	  block_bitlen = block_bitlen +
					   ((code == 16) and 2 or (code == 17 and 3 or 7))
	end
  end

  local length_code_count = 0
  for i = 1, #lcodes do
	local code = lcodes[i]
	local huffman_bitlen = lcodes_huffman_bitlens[code]
	block_bitlen = block_bitlen + huffman_bitlen
	if code > 256 then -- Length code
	  length_code_count = length_code_count + 1
	  if code > 264 and code < 285 then -- Length code with extra bits
		local extra_bits_bitlen = _literal_deflate_code_to_extra_bitlen[code -
									256]
		block_bitlen = block_bitlen + extra_bits_bitlen
	  end
	  local dist_code = dcodes[length_code_count]
	  local dist_huffman_bitlen = dcodes_huffman_bitlens[dist_code]
	  block_bitlen = block_bitlen + dist_huffman_bitlen

	  if dist_code > 3 then -- dist code with extra bits
		local dist_extra_bits_bitlen = (dist_code - dist_code % 2) / 2 - 1
		block_bitlen = block_bitlen + dist_extra_bits_bitlen
	  end
	end
  end
  return block_bitlen
end

-- Write dynamic block.
-- @param ... Read the source code of GetBlockDynamicHuffmanHeader()
local function CompressDynamicHuffmanBlock(WriteBits, is_last_block, lcodes,
										   lextra_bits, dcodes, dextra_bits,
										   HLIT, HDIST, HCLEN,
										   rle_codes_huffman_bitlens,
										   rle_codes_huffman_codes,
										   rle_deflate_codes, rle_extra_bits,
										   lcodes_huffman_bitlens,
										   lcodes_huffman_codes,
										   dcodes_huffman_bitlens,
										   dcodes_huffman_codes)

  WriteBits(is_last_block and 1 or 0, 1) -- Last block identifier
  WriteBits(2, 2) -- Dynamic Huffman block identifier

  WriteBits(HLIT, 5)
  WriteBits(HDIST, 5)
  WriteBits(HCLEN, 4)

  for i = 1, HCLEN + 4 do
	local symbol = _rle_codes_huffman_bitlen_order[i]
	local length = rle_codes_huffman_bitlens[symbol] or 0
	WriteBits(length, 3)
  end

  local rleExtraBitsIndex = 1
  for i = 1, #rle_deflate_codes do
	local code = rle_deflate_codes[i]
	WriteBits(rle_codes_huffman_codes[code], rle_codes_huffman_bitlens[code])
	if code >= 16 then
	  local extraBits = rle_extra_bits[rleExtraBitsIndex]
	  WriteBits(extraBits, (code == 16) and 2 or (code == 17 and 3 or 7))
	  rleExtraBitsIndex = rleExtraBitsIndex + 1
	end
  end

  local length_code_count = 0
  local length_code_with_extra_count = 0
  local dist_code_with_extra_count = 0

  for i = 1, #lcodes do
	local deflate_codee = lcodes[i]
	local huffman_code = lcodes_huffman_codes[deflate_codee]
	local huffman_bitlen = lcodes_huffman_bitlens[deflate_codee]
	WriteBits(huffman_code, huffman_bitlen)
	if deflate_codee > 256 then -- Length code
	  length_code_count = length_code_count + 1
	  if deflate_codee > 264 and deflate_codee < 285 then
		-- Length code with extra bits
		length_code_with_extra_count = length_code_with_extra_count + 1
		local extra_bits = lextra_bits[length_code_with_extra_count]
		local extra_bits_bitlen =
		  _literal_deflate_code_to_extra_bitlen[deflate_codee - 256]
		WriteBits(extra_bits, extra_bits_bitlen)
	  end
	  -- Write distance code
	  local dist_deflate_code = dcodes[length_code_count]
	  local dist_huffman_code = dcodes_huffman_codes[dist_deflate_code]
	  local dist_huffman_bitlen = dcodes_huffman_bitlens[dist_deflate_code]
	  WriteBits(dist_huffman_code, dist_huffman_bitlen)

	  if dist_deflate_code > 3 then -- dist code with extra bits
		dist_code_with_extra_count = dist_code_with_extra_count + 1
		local dist_extra_bits = dextra_bits[dist_code_with_extra_count]
		local dist_extra_bits_bitlen = (dist_deflate_code - dist_deflate_code %
										 2) / 2 - 1
		WriteBits(dist_extra_bits, dist_extra_bits_bitlen)
	  end
	end
  end
end

-- Get the size of fixed block without writing any bits into the writer.
-- @param lcodes literal/LZ77_length deflate codes
-- @param decodes LZ77 distance deflate codes
-- @return the bit length of the fixed block
local function GetFixedHuffmanBlockSize(lcodes, dcodes)
  local block_bitlen = 3
  local length_code_count = 0
  for i = 1, #lcodes do
	local code = lcodes[i]
	local huffman_bitlen = _fix_block_literal_huffman_bitlen[code]
	block_bitlen = block_bitlen + huffman_bitlen
	if code > 256 then -- Length code
	  length_code_count = length_code_count + 1
	  if code > 264 and code < 285 then -- Length code with extra bits
		local extra_bits_bitlen = _literal_deflate_code_to_extra_bitlen[code -
									256]
		block_bitlen = block_bitlen + extra_bits_bitlen
	  end
	  local dist_code = dcodes[length_code_count]
	  block_bitlen = block_bitlen + 5

	  if dist_code > 3 then -- dist code with extra bits
		local dist_extra_bits_bitlen = (dist_code - dist_code % 2) / 2 - 1
		block_bitlen = block_bitlen + dist_extra_bits_bitlen
	  end
	end
  end
  return block_bitlen
end

-- Write fixed block.
-- @param lcodes literal/LZ77_length deflate codes
-- @param decodes LZ77 distance deflate codes
local function CompressFixedHuffmanBlock(WriteBits, is_last_block, lcodes,
										 lextra_bits, dcodes, dextra_bits)
  WriteBits(is_last_block and 1 or 0, 1) -- Last block identifier
  WriteBits(1, 2) -- Fixed Huffman block identifier
  local length_code_count = 0
  local length_code_with_extra_count = 0
  local dist_code_with_extra_count = 0
  for i = 1, #lcodes do
	local deflate_code = lcodes[i]
	local huffman_code = _fix_block_literal_huffman_code[deflate_code]
	local huffman_bitlen = _fix_block_literal_huffman_bitlen[deflate_code]
	WriteBits(huffman_code, huffman_bitlen)
	if deflate_code > 256 then -- Length code
	  length_code_count = length_code_count + 1
	  if deflate_code > 264 and deflate_code < 285 then
		-- Length code with extra bits
		length_code_with_extra_count = length_code_with_extra_count + 1
		local extra_bits = lextra_bits[length_code_with_extra_count]
		local extra_bits_bitlen =
		  _literal_deflate_code_to_extra_bitlen[deflate_code - 256]
		WriteBits(extra_bits, extra_bits_bitlen)
	  end
	  -- Write distance code
	  local dist_code = dcodes[length_code_count]
	  local dist_huffman_code = _fix_block_dist_huffman_code[dist_code]
	  WriteBits(dist_huffman_code, 5)

	  if dist_code > 3 then -- dist code with extra bits
		dist_code_with_extra_count = dist_code_with_extra_count + 1
		local dist_extra_bits = dextra_bits[dist_code_with_extra_count]
		local dist_extra_bits_bitlen = (dist_code - dist_code % 2) / 2 - 1
		WriteBits(dist_extra_bits, dist_extra_bits_bitlen)
	  end
	end
  end
end

-- Get the size of store block without writing any bits into the writer.
-- @param block_start The start index of the origin input string
-- @param block_end The end index of the origin input string
-- @param Total bit lens had been written into the compressed result before,
-- because store block needs to shift to byte boundary.
-- @return the bit length of the fixed block
local function GetStoreBlockSize(block_start, block_end, total_bitlen)
  assert(block_end - block_start + 1 <= 65535)
  local block_bitlen = 3
  total_bitlen = total_bitlen + 3
  local padding_bitlen = (8 - total_bitlen % 8) % 8
  block_bitlen = block_bitlen + padding_bitlen
  block_bitlen = block_bitlen + 32
  block_bitlen = block_bitlen + (block_end - block_start + 1) * 8
  return block_bitlen
end

-- Write the store block.
-- @param ... lots of stuffs
-- @return nil
local function CompressStoreBlock(WriteBits, WriteString, is_last_block, str,
								  block_start, block_end, total_bitlen)
  assert(block_end - block_start + 1 <= 65535)
  WriteBits(is_last_block and 1 or 0, 1) -- Last block identifer.
  WriteBits(0, 2) -- Store block identifier.
  total_bitlen = total_bitlen + 3
  local padding_bitlen = (8 - total_bitlen % 8) % 8
  if padding_bitlen > 0 then
	WriteBits(_pow2[padding_bitlen] - 1, padding_bitlen)
  end
  local size = block_end - block_start + 1
  WriteBits(size, 16)

  -- Write size's one's complement
  local comp = (255 - size % 256) + (255 - (size - size % 256) / 256) * 256
  WriteBits(comp, 16)

  WriteString(str:sub(block_start, block_end))
end

-- Do the deflate
-- Currently using a simple way to determine the block size
-- (This is why the compression ratio is little bit worse than zlib when
-- the input size is very large
-- The first block is 64KB, the following block is 32KB.
-- After each block, there is a memory cleanup operation.
-- This is not a fast operation, but it is needed to save memory usage, so
-- the memory usage does not grow unboundly. If the data size is less than
-- 64KB, then memory cleanup won't happen.
-- This function determines whether to use store/fixed/dynamic blocks by
-- calculating the block size of each block type and chooses the smallest one.
local function Deflate(configs, WriteBits, WriteString, FlushWriter, str,
					   dictionary)
  local string_table = {}
  local hash_tables = {}
  local is_last_block = nil
  local block_start
  local block_end
  local bitlen_written
  local total_bitlen = FlushWriter(_FLUSH_MODE_NO_FLUSH)
  local strlen = #str
  local offset

  local level
  local strategy
  if configs then
	if configs.level then level = configs.level end
	if configs.strategy then strategy = configs.strategy end
  end

  if not level then
	if strlen < 2048 then
	  level = 7
	elseif strlen > 65536 then
	  level = 3
	else
	  level = 5
	end
  end

  while not is_last_block do
	if not block_start then
	  block_start = 1
	  block_end = 64 * 1024 - 1
	  offset = 0
	else
	  block_start = block_end + 1
	  block_end = block_end + 32 * 1024
	  offset = block_start - 32 * 1024 - 1
	end

	if block_end >= strlen then
	  block_end = strlen
	  is_last_block = true
	else
	  is_last_block = false
	end

	local lcodes, lextra_bits, lcodes_counts, dcodes, dextra_bits, dcodes_counts

	local HLIT, HDIST, HCLEN, rle_codes_huffman_bitlens,
		  rle_codes_huffman_codes, rle_deflate_codes, rle_extra_bits,
		  lcodes_huffman_bitlens, lcodes_huffman_codes, dcodes_huffman_bitlens,
		  dcodes_huffman_codes

	local dynamic_block_bitlen
	local fixed_block_bitlen
	local store_block_bitlen

	if level ~= 0 then

	  -- GetBlockLZ77 needs block_start to block_end+3 to be loaded.
	  LoadStringToTable(str, string_table, block_start, block_end + 3, offset)
	  if block_start == 1 and dictionary then
		local dict_string_table = dictionary.string_table
		local dict_strlen = dictionary.strlen
		for i = 0, (-dict_strlen + 1) < -257 and -257 or (-dict_strlen + 1), -1 do
		  string_table[i] = dict_string_table[dict_strlen + i]
		end
	  end

	  if strategy == "huffman_only" then
		lcodes = {}
		LoadStringToTable(str, lcodes, block_start, block_end, block_start - 1)
		lextra_bits = {}
		lcodes_counts = {}
		lcodes[block_end - block_start + 2] = 256 -- end of block
		for i = 1, block_end - block_start + 2 do
		  local code = lcodes[i]
		  lcodes_counts[code] = (lcodes_counts[code] or 0) + 1
		end
		dcodes = {}
		dextra_bits = {}
		dcodes_counts = {}
	  else
		lcodes, lextra_bits, lcodes_counts, dcodes, dextra_bits, dcodes_counts =
		  GetBlockLZ77Result(level, string_table, hash_tables, block_start,
							 block_end, offset, dictionary)
	  end

	  -- LuaFormatter off
	  HLIT, HDIST, HCLEN, rle_codes_huffman_bitlens, rle_codes_huffman_codes, rle_deflate_codes,
	   rle_extra_bits, lcodes_huffman_bitlens, lcodes_huffman_codes, dcodes_huffman_bitlens, dcodes_huffman_codes =
	  -- LuaFormatter on
	  GetBlockDynamicHuffmanHeader(lcodes_counts, dcodes_counts)
	  dynamic_block_bitlen = GetDynamicHuffmanBlockSize(lcodes, dcodes, HCLEN,
														rle_codes_huffman_bitlens,
														rle_deflate_codes,
														lcodes_huffman_bitlens,
														dcodes_huffman_bitlens)
	  fixed_block_bitlen = GetFixedHuffmanBlockSize(lcodes, dcodes)
	end

	store_block_bitlen = GetStoreBlockSize(block_start, block_end, total_bitlen)

	local min_bitlen = store_block_bitlen
	min_bitlen = (fixed_block_bitlen and fixed_block_bitlen < min_bitlen) and
				   fixed_block_bitlen or min_bitlen
	min_bitlen =
	  (dynamic_block_bitlen and dynamic_block_bitlen < min_bitlen) and
		dynamic_block_bitlen or min_bitlen

	if level == 0 or
	  (strategy ~= "fixed" and strategy ~= "dynamic" and store_block_bitlen ==
		min_bitlen) then
	  CompressStoreBlock(WriteBits, WriteString, is_last_block, str,
						 block_start, block_end, total_bitlen)
	  total_bitlen = total_bitlen + store_block_bitlen
	elseif strategy ~= "dynamic" and
	  (strategy == "fixed" or fixed_block_bitlen == min_bitlen) then
	  CompressFixedHuffmanBlock(WriteBits, is_last_block, lcodes, lextra_bits,
								dcodes, dextra_bits)
	  total_bitlen = total_bitlen + fixed_block_bitlen
	elseif strategy == "dynamic" or dynamic_block_bitlen == min_bitlen then
	  CompressDynamicHuffmanBlock(WriteBits, is_last_block, lcodes, lextra_bits,
								  dcodes, dextra_bits, HLIT, HDIST, HCLEN,
								  rle_codes_huffman_bitlens,
								  rle_codes_huffman_codes, rle_deflate_codes,
								  rle_extra_bits, lcodes_huffman_bitlens,
								  lcodes_huffman_codes, dcodes_huffman_bitlens,
								  dcodes_huffman_codes)
	  total_bitlen = total_bitlen + dynamic_block_bitlen
	end

	if is_last_block then
	  bitlen_written = FlushWriter(_FLUSH_MODE_NO_FLUSH)
	else
	  bitlen_written = FlushWriter(_FLUSH_MODE_MEMORY_CLEANUP)
	end

	assert(bitlen_written == total_bitlen)

	-- Memory clean up, so memory consumption does not always grow linearly
	-- , even if input string is > 64K.
	-- Not a very efficient operation, but this operation won't happen
	-- when the input data size is less than 64K.
	if not is_last_block then
	  local j
	  if dictionary and block_start == 1 then
		j = 0
		while (string_table[j]) do
		  string_table[j] = nil
		  j = j - 1
		end
	  end
	  dictionary = nil
	  j = 1
	  for i = block_end - 32767, block_end do
		string_table[j] = string_table[i - offset]
		j = j + 1
	  end

	  for k, t in pairs(hash_tables) do
		local tSize = #t
		if tSize > 0 and block_end + 1 - t[1] > 32768 then
		  if tSize == 1 then
			hash_tables[k] = nil
		  else
			local new = {}
			local newSize = 0
			for i = 2, tSize do
			  j = t[i]
			  if block_end + 1 - j <= 32768 then
				newSize = newSize + 1
				new[newSize] = j
			  end
			end
			hash_tables[k] = new
		  end
		end
	  end
	end
  end
end

--- The description to compression configuration table. <br>
-- Any field can be nil to use its default. <br>
-- Table with keys other than those below is an invalid table.
-- @class table
-- @name compression_configs
-- @field level The compression level ranged from 0 to 9. 0 is no compression.
-- 9 is the slowest but best compression. Use nil for default level.
-- @field strategy The compression strategy. "fixed" to only use fixed deflate
-- compression block. "dynamic" to only use dynamic block. "huffman_only" to
-- do no LZ77 compression. Only do huffman compression.

-- @see LibDeflate:CompressDeflate(str, configs)
-- @see LibDeflate:CompressDeflateWithDict(str, dictionary, configs)
local function CompressDeflateInternal(str, dictionary, configs)
  local WriteBits, WriteString, FlushWriter = CreateWriter()
  Deflate(configs, WriteBits, WriteString, FlushWriter, str, dictionary)
  local total_bitlen, result = FlushWriter(_FLUSH_MODE_OUTPUT)
  local padding_bitlen = (8 - total_bitlen % 8) % 8
  return result, padding_bitlen
end

-- @see LibDeflate:CompressZlib
-- @see LibDeflate:CompressZlibWithDict
local function CompressZlibInternal(str, dictionary, configs)
  local WriteBits, WriteString, FlushWriter = CreateWriter()

  local CM = 8 -- Compression method
  local CINFO = 7 -- Window Size = 32K
  local CMF = CINFO * 16 + CM
  WriteBits(CMF, 8)

  local FDIST = dictionary and 1 or 0
  local FLEVEL = 2 -- Default compression
  local FLG = FLEVEL * 64 + FDIST * 32
  local FCHECK = (31 - (CMF * 256 + FLG) % 31)
  -- The FCHECK value must be such that CMF and FLG,
  -- when viewed as a 16-bit unsigned integer stored
  -- in MSB order (CMF*256 + FLG), is a multiple of 31.
  FLG = FLG + FCHECK
  WriteBits(FLG, 8)

  if FDIST == 1 then
	local adler32 = dictionary.adler32
	local byte0 = adler32 % 256
	adler32 = (adler32 - byte0) / 256
	local byte1 = adler32 % 256
	adler32 = (adler32 - byte1) / 256
	local byte2 = adler32 % 256
	adler32 = (adler32 - byte2) / 256
	local byte3 = adler32 % 256
	WriteBits(byte3, 8)
	WriteBits(byte2, 8)
	WriteBits(byte1, 8)
	WriteBits(byte0, 8)
  end

  Deflate(configs, WriteBits, WriteString, FlushWriter, str, dictionary)
  FlushWriter(_FLUSH_MODE_BYTE_BOUNDARY)

  local adler32 = LibDeflate:Adler32(str)

  -- Most significant byte first
  local byte3 = adler32 % 256
  adler32 = (adler32 - byte3) / 256
  local byte2 = adler32 % 256
  adler32 = (adler32 - byte2) / 256
  local byte1 = adler32 % 256
  adler32 = (adler32 - byte1) / 256
  local byte0 = adler32 % 256

  WriteBits(byte0, 8)
  WriteBits(byte1, 8)
  WriteBits(byte2, 8)
  WriteBits(byte3, 8)
  local total_bitlen, result = FlushWriter(_FLUSH_MODE_OUTPUT)
  local padding_bitlen = (8 - total_bitlen % 8) % 8
  return result, padding_bitlen
end

--- Compress using the raw deflate format.
-- @param str [string] The data to be compressed.
-- @param configs [table/nil] The configuration table to control the compression
-- . If nil, use the default configuration.
-- @return [string] The compressed data.
-- @return [integer] The number of bits padded at the end of output.
-- 0 <= bits < 8  <br>
-- This means the most significant "bits" of the last byte of the returned
-- compressed data are padding bits and they don't affect decompression.
-- You don't need to use this value unless you want to do some postprocessing
-- to the compressed data.
-- @see compression_configs
-- @see LibDeflate:DecompressDeflate
function LibDeflate:CompressDeflate(str, configs)
  local arg_valid, arg_err = IsValidArguments(str, false, nil, true, configs)
  if not arg_valid then
	error(("Usage: LibDeflate:CompressDeflate(str, configs): " .. arg_err), 2)
  end
  return CompressDeflateInternal(str, nil, configs)
end

--- Compress using the raw deflate format with a preset dictionary.
-- @param str [string] The data to be compressed.
-- @param dictionary [table] The preset dictionary produced by
-- LibDeflate:CreateDictionary
-- @param configs [table/nil] The configuration table to control the compression
-- . If nil, use the default configuration.
-- @return [string] The compressed data.
-- @return [integer] The number of bits padded at the end of output.
-- 0 <= bits < 8  <br>
-- This means the most significant "bits" of the last byte of the returned
-- compressed data are padding bits and they don't affect decompression.
-- You don't need to use this value unless you want to do some postprocessing
-- to the compressed data.
-- @see compression_configs
-- @see LibDeflate:CreateDictionary
-- @see LibDeflate:DecompressDeflateWithDict
function LibDeflate:CompressDeflateWithDict(str, dictionary, configs)
  local arg_valid, arg_err = IsValidArguments(str, true, dictionary, true,
											  configs)
  if not arg_valid then
	error(("Usage: LibDeflate:CompressDeflateWithDict" ..
			"(str, dictionary, configs): " .. arg_err), 2)
  end
  return CompressDeflateInternal(str, dictionary, configs)
end

--- Compress using the zlib format.
-- @param str [string] the data to be compressed.
-- @param configs [table/nil] The configuration table to control the compression
-- . If nil, use the default configuration.
-- @return [string] The compressed data.
-- @return [integer] The number of bits padded at the end of output.
-- Should always be 0.
-- Zlib formatted compressed data never has padding bits at the end.
-- @see compression_configs
-- @see LibDeflate:DecompressZlib
function LibDeflate:CompressZlib(str, configs)
  local arg_valid, arg_err = IsValidArguments(str, false, nil, true, configs)
  if not arg_valid then
	error(("Usage: LibDeflate:CompressZlib(str, configs): " .. arg_err), 2)
  end
  return CompressZlibInternal(str, nil, configs)
end

--- Compress using the zlib format with a preset dictionary.
-- @param str [string] the data to be compressed.
-- @param dictionary [table] A preset dictionary produced
-- by LibDeflate:CreateDictionary()
-- @param configs [table/nil] The configuration table to control the compression
-- . If nil, use the default configuration.
-- @return [string] The compressed data.
-- @return [integer] The number of bits padded at the end of output.
-- Should always be 0.
-- Zlib formatted compressed data never has padding bits at the end.
-- @see compression_configs
-- @see LibDeflate:CreateDictionary
-- @see LibDeflate:DecompressZlibWithDict
function LibDeflate:CompressZlibWithDict(str, dictionary, configs)
  local arg_valid, arg_err = IsValidArguments(str, true, dictionary, true,
											  configs)
  if not arg_valid then
	error(("Usage: LibDeflate:CompressZlibWithDict" ..
			"(str, dictionary, configs): " .. arg_err), 2)
  end
  return CompressZlibInternal(str, dictionary, configs)
end


--[[ --------------------------------------------------------------------------
	Decompress code
--]] --------------------------------------------------------------------------

--[[
	Create a reader to easily reader stuffs as the unit of bits.
	Return values:
	1. ReadBits(bitlen)
	2. ReadBytes(bytelen, buffer, buffer_size)
	3. Decode(huffman_bitlen_count, huffman_symbol, min_bitlen)
	4. ReaderBitlenLeft()
	5. SkipToByteBoundary()
--]]
local function CreateReader(input_string)
  local input = input_string
  local input_strlen = #input_string
  local input_next_byte_pos = 1
  local cache_bitlen = 0
  local cache = 0

  -- Read some bits.
  -- To improve speed, this function does not
  -- check if the input has been exhausted.
  -- Use ReaderBitlenLeft() < 0 to check it.
  -- @param bitlen the number of bits to read
  -- @return the data is read.
  local function ReadBits(bitlen)
	local rshift_mask = _pow2[bitlen]
	local code
	if bitlen <= cache_bitlen then
	  code = cache % rshift_mask
	  cache = (cache - code) / rshift_mask
	  cache_bitlen = cache_bitlen - bitlen
	else -- Whether input has been exhausted is not checked.
	  local lshift_mask = _pow2[cache_bitlen]
	  local byte1, byte2, byte3, byte4 =
		string_byte(input, input_next_byte_pos, input_next_byte_pos + 3)
	  -- This requires lua number to be at least double ()
	  cache = cache +
				((byte1 or 0) + (byte2 or 0) * 256 + (byte3 or 0) * 65536 +
				  (byte4 or 0) * 16777216) * lshift_mask
	  input_next_byte_pos = input_next_byte_pos + 4
	  cache_bitlen = cache_bitlen + 32 - bitlen
	  code = cache % rshift_mask
	  cache = (cache - code) / rshift_mask
	end
	return code
  end

  -- Read some bytes from the reader.
  -- Assume reader is on the byte boundary.
  -- @param bytelen The number of bytes to be read.
  -- @param buffer The byte read will be stored into this buffer.
  -- @param buffer_size The buffer will be modified starting from
  --	buffer[buffer_size+1], ending at buffer[buffer_size+bytelen-1]
  -- @return the new buffer_size
  local function ReadBytes(bytelen, buffer, buffer_size)
	assert(cache_bitlen % 8 == 0)

	local byte_from_cache =
	  (cache_bitlen / 8 < bytelen) and (cache_bitlen / 8) or bytelen
	for _ = 1, byte_from_cache do
	  local byte = cache % 256
	  buffer_size = buffer_size + 1
	  buffer[buffer_size] = string_char(byte)
	  cache = (cache - byte) / 256
	end
	cache_bitlen = cache_bitlen - byte_from_cache * 8
	bytelen = bytelen - byte_from_cache
	if (input_strlen - input_next_byte_pos - bytelen + 1) * 8 + cache_bitlen < 0 then
	  return -1 -- out of input
	end
	for i = input_next_byte_pos, input_next_byte_pos + bytelen - 1 do
	  buffer_size = buffer_size + 1
	  buffer[buffer_size] = string_sub(input, i, i)
	end

	input_next_byte_pos = input_next_byte_pos + bytelen
	return buffer_size
  end

  -- Decode huffman code
  -- To improve speed, this function does not check
  -- if the input has been exhausted.
  -- Use ReaderBitlenLeft() < 0 to check it.
  -- Credits for Mark Adler. This code is from puff:Decode()
  -- @see puff:Decode(...)
  -- @param huffman_bitlen_count
  -- @param huffman_symbol
  -- @param min_bitlen The minimum huffman bit length of all symbols
  -- @return The decoded deflate code.
  --	Negative value is returned if decoding fails.
  local function Decode(huffman_bitlen_counts, huffman_symbols, min_bitlen)
	local code = 0
	local first = 0
	local index = 0
	local count
	if min_bitlen > 0 then
	  if cache_bitlen < 15 and input then
		local lshift_mask = _pow2[cache_bitlen]
		local byte1, byte2, byte3, byte4 =
		  string_byte(input, input_next_byte_pos, input_next_byte_pos + 3)
		-- This requires lua number to be at least double ()
		cache = cache +
				  ((byte1 or 0) + (byte2 or 0) * 256 + (byte3 or 0) * 65536 +
					(byte4 or 0) * 16777216) * lshift_mask
		input_next_byte_pos = input_next_byte_pos + 4
		cache_bitlen = cache_bitlen + 32
	  end

	  local rshift_mask = _pow2[min_bitlen]
	  cache_bitlen = cache_bitlen - min_bitlen
	  code = cache % rshift_mask
	  cache = (cache - code) / rshift_mask
	  -- Reverse the bits
	  code = _reverse_bits_tbl[min_bitlen][code]

	  count = huffman_bitlen_counts[min_bitlen]
	  if code < count then return huffman_symbols[code] end
	  index = count
	  first = count * 2
	  code = code * 2
	end

	for bitlen = min_bitlen + 1, 15 do
	  local bit
	  bit = cache % 2
	  cache = (cache - bit) / 2
	  cache_bitlen = cache_bitlen - 1

	  code = (bit == 1) and (code + 1 - code % 2) or code
	  count = huffman_bitlen_counts[bitlen] or 0
	  local diff = code - first
	  if diff < count then return huffman_symbols[index + diff] end
	  index = index + count
	  first = first + count
	  first = first * 2
	  code = code * 2
	end
	-- invalid literal/length or distance code
	-- in fixed or dynamic block (run out of code)
	return -10
  end

  local function ReaderBitlenLeft()
	return (input_strlen - input_next_byte_pos + 1) * 8 + cache_bitlen
  end

  local function SkipToByteBoundary()
	local skipped_bitlen = cache_bitlen % 8
	local rshift_mask = _pow2[skipped_bitlen]
	cache_bitlen = cache_bitlen - skipped_bitlen
	cache = (cache - cache % rshift_mask) / rshift_mask
  end

  return ReadBits, ReadBytes, Decode, ReaderBitlenLeft, SkipToByteBoundary
end

-- Create a deflate state, so I can pass in less arguments to functions.
-- @param str the whole string to be decompressed.
-- @param dictionary The preset dictionary. nil if not provided.
--		This dictionary should be produced by LibDeflate:CreateDictionary(str)
-- @return The decomrpess state.
local function CreateDecompressState(str, dictionary)
  local ReadBits, ReadBytes, Decode, ReaderBitlenLeft, SkipToByteBoundary =
	CreateReader(str)
  local state = {
	ReadBits = ReadBits,
	ReadBytes = ReadBytes,
	Decode = Decode,
	ReaderBitlenLeft = ReaderBitlenLeft,
	SkipToByteBoundary = SkipToByteBoundary,
	buffer_size = 0,
	buffer = {},
	result_buffer = {},
	dictionary = dictionary
  }
  return state
end

-- Get the stuffs needed to decode huffman codes
-- @see puff.c:construct(...)
-- @param huffman_bitlen The huffman bit length of the huffman codes.
-- @param max_symbol The maximum symbol
-- @param max_bitlen The min huffman bit length of all codes
-- @return zero or positive for success, negative for failure.
-- @return The count of each huffman bit length.
-- @return A table to convert huffman codes to deflate codes.
-- @return The minimum huffman bit length.
local function GetHuffmanForDecode(huffman_bitlens, max_symbol, max_bitlen)
  local huffman_bitlen_counts = {}
  local min_bitlen = max_bitlen
  for symbol = 0, max_symbol do
	local bitlen = huffman_bitlens[symbol] or 0
	min_bitlen = (bitlen > 0 and bitlen < min_bitlen) and bitlen or min_bitlen
	huffman_bitlen_counts[bitlen] = (huffman_bitlen_counts[bitlen] or 0) + 1
  end

  if huffman_bitlen_counts[0] == max_symbol + 1 then -- No Codes
	return 0, huffman_bitlen_counts, {}, 0 -- Complete, but decode will fail
  end

  local left = 1
  for len = 1, max_bitlen do
	left = left * 2
	left = left - (huffman_bitlen_counts[len] or 0)
	if left < 0 then
	  return left -- Over-subscribed, return negative
	end
  end

  -- Generate offsets info symbol table for each length for sorting
  local offsets = {}
  offsets[1] = 0
  for len = 1, max_bitlen - 1 do
	offsets[len + 1] = offsets[len] + (huffman_bitlen_counts[len] or 0)
  end

  local huffman_symbols = {}
  for symbol = 0, max_symbol do
	local bitlen = huffman_bitlens[symbol] or 0
	if bitlen ~= 0 then
	  local offset = offsets[bitlen]
	  huffman_symbols[offset] = symbol
	  offsets[bitlen] = offsets[bitlen] + 1
	end
  end

  -- Return zero for complete set, positive for incomplete set.
  return left, huffman_bitlen_counts, huffman_symbols, min_bitlen
end

-- Decode a fixed or dynamic huffman blocks, excluding last block identifier
-- and block type identifer.
-- @see puff.c:codes()
-- @param state decompression state that will be modified by this function.
--	@see CreateDecompressState
-- @param ... Read the source code
-- @return 0 on success, other value on failure.
local function DecodeUntilEndOfBlock(state, lcodes_huffman_bitlens,
									 lcodes_huffman_symbols,
									 lcodes_huffman_min_bitlen,
									 dcodes_huffman_bitlens,
									 dcodes_huffman_symbols,
									 dcodes_huffman_min_bitlen)
  local buffer, buffer_size, ReadBits, Decode, ReaderBitlenLeft, result_buffer =
	state.buffer, state.buffer_size, state.ReadBits, state.Decode,
	state.ReaderBitlenLeft, state.result_buffer
  local dictionary = state.dictionary
  local dict_string_table
  local dict_strlen

  local buffer_end = 1
  if dictionary and not buffer[0] then
	-- If there is a dictionary, copy the last 258 bytes into
	-- the string_table to make the copy in the main loop quicker.
	-- This is done only once per decompression.
	dict_string_table = dictionary.string_table
	dict_strlen = dictionary.strlen
	buffer_end = -dict_strlen + 1
	for i = 0, (-dict_strlen + 1) < -257 and -257 or (-dict_strlen + 1), -1 do
	  buffer[i] = _byte_to_char[dict_string_table[dict_strlen + i]]
	end
  end

  repeat
	local symbol = Decode(lcodes_huffman_bitlens, lcodes_huffman_symbols,
						  lcodes_huffman_min_bitlen)
	if symbol < 0 or symbol > 285 then
	  -- invalid literal/length or distance code in fixed or dynamic block
	  return -10
	elseif symbol < 256 then -- Literal
	  buffer_size = buffer_size + 1
	  buffer[buffer_size] = _byte_to_char[symbol]
	elseif symbol > 256 then -- Length code
	  symbol = symbol - 256
	  local bitlen = _literal_deflate_code_to_base_len[symbol]
	  bitlen = (symbol >= 8) and
				 (bitlen +
				   ReadBits(_literal_deflate_code_to_extra_bitlen[symbol])) or
				 bitlen
	  symbol = Decode(dcodes_huffman_bitlens, dcodes_huffman_symbols,
					  dcodes_huffman_min_bitlen)
	  if symbol < 0 or symbol > 29 then
		-- invalid literal/length or distance code in fixed or dynamic block
		return -10
	  end
	  local dist = _dist_deflate_code_to_base_dist[symbol]
	  dist = (dist > 4) and
			   (dist + ReadBits(_dist_deflate_code_to_extra_bitlen[symbol])) or
			   dist

	  local char_buffer_index = buffer_size - dist + 1
	  if char_buffer_index < buffer_end then
		-- distance is too far back in fixed or dynamic block
		return -11
	  end
	  if char_buffer_index >= -257 then
		for _ = 1, bitlen do
		  buffer_size = buffer_size + 1
		  buffer[buffer_size] = buffer[char_buffer_index]
		  char_buffer_index = char_buffer_index + 1
		end
	  else
		char_buffer_index = dict_strlen + char_buffer_index
		for _ = 1, bitlen do
		  buffer_size = buffer_size + 1
		  buffer[buffer_size] =
			_byte_to_char[dict_string_table[char_buffer_index]]
		  char_buffer_index = char_buffer_index + 1
		end
	  end
	end

	if ReaderBitlenLeft() < 0 then
	  return 2 -- available inflate data did not terminate
	end

	if buffer_size >= 65536 then
	  result_buffer[#result_buffer + 1] = table_concat(buffer, "", 1, 32768)
	  for i = 32769, buffer_size do buffer[i - 32768] = buffer[i] end
	  buffer_size = buffer_size - 32768
	  buffer[buffer_size + 1] = nil
	  -- NOTE: buffer[32769..end] and buffer[-257..0] are not cleared.
	  -- This is why "buffer_size" variable is needed.
	end
  until symbol == 256

  state.buffer_size = buffer_size

  return 0
end

-- Decompress a store block
-- @param state decompression state that will be modified by this function.
-- @return 0 if succeeds, other value if fails.
local function DecompressStoreBlock(state)
  local buffer, buffer_size, ReadBits, ReadBytes, ReaderBitlenLeft,
		SkipToByteBoundary, result_buffer = state.buffer, state.buffer_size,
											state.ReadBits, state.ReadBytes,
											state.ReaderBitlenLeft,
											state.SkipToByteBoundary,
											state.result_buffer

  SkipToByteBoundary()
  local bytelen = ReadBits(16)
  if ReaderBitlenLeft() < 0 then
	return 2 -- available inflate data did not terminate
  end
  local bytelenComp = ReadBits(16)
  if ReaderBitlenLeft() < 0 then
	return 2 -- available inflate data did not terminate
  end

  if bytelen % 256 + bytelenComp % 256 ~= 255 then
	return -2 -- Not one's complement
  end
  if (bytelen - bytelen % 256) / 256 + (bytelenComp - bytelenComp % 256) / 256 ~=
	255 then
	return -2 -- Not one's complement
  end

  -- Note that ReadBytes will skip to the next byte boundary first.
  buffer_size = ReadBytes(bytelen, buffer, buffer_size)
  if buffer_size < 0 then
	return 2 -- available inflate data did not terminate
  end

  -- memory clean up when there are enough bytes in the buffer.
  if buffer_size >= 65536 then
	result_buffer[#result_buffer + 1] = table_concat(buffer, "", 1, 32768)
	for i = 32769, buffer_size do buffer[i - 32768] = buffer[i] end
	buffer_size = buffer_size - 32768
	buffer[buffer_size + 1] = nil
  end
  state.buffer_size = buffer_size
  return 0
end

-- Decompress a fixed block
-- @param state decompression state that will be modified by this function.
-- @return 0 if succeeds other value if fails.
local function DecompressFixBlock(state)
  return DecodeUntilEndOfBlock(state, _fix_block_literal_huffman_bitlen_count,
							   _fix_block_literal_huffman_to_deflate_code, 7,
							   _fix_block_dist_huffman_bitlen_count,
							   _fix_block_dist_huffman_to_deflate_code, 5)
end

-- Decompress a dynamic block
-- @param state decompression state that will be modified by this function.
-- @return 0 if success, other value if fails.
local function DecompressDynamicBlock(state)
  local ReadBits, Decode = state.ReadBits, state.Decode
  local nlen = ReadBits(5) + 257
  local ndist = ReadBits(5) + 1
  local ncode = ReadBits(4) + 4
  if nlen > 286 or ndist > 30 then
	-- dynamic block code description: too many length or distance codes
	return -3
  end

  local rle_codes_huffman_bitlens = {}

  for i = 1, ncode do
	rle_codes_huffman_bitlens[_rle_codes_huffman_bitlen_order[i]] = ReadBits(3)
  end

  local rle_codes_err, rle_codes_huffman_bitlen_counts,
		rle_codes_huffman_symbols, rle_codes_huffman_min_bitlen =
	GetHuffmanForDecode(rle_codes_huffman_bitlens, 18, 7)
  if rle_codes_err ~= 0 then -- Require complete code set here
	-- dynamic block code description: code lengths codes incomplete
	return -4
  end

  local lcodes_huffman_bitlens = {}
  local dcodes_huffman_bitlens = {}
  -- Read length/literal and distance code length tables
  local index = 0
  while index < nlen + ndist do
	local symbol -- Decoded value
	local bitlen -- Last length to repeat

	symbol = Decode(rle_codes_huffman_bitlen_counts, rle_codes_huffman_symbols,
					rle_codes_huffman_min_bitlen)

	if symbol < 0 then
	  return symbol -- Invalid symbol
	elseif symbol < 16 then
	  if index < nlen then
		lcodes_huffman_bitlens[index] = symbol
	  else
		dcodes_huffman_bitlens[index - nlen] = symbol
	  end
	  index = index + 1
	else
	  bitlen = 0
	  if symbol == 16 then
		if index == 0 then
		  -- dynamic block code description: repeat lengths
		  -- with no first length
		  return -5
		end
		if index - 1 < nlen then
		  bitlen = lcodes_huffman_bitlens[index - 1]
		else
		  bitlen = dcodes_huffman_bitlens[index - nlen - 1]
		end
		symbol = 3 + ReadBits(2)
	  elseif symbol == 17 then -- Repeat zero 3..10 times
		symbol = 3 + ReadBits(3)
	  else -- == 18, repeat zero 11.138 times
		symbol = 11 + ReadBits(7)
	  end
	  if index + symbol > nlen + ndist then
		-- dynamic block code description:
		-- repeat more than specified lengths
		return -6
	  end
	  while symbol > 0 do -- Repeat last or zero symbol times
		symbol = symbol - 1
		if index < nlen then
		  lcodes_huffman_bitlens[index] = bitlen
		else
		  dcodes_huffman_bitlens[index - nlen] = bitlen
		end
		index = index + 1
	  end
	end
  end

  if (lcodes_huffman_bitlens[256] or 0) == 0 then
	-- dynamic block code description: missing end-of-block code
	return -9
  end

  local lcodes_err, lcodes_huffman_bitlen_counts, lcodes_huffman_symbols,
		lcodes_huffman_min_bitlen = GetHuffmanForDecode(lcodes_huffman_bitlens,
														nlen - 1, 15)
  -- dynamic block code description: invalid literal/length code lengths,
  -- Incomplete code ok only for single length 1 code
  if (lcodes_err ~= 0 and
	(lcodes_err < 0 or nlen ~= (lcodes_huffman_bitlen_counts[0] or 0) +
	  (lcodes_huffman_bitlen_counts[1] or 0))) then return -7 end

  local dcodes_err, dcodes_huffman_bitlen_counts, dcodes_huffman_symbols,
		dcodes_huffman_min_bitlen = GetHuffmanForDecode(dcodes_huffman_bitlens,
														ndist - 1, 15)
  -- dynamic block code description: invalid distance code lengths,
  -- Incomplete code ok only for single length 1 code
  if (dcodes_err ~= 0 and
	(dcodes_err < 0 or ndist ~= (dcodes_huffman_bitlen_counts[0] or 0) +
	  (dcodes_huffman_bitlen_counts[1] or 0))) then return -8 end

  -- Build buffman table for literal/length codes
  return DecodeUntilEndOfBlock(state, lcodes_huffman_bitlen_counts,
							   lcodes_huffman_symbols,
							   lcodes_huffman_min_bitlen,
							   dcodes_huffman_bitlen_counts,
							   dcodes_huffman_symbols, dcodes_huffman_min_bitlen)
end

-- Decompress a deflate stream
-- @param state: a decompression state
-- @return the decompressed string if succeeds. nil if fails.
local function Inflate(state)
  local ReadBits = state.ReadBits

  local is_last_block
  while not is_last_block do
	is_last_block = (ReadBits(1) == 1)
	local block_type = ReadBits(2)
	local status
	if block_type == 0 then
	  status = DecompressStoreBlock(state)
	elseif block_type == 1 then
	  status = DecompressFixBlock(state)
	elseif block_type == 2 then
	  status = DecompressDynamicBlock(state)
	else
	  return nil, -1 -- invalid block type (type == 3)
	end
	if status ~= 0 then return nil, status end
  end

  state.result_buffer[#state.result_buffer + 1] =
	table_concat(state.buffer, "", 1, state.buffer_size)
  local result = table_concat(state.result_buffer)
  return result
end

-- @see LibDeflate:DecompressDeflate(str)
-- @see LibDeflate:DecompressDeflateWithDict(str, dictionary)
local function DecompressDeflateInternal(str, dictionary)
  local state = CreateDecompressState(str, dictionary)
  local result, status = Inflate(state)
  if not result then return nil, status end

  local bitlen_left = state.ReaderBitlenLeft()
  local bytelen_left = (bitlen_left - bitlen_left % 8) / 8
  return result, bytelen_left
end

-- @see LibDeflate:DecompressZlib(str)
-- @see LibDeflate:DecompressZlibWithDict(str)
local function DecompressZlibInternal(str, dictionary)
  local state = CreateDecompressState(str, dictionary)
  local ReadBits = state.ReadBits

  local CMF = ReadBits(8)
  if state.ReaderBitlenLeft() < 0 then
	return nil, 2 -- available inflate data did not terminate
  end
  local CM = CMF % 16
  local CINFO = (CMF - CM) / 16
  if CM ~= 8 then
	return nil, -12 -- invalid compression method
  end
  if CINFO > 7 then
	return nil, -13 -- invalid window size
  end

  local FLG = ReadBits(8)
  if state.ReaderBitlenLeft() < 0 then
	return nil, 2 -- available inflate data did not terminate
  end
  if (CMF * 256 + FLG) % 31 ~= 0 then
	return nil, -14 -- invalid header checksum
  end

  local FDIST = ((FLG - FLG % 32) / 32 % 2)
  local FLEVEL = ((FLG - FLG % 64) / 64 % 4) -- luacheck: ignore FLEVEL

  if FDIST == 1 then
	if not dictionary then
	  return nil, -16 -- need dictonary, but dictionary is not provided.
	end
	local byte3 = ReadBits(8)
	local byte2 = ReadBits(8)
	local byte1 = ReadBits(8)
	local byte0 = ReadBits(8)
	local actual_adler32 = byte3 * 16777216 + byte2 * 65536 + byte1 * 256 +
							 byte0
	if state.ReaderBitlenLeft() < 0 then
	  return nil, 2 -- available inflate data did not terminate
	end
	if not IsEqualAdler32(actual_adler32, dictionary.adler32) then
	  return nil, -17 -- dictionary adler32 does not match
	end
  end
  local result, status = Inflate(state)
  if not result then return nil, status end
  state.SkipToByteBoundary()

  local adler_byte0 = ReadBits(8)
  local adler_byte1 = ReadBits(8)
  local adler_byte2 = ReadBits(8)
  local adler_byte3 = ReadBits(8)
  if state.ReaderBitlenLeft() < 0 then
	return nil, 2 -- available inflate data did not terminate
  end

  local adler32_expected = adler_byte0 * 16777216 + adler_byte1 * 65536 +
							 adler_byte2 * 256 + adler_byte3
  local adler32_actual = LibDeflate:Adler32(result)
  if not IsEqualAdler32(adler32_expected, adler32_actual) then
	return nil, -15 -- Adler32 checksum does not match
  end

  local bitlen_left = state.ReaderBitlenLeft()
  local bytelen_left = (bitlen_left - bitlen_left % 8) / 8
  return result, bytelen_left
end

--- Decompress a raw deflate compressed data.
-- @param str [string] The data to be decompressed.
-- @return [string/nil] If the decompression succeeds, return the decompressed
-- data. If the decompression fails, return nil. You should check if this return
-- value is non-nil to know if the decompression succeeds.
-- @return [integer] If the decompression succeeds, return the number of
-- unprocessed bytes in the input compressed data. This return value is a
-- positive integer if the input data is a valid compressed data appended by an
-- arbitary non-empty string. This return value is 0 if the input data does not
-- contain any extra bytes.<br>
-- If the decompression fails (The first return value of this function is nil),
-- this return value is undefined.
-- @see LibDeflate:CompressDeflate
function LibDeflate:DecompressDeflate(str)
  local arg_valid, arg_err = IsValidArguments(str)
  if not arg_valid then
	error(("Usage: LibDeflate:DecompressDeflate(str): " .. arg_err), 2)
  end
  return DecompressDeflateInternal(str)
end

--- Decompress a raw deflate compressed data with a preset dictionary.
-- @param str [string] The data to be decompressed.
-- @param dictionary [table] The preset dictionary used by
-- LibDeflate:CompressDeflateWithDict when the compressed data is produced.
-- Decompression and compression must use the same dictionary.
-- Otherwise wrong decompressed data could be produced without generating any
-- error.
-- @return [string/nil] If the decompression succeeds, return the decompressed
-- data. If the decompression fails, return nil. You should check if this return
-- value is non-nil to know if the decompression succeeds.
-- @return [integer] If the decompression succeeds, return the number of
-- unprocessed bytes in the input compressed data. This return value is a
-- positive integer if the input data is a valid compressed data appended by an
-- arbitary non-empty string. This return value is 0 if the input data does not
-- contain any extra bytes.<br>
-- If the decompression fails (The first return value of this function is nil),
-- this return value is undefined.
-- @see LibDeflate:CompressDeflateWithDict
function LibDeflate:DecompressDeflateWithDict(str, dictionary)
  local arg_valid, arg_err = IsValidArguments(str, true, dictionary)
  if not arg_valid then
	error(("Usage: LibDeflate:DecompressDeflateWithDict(str, dictionary): " ..
			arg_err), 2)
  end
  return DecompressDeflateInternal(str, dictionary)
end

--- Decompress a zlib compressed data.
-- @param str [string] The data to be decompressed
-- @return [string/nil] If the decompression succeeds, return the decompressed
-- data. If the decompression fails, return nil. You should check if this return
-- value is non-nil to know if the decompression succeeds.
-- @return [integer] If the decompression succeeds, return the number of
-- unprocessed bytes in the input compressed data. This return value is a
-- positive integer if the input data is a valid compressed data appended by an
-- arbitary non-empty string. This return value is 0 if the input data does not
-- contain any extra bytes.<br>
-- If the decompression fails (The first return value of this function is nil),
-- this return value is undefined.
-- @see LibDeflate:CompressZlib
function LibDeflate:DecompressZlib(str)
  local arg_valid, arg_err = IsValidArguments(str)
  if not arg_valid then
	error(("Usage: LibDeflate:DecompressZlib(str): " .. arg_err), 2)
  end
  return DecompressZlibInternal(str)
end

--- Decompress a zlib compressed data with a preset dictionary.
-- @param str [string] The data to be decompressed
-- @param dictionary [table] The preset dictionary used by
-- LibDeflate:CompressDeflateWithDict when the compressed data is produced.
-- Decompression and compression must use the same dictionary.
-- Otherwise wrong decompressed data could be produced without generating any
-- error.
-- @return [string/nil] If the decompression succeeds, return the decompressed
-- data. If the decompression fails, return nil. You should check if this return
-- value is non-nil to know if the decompression succeeds.
-- @return [integer] If the decompression succeeds, return the number of
-- unprocessed bytes in the input compressed data. This return value is a
-- positive integer if the input data is a valid compressed data appended by an
-- arbitary non-empty string. This return value is 0 if the input data does not
-- contain any extra bytes.<br>
-- If the decompression fails (The first return value of this function is nil),
-- this return value is undefined.
-- @see LibDeflate:CompressZlibWithDict
function LibDeflate:DecompressZlibWithDict(str, dictionary)
  local arg_valid, arg_err = IsValidArguments(str, true, dictionary)
  if not arg_valid then
	error(("Usage: LibDeflate:DecompressZlibWithDict(str, dictionary): " ..
			arg_err), 2)
  end
  return DecompressZlibInternal(str, dictionary)
end

-- Calculate the huffman code of fixed block
do
  _fix_block_literal_huffman_bitlen = {}
  for sym = 0, 143 do _fix_block_literal_huffman_bitlen[sym] = 8 end
  for sym = 144, 255 do _fix_block_literal_huffman_bitlen[sym] = 9 end
  for sym = 256, 279 do _fix_block_literal_huffman_bitlen[sym] = 7 end
  for sym = 280, 287 do _fix_block_literal_huffman_bitlen[sym] = 8 end

  _fix_block_dist_huffman_bitlen = {}
  for dist = 0, 31 do _fix_block_dist_huffman_bitlen[dist] = 5 end
  local status
  status, _fix_block_literal_huffman_bitlen_count, _fix_block_literal_huffman_to_deflate_code =
	GetHuffmanForDecode(_fix_block_literal_huffman_bitlen, 287, 9)
  assert(status == 0)
  status, _fix_block_dist_huffman_bitlen_count, _fix_block_dist_huffman_to_deflate_code =
	GetHuffmanForDecode(_fix_block_dist_huffman_bitlen, 31, 5)
  assert(status == 0)

  _fix_block_literal_huffman_code = GetHuffmanCodeFromBitlen(
									  _fix_block_literal_huffman_bitlen_count,
									  _fix_block_literal_huffman_bitlen, 287, 9)
  _fix_block_dist_huffman_code = GetHuffmanCodeFromBitlen(
								   _fix_block_dist_huffman_bitlen_count,
								   _fix_block_dist_huffman_bitlen, 31, 5)
end

-- Prefix encoding algorithm
-- Credits to LibCompress.
-- The code has been rewritten by the author of LibDeflate.
------------------------------------------------------------------------------

-- to be able to match any requested byte value, the search
-- string must be preprocessed characters to escape with %:
-- ( ) . % + - * ? [ ] ^ $
-- "illegal" byte values:
-- 0 is replaces %z
local _gsub_escape_table = {
  ["\000"] = "%z",
  ["("] = "%(",
  [")"] = "%)",
  ["."] = "%.",
  ["%"] = "%%",
  ["+"] = "%+",
  ["-"] = "%-",
  ["*"] = "%*",
  ["?"] = "%?",
  ["["] = "%[",
  ["]"] = "%]",
  ["^"] = "%^",
  ["$"] = "%$"
}

local function escape_for_gsub(str)
  return str:gsub("([%z%(%)%.%%%+%-%*%?%[%]%^%$])", _gsub_escape_table)
end

--- Create a custom codec with encoder and decoder. <br>
-- This codec is used to convert an input string to make it not contain
-- some specific bytes.
-- This created codec and the parameters of this function do NOT take
-- localization into account. One byte (0-255) in the string is exactly one
-- character (0-255).
-- Credits to LibCompress.
-- The code has been rewritten by the author of LibDeflate. <br>
-- @param reserved_chars [string] The created encoder will ensure encoded
-- data does not contain any single character in reserved_chars. This parameter
-- should be non-empty.
-- @param escape_chars [string] The escape character(s) used in the created
-- codec. The codec converts any character included in reserved\_chars /
-- escape\_chars / map\_chars to (one escape char + one character not in
-- reserved\_chars / escape\_chars / map\_chars).
-- You usually only need to provide a length-1 string for this parameter.
-- Length-2 string is only needed when
-- reserved\_chars + escape\_chars + map\_chars is longer than 127.
-- This parameter should be non-empty.
-- @param map_chars [string] The created encoder will map every
-- reserved\_chars:sub(i, i) (1 <= i <= #map\_chars) to map\_chars:sub(i, i).
-- This parameter CAN be empty string.
-- @return [table/nil] If the codec cannot be created, return nil.<br>
-- If the codec can be created according to the given
-- parameters, return the codec, which is a encode/decode table.
-- The table contains two functions: <br>
-- t:Encode(str) returns the encoded string. <br>
-- t:Decode(str) returns the decoded string if succeeds. nil if fails.
-- @return [nil/string] If the codec is successfully created, return nil.
-- If not, return a string that describes the reason why the codec cannot be
-- created.
-- @usage
-- -- Create an encoder/decoder that maps all "\000" to "\003",
-- -- and escape "\001" (and "\002" and "\003") properly
-- local codec = LibDeflate:CreateCodec("\000\001", "\002", "\003")
--
-- local encoded = codec:Encode(SOME_STRING)
-- -- "encoded" does not contain "\000" or "\001"
-- local decoded = codec:Decode(encoded)
-- -- assert(decoded == SOME_STRING)
function LibDeflate:CreateCodec(reserved_chars, escape_chars, map_chars)
  if type(reserved_chars) ~= "string" or type(escape_chars) ~= "string" or
	type(map_chars) ~= "string" then
	error("Usage: LibDeflate:CreateCodec(reserved_chars," ..
			" escape_chars, map_chars):" .. " All arguments must be string.", 2)
  end

  if escape_chars == "" then return nil, "No escape characters supplied." end
  if #reserved_chars < #map_chars then
	return nil, "The number of reserved characters must be" ..
			 " at least as many as the number of mapped chars."
  end
  if reserved_chars == "" then return nil, "No characters to encode." end

  local encode_bytes = reserved_chars .. escape_chars .. map_chars
  -- build list of bytes not available as a suffix to a prefix byte
  local taken = {}
  for i = 1, #encode_bytes do
	local byte = string_byte(encode_bytes, i, i)
	if taken[byte] then
	  return nil, "There must be no duplicate characters in the" ..
			   " concatenation of reserved_chars, escape_chars and" ..
			   " map_chars."
	end
	taken[byte] = true
  end

  local decode_patterns = {}
  local decode_repls = {}

  -- the encoding can be a single gsub
  -- , but the decoding can require multiple gsubs
  local encode_search = {}
  local encode_translate = {}

  -- map single byte to single byte
  if #map_chars > 0 then
	local decode_search = {}
	local decode_translate = {}
	for i = 1, #map_chars do
	  local from = string_sub(reserved_chars, i, i)
	  local to = string_sub(map_chars, i, i)
	  encode_translate[from] = to
	  encode_search[#encode_search + 1] = from
	  decode_translate[to] = from
	  decode_search[#decode_search + 1] = to
	end
	decode_patterns[#decode_patterns + 1] =
	  "([" .. escape_for_gsub(table_concat(decode_search)) .. "])"
	decode_repls[#decode_repls + 1] = decode_translate
  end

  local escape_char_index = 1
  local escape_char = string_sub(escape_chars, escape_char_index,
								 escape_char_index)
  -- map single byte to double-byte
  local r = 0 -- suffix char value to the escapeChar

  local decode_search = {}
  local decode_translate = {}
  for i = 1, #encode_bytes do
	local c = string_sub(encode_bytes, i, i)
	if not encode_translate[c] then
	  while r >= 256 or taken[r] do
		r = r + 1
		if r > 255 then -- switch to next escapeChar
		  decode_patterns[#decode_patterns + 1] =
			escape_for_gsub(escape_char) .. "([" ..
			  escape_for_gsub(table_concat(decode_search)) .. "])"
		  decode_repls[#decode_repls + 1] = decode_translate

		  escape_char_index = escape_char_index + 1
		  escape_char = string_sub(escape_chars, escape_char_index,
								   escape_char_index)
		  r = 0
		  decode_search = {}
		  decode_translate = {}

		  if not escape_char or escape_char == "" then
			-- actually I don't need to check
			-- "not ecape_char", but what if Lua changes
			-- the behavior of string.sub() in the future?
			-- we are out of escape chars and we need more!
			return nil, "Out of escape characters."
		  end
		end
	  end

	  local char_r = _byte_to_char[r]
	  encode_translate[c] = escape_char .. char_r
	  encode_search[#encode_search + 1] = c
	  decode_translate[char_r] = c
	  decode_search[#decode_search + 1] = char_r
	  r = r + 1
	end
	if i == #encode_bytes then
	  decode_patterns[#decode_patterns + 1] =
		escape_for_gsub(escape_char) .. "([" ..
		  escape_for_gsub(table_concat(decode_search)) .. "])"
	  decode_repls[#decode_repls + 1] = decode_translate
	end
  end

  local codec = {}

  local encode_pattern = "([" .. escape_for_gsub(table_concat(encode_search)) ..
						   "])"
  local encode_repl = encode_translate

  function codec:Encode(str)
	if type(str) ~= "string" then
	  error(
		("Usage: codec:Encode(str):" .. " 'str' - string expected got '%s'."):format(
		  type(str)), 2)
	end
	return string_gsub(str, encode_pattern, encode_repl)
  end

  local decode_tblsize = #decode_patterns
  local decode_fail_pattern = "([" .. escape_for_gsub(reserved_chars) .. "])"

  function codec:Decode(str)
	if type(str) ~= "string" then
	  error(
		("Usage: codec:Decode(str):" .. " 'str' - string expected got '%s'."):format(
		  type(str)), 2)
	end
	if string_find(str, decode_fail_pattern) then return nil end
	for i = 1, decode_tblsize do
	  str = string_gsub(str, decode_patterns[i], decode_repls[i])
	end
	return str
  end

  return codec
end

local _addon_channel_codec

local function GenerateWoWAddonChannelCodec()
  return LibDeflate:CreateCodec("\000", "\001", "")
end

--- Encode the string to make it ready to be transmitted in World of
-- Warcraft addon channel. <br>
-- The encoded string is guaranteed to contain no NULL ("\000") character.
-- @param str [string] The string to be encoded.
-- @return The encoded string.
-- @see LibDeflate:DecodeForWoWAddonChannel
function LibDeflate:EncodeForWoWAddonChannel(str)
  if type(str) ~= "string" then
	error(("Usage: LibDeflate:EncodeForWoWAddonChannel(str):" ..
			" 'str' - string expected got '%s'."):format(type(str)), 2)
  end
  if not _addon_channel_codec then
	_addon_channel_codec = GenerateWoWAddonChannelCodec()
  end
  return _addon_channel_codec:Encode(str)
end

--- Decode the string produced by LibDeflate:EncodeForWoWAddonChannel
-- @param str [string] The string to be decoded.
-- @return [string/nil] The decoded string if succeeds. nil if fails.
-- @see LibDeflate:EncodeForWoWAddonChannel
function LibDeflate:DecodeForWoWAddonChannel(str)
  if type(str) ~= "string" then
	error(("Usage: LibDeflate:DecodeForWoWAddonChannel(str):" ..
			" 'str' - string expected got '%s'."):format(type(str)), 2)
  end
  if not _addon_channel_codec then
	_addon_channel_codec = GenerateWoWAddonChannelCodec()
  end
  return _addon_channel_codec:Decode(str)
end

-- For World of Warcraft Chat Channel Encoding
-- Credits to LibCompress.
-- The code has been rewritten by the author of LibDeflate. <br>
-- Following byte values are not allowed:
-- \000, s, S, \010, \013, \124, %
-- Because SendChatMessage will error
-- if an UTF8 multibyte character is incomplete,
-- all character values above 127 have to be encoded to avoid this.
-- This costs quite a bit of bandwidth (about 13-14%)
-- Also, because drunken status is unknown for the received
-- , strings used with SendChatMessage should be terminated with
-- an identifying byte value, after which the server MAY add "...hic!"
-- or as much as it can fit(!).
-- Pass the identifying byte as a reserved character to this function
-- to ensure the encoding doesn't contain that value.
-- or use this: local message, match = arg1:gsub("^(.*)\029.-$", "%1")
-- arg1 is message from channel, \029 is the string terminator
-- , but may be used in the encoded datastream as well. :-)
-- This encoding will expand data anywhere from:
-- 0% (average with pure ascii text)
-- 53.5% (average with random data valued zero to 255)
-- 100% (only encoding data that encodes to two bytes)
local function GenerateWoWChatChannelCodec()
  local r = {}
  for i = 128, 255 do r[#r + 1] = _byte_to_char[i] end

  local reserved_chars = "sS\000\010\013\124%" .. table_concat(r)
  return LibDeflate:CreateCodec(reserved_chars, "\029\031", "\015\020")
end

local _chat_channel_codec

--- Encode the string to make it ready to be transmitted in World of
-- Warcraft chat channel. <br>
-- See also https://wow.gamepedia.com/ValidChatMessageCharacters
-- @param str [string] The string to be encoded.
-- @return [string] The encoded string.
-- @see LibDeflate:DecodeForWoWChatChannel
function LibDeflate:EncodeForWoWChatChannel(str)
  if type(str) ~= "string" then
	error(("Usage: LibDeflate:EncodeForWoWChatChannel(str):" ..
			" 'str' - string expected got '%s'."):format(type(str)), 2)
  end
  if not _chat_channel_codec then
	_chat_channel_codec = GenerateWoWChatChannelCodec()
  end
  return _chat_channel_codec:Encode(str)
end

--- Decode the string produced by LibDeflate:EncodeForWoWChatChannel.
-- @param str [string] The string to be decoded.
-- @return [string/nil] The decoded string if succeeds. nil if fails.
-- @see LibDeflate:EncodeForWoWChatChannel
function LibDeflate:DecodeForWoWChatChannel(str)
  if type(str) ~= "string" then
	error(("Usage: LibDeflate:DecodeForWoWChatChannel(str):" ..
			" 'str' - string expected got '%s'."):format(type(str)), 2)
  end
  if not _chat_channel_codec then
	_chat_channel_codec = GenerateWoWChatChannelCodec()
  end
  return _chat_channel_codec:Decode(str)
end

-- Credits to WeakAuras2 and Galmok for the 6 bit encoding algorithm.
-- The code has been rewritten by the author of LibDeflate.
-- The result of encoding will be 25% larger than the
-- origin string, but every single byte of the encoding result will be
-- printable characters as the following.
local _byte_to_6bit_char = {
  [0] = "a",
  "b",
  "c",
  "d",
  "e",
  "f",
  "g",
  "h",
  "i",
  "j",
  "k",
  "l",
  "m",
  "n",
  "o",
  "p",
  "q",
  "r",
  "s",
  "t",
  "u",
  "v",
  "w",
  "x",
  "y",
  "z",
  "A",
  "B",
  "C",
  "D",
  "E",
  "F",
  "G",
  "H",
  "I",
  "J",
  "K",
  "L",
  "M",
  "N",
  "O",
  "P",
  "Q",
  "R",
  "S",
  "T",
  "U",
  "V",
  "W",
  "X",
  "Y",
  "Z",
  "0",
  "1",
  "2",
  "3",
  "4",
  "5",
  "6",
  "7",
  "8",
  "9",
  "(",
  ")"
}

local _6bit_to_byte = {
  [97] = 0,
  [98] = 1,
  [99] = 2,
  [100] = 3,
  [101] = 4,
  [102] = 5,
  [103] = 6,
  [104] = 7,
  [105] = 8,
  [106] = 9,
  [107] = 10,
  [108] = 11,
  [109] = 12,
  [110] = 13,
  [111] = 14,
  [112] = 15,
  [113] = 16,
  [114] = 17,
  [115] = 18,
  [116] = 19,
  [117] = 20,
  [118] = 21,
  [119] = 22,
  [120] = 23,
  [121] = 24,
  [122] = 25,
  [65] = 26,
  [66] = 27,
  [67] = 28,
  [68] = 29,
  [69] = 30,
  [70] = 31,
  [71] = 32,
  [72] = 33,
  [73] = 34,
  [74] = 35,
  [75] = 36,
  [76] = 37,
  [77] = 38,
  [78] = 39,
  [79] = 40,
  [80] = 41,
  [81] = 42,
  [82] = 43,
  [83] = 44,
  [84] = 45,
  [85] = 46,
  [86] = 47,
  [87] = 48,
  [88] = 49,
  [89] = 50,
  [90] = 51,
  [48] = 52,
  [49] = 53,
  [50] = 54,
  [51] = 55,
  [52] = 56,
  [53] = 57,
  [54] = 58,
  [55] = 59,
  [56] = 60,
  [57] = 61,
  [40] = 62,
  [41] = 63
}

--- Encode the string to make it printable. <br>
--
-- Credit to WeakAuras2, this function is equivalant to the implementation
-- it is using right now. <br>
-- The code has been rewritten by the author of LibDeflate. <br>
-- The encoded string will be 25% larger than the origin string. However, every
-- single byte of the encoded string will be one of 64 printable ASCII
-- characters, which are can be easier copied, pasted and displayed.
-- (26 lowercase letters, 26 uppercase letters, 10 numbers digits,
-- left parenthese, or right parenthese)
-- @param str [string] The string to be encoded.
-- @return [string] The encoded string.
function LibDeflate:EncodeForPrint(str)
  if type(str) ~= "string" then
	error(("Usage: LibDeflate:EncodeForPrint(str):" ..
			" 'str' - string expected got '%s'."):format(type(str)), 2)
  end
  local strlen = #str
  local strlenMinus2 = strlen - 2
  local i = 1
  local buffer = {}
  local buffer_size = 0
  while i <= strlenMinus2 do
	local x1, x2, x3 = string_byte(str, i, i + 2)
	i = i + 3
	local cache = x1 + x2 * 256 + x3 * 65536
	local b1 = cache % 64
	cache = (cache - b1) / 64
	local b2 = cache % 64
	cache = (cache - b2) / 64
	local b3 = cache % 64
	local b4 = (cache - b3) / 64
	buffer_size = buffer_size + 1
	buffer[buffer_size] = _byte_to_6bit_char[b1] .. _byte_to_6bit_char[b2] ..
							_byte_to_6bit_char[b3] .. _byte_to_6bit_char[b4]
  end

  local cache = 0
  local cache_bitlen = 0
  while i <= strlen do
	local x = string_byte(str, i, i)
	cache = cache + x * _pow2[cache_bitlen]
	cache_bitlen = cache_bitlen + 8
	i = i + 1
  end
  while cache_bitlen > 0 do
	local bit6 = cache % 64
	buffer_size = buffer_size + 1
	buffer[buffer_size] = _byte_to_6bit_char[bit6]
	cache = (cache - bit6) / 64
	cache_bitlen = cache_bitlen - 6
  end

  return table_concat(buffer)
end

--- Decode the printable string produced by LibDeflate:EncodeForPrint.
-- "str" will have its prefixed and trailing control characters or space
-- removed before it is decoded, so it is easier to use if "str" comes form
-- user copy and paste with some prefixed or trailing spaces.
-- Then decode fails if the string contains any characters cant be produced by
-- LibDeflate:EncodeForPrint. That means, decode fails if the string contains a
-- characters NOT one of 26 lowercase letters, 26 uppercase letters,
-- 10 numbers digits, left parenthese, or right parenthese.
-- @param str [string] The string to be decoded
-- @return [string/nil] The decoded string if succeeds. nil if fails.
function LibDeflate:DecodeForPrint(str)
  if type(str) ~= "string" then
	error(("Usage: LibDeflate:DecodeForPrint(str):" ..
			" 'str' - string expected got '%s'."):format(type(str)), 2)
  end
  str = str:gsub("^[%c ]+", "")
  str = str:gsub("[%c ]+$", "")

  local strlen = #str
  if strlen == 1 then return nil end
  local strlenMinus3 = strlen - 3
  local i = 1
  local buffer = {}
  local buffer_size = 0
  while i <= strlenMinus3 do
	local x1, x2, x3, x4 = string_byte(str, i, i + 3)
	x1 = _6bit_to_byte[x1]
	x2 = _6bit_to_byte[x2]
	x3 = _6bit_to_byte[x3]
	x4 = _6bit_to_byte[x4]
	if not (x1 and x2 and x3 and x4) then return nil end
	i = i + 4
	local cache = x1 + x2 * 64 + x3 * 4096 + x4 * 262144
	local b1 = cache % 256
	cache = (cache - b1) / 256
	local b2 = cache % 256
	local b3 = (cache - b2) / 256
	buffer_size = buffer_size + 1
	buffer[buffer_size] = _byte_to_char[b1] .. _byte_to_char[b2] ..
							_byte_to_char[b3]
  end

  local cache = 0
  local cache_bitlen = 0
  while i <= strlen do
	local x = string_byte(str, i, i)
	x = _6bit_to_byte[x]
	if not x then return nil end
	cache = cache + x * _pow2[cache_bitlen]
	cache_bitlen = cache_bitlen + 6
	i = i + 1
  end

  while cache_bitlen >= 8 do
	local byte = cache % 256
	buffer_size = buffer_size + 1
	buffer[buffer_size] = _byte_to_char[byte]
	cache = (cache - byte) / 256
	cache_bitlen = cache_bitlen - 8
  end

  return table_concat(buffer)
end

local function InternalClearCache()
  _chat_channel_codec = nil
  _addon_channel_codec = nil
end

-- For test. Don't use the functions in this table for real application.
-- Stuffs in this table is subject to change.
LibDeflate.internals = {
  LoadStringToTable = LoadStringToTable,
  IsValidDictionary = IsValidDictionary,
  IsEqualAdler32 = IsEqualAdler32,
  _byte_to_6bit_char = _byte_to_6bit_char,
  _6bit_to_byte = _6bit_to_byte,
  InternalClearCache = InternalClearCache
}

end
--[[-----------------------------------------------------------------------------------------------------

												phys' texture lab

]]-------------------------------------------------------------------------------------------------------

local function getRandomDarkColor(max)
    local r = math.random(0, max)
    local g = math.random(0, max)
    local b = math.random(0, max)
    lastFullColor = {0, r, g, b}
    return lastFullColor 
end

-- Generate random colors
local function generateRandomColor(itter)
	
    --prepare last color for modding
    local fltr = lastFullColor[1] -- 0 or 2
    local r = lastFullColor[2] 
    local g = lastFullColor[3] 
    local b = lastFullColor[4] 
    local duplicate = math.random(0, 100) > entropy:GetInt()
    local percContrast = contrast:GetInt() * contrast:GetInt() / 255
    local linContrast = contrast:GetInt()

    if duplicate then
        return {2, 0, 0, 0} --set pixel filter to 2 to reference the previous pixel above.
    else
        local methodInt = method:GetInt()
        inversionsGetInt = inversions:GetInt()

        if methodInt == 0 then -- simple add
            r = r + r * (linContrast / 128) 
            g = g + g * (linContrast / 128) 
            b = b + b * (linContrast / 128) 
			
        elseif methodInt == 1 then --pick any random brighter color
            r = math.random(r, r + percContrast) 
            g = math.random(g, g + percContrast) 
            b = math.random(b, b + percContrast) 
			
        elseif methodInt == 2 then --mono
            r = r + percContrast 
            g = g + percContrast 
            b = b + percContrast 
			
        elseif methodInt == 3 then --outrun 
            r = r + math.random(0, linContrast / 3 + 60) 
            g = g + math.random(0, linContrast / 5 + 3) 
            b = b + math.random(0, linContrast / 6 + 20) 
			
        elseif methodInt == 4 then -- jitter
            r = r + math.floor(math.random(-r, r + linContrast)) 
            g = g + math.floor(math.random(-g, g + linContrast)) 
            b = b + math.floor(math.random(-b, b + linContrast)) 
			
        elseif methodInt == 5 then -- expo
            r = r * itter / 2 * (linContrast / 128) 
            g = g * itter / 2 * (linContrast / 128) 
            b = b * itter / 2 * (linContrast / 128) 
            r = math.random(r, r + percContrast) / 2 
            g = math.random(g, g + percContrast) / 2 
            b = math.random(b, b + percContrast) / 2 
			
        elseif methodInt == 6 then -- noisy expo
            r = r * itter * (linContrast / 128) * math.random()
            g = g * itter * (linContrast / 128) * math.random()
            b = b * itter * (linContrast / 128) * math.random()
			
        elseif methodInt == 11 then -- swap
            local tr, tg, tb = r, g, b
            local dirr = math.random() > 0.2
            r = dirr and tg or tb 
            g = dirr and tb or tr 
            b = dirr and tr or tg 
            inversionsGetInt = math.random(0, 7)
			
        else ---any color go wild
            r = math.random(0, 255) 
            g = math.random(0, 255) 
            b = math.random(0, 255) 
        end

        -- Ensure the values are within the range of 0 to 255
        r = math.floor(math.max(0, math.min(r, 255)))
        g = math.floor(math.max(0, math.min(g, 255)))
        b = math.floor(math.max(0, math.min(b, 255)))
		
        lastFullColor = {fltr, r, g, b}
        return lastFullColor
    end
end

local function GeneratePixelData(useCustom)
    local pixelTable = {}
    if useCustom then
        pixelTable = fullArray
    else
        --choose first color
        if method:GetInt() < 10 then
            pixelTable = getRandomDarkColor(math.random(0, 64))
        else
            pixelTable = getRandomDarkColor(255)
        end
		
		--we already have the first color, so make 7 more
        for i = 1, 7 do 
            local temptabl = generateRandomColor(i)
            for _, value in ipairs(temptabl) do
                table.insert(pixelTable, value)
            end
        end

        local controlFrames = 0
        local invR = inversionsGetInt == 1 or inversionsGetInt == 2 or inversionsGetInt == 6 or inversionsGetInt == 7
        local invG = inversionsGetInt == 2 or inversionsGetInt == 3 or inversionsGetInt == 4 or inversionsGetInt == 7
        local invB = inversionsGetInt == 4 or inversionsGetInt == 5 or inversionsGetInt == 6 or inversionsGetInt == 7

        --invert selected channels
        for i, value in ipairs(pixelTable) do
            if i % 4 == 1 then
                -- Skip, you are on a control frame
                if pixelTable[i] ~= 0 then
                    controlFrames = controlFrames + 1
                    i = i + 3
                end
            else
                if i % 4 == 2 and invR then
                    pixelTable[i] = 255 - value
                end
                if i % 4 == 3 and invG then
                    pixelTable[i] = 255 - value
                end
                if i % 4 == 0 and invB then
                    pixelTable[i] = 255 - value
                end
            end
        end

		--insert a white color if whole palette is the same color
        if controlFrames >= 7 then
            local tableLength = #pixelTable
            if tableLength >= 16 then
                for j = 1, 4 do
                    pixelTable[tableLength - j + 1] = nil
                end
                table.insert(pixelTable, 17, 0)
                table.insert(pixelTable, 18, 255)
                table.insert(pixelTable, 19, 255)
                table.insert(pixelTable, 20, 255)
            end
        end
    end

    local pixelData = string.char(unpack(pixelTable))
    fullArray = pixelTable

    -- Generate 1x8px png image 
	-- FYI: pixelTable is basically a bitmap. each group of 4 bytes indicates the color of one pixel.
	--      first = filter byte (0-4) improves compression and speed.
	--      second = red value (0-255)  
	--      third = green value (0-255)  
	--      fourth = blue value (0-255)  
	-- this took so much time to get exactly right. change one bit, and different software will show different pixels/errors...
	-- idea could be taken to generate larger png images. 
	-- references: https://en.wikipedia.org/wiki/PNG#Examples
	--             https://www.w3.org/TR/png/#3filter
	--	           http://www.libpng.org/pub/png/apps/pngcheck.html
	
	-- PNG header - pretty much the same for all pngs
    local header = string.char(137, 80, 78, 71, 13, 10, 26, 10)
	
	 -- IHDR chunk (1px by 8px) - https://www.w3.org/TR/png/#11IHDR
    local ihdr = string.char(0, 0, 0, 13) .. "IHDR" .. string.char(0, 0, 0, 1, 0, 0, 0, 8, 8, 2, 0, 0, 0, 183, 120, 2, 22)

    -- build IDAT chunk (size, "IDAT", compressedPixelData, crc) - https://www.w3.org/TR/png/#11IDAT
    local idatType = "IDAT"
    local compressedPixelData = LibDeflate.CompressZlib("", pixelData) --zlib, does the FChek, Deflate, and Adler32 thing
    local crc = util.CRC(idatType .. compressedPixelData)
    local crcBytes =
        string.char(
        bit.band(bit.rshift(crc, 24), 0xFF),
        bit.band(bit.rshift(crc, 16), 0xFF),
        bit.band(bit.rshift(crc, 8), 0xFF),
        bit.band(crc, 0xFF)
    )
    local sizeofchunk = string.char(0, 0, 0, string.len(compressedPixelData))
    local idat = sizeofchunk .. idatType .. compressedPixelData .. crcBytes 
	
	-- iend
    local iend = string.char(0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130)
	
    return header .. ihdr .. idat .. iend
end

--open and uncompress the data so we can edit it later
local function ExtractTextFromFile(fileName)
    local fileSize = file.Size(fileName, "DATA")
	
    if fileSize < 1024 then 
        local fileContents = file.Read(fileName, "DATA")
        local startIndex, endIndex = string.find(fileContents, "IDAT(.-)IEND") 
		
        if startIndex and endIndex then 
            local foundCompressedPixelData = string.sub(fileContents, startIndex + 4, endIndex - 3) 
			local uncompressedIDAT = LibDeflate.DecompressZlib("",foundCompressedPixelData)
			fullArray = {}
			
			for i = 1, #uncompressedIDAT do
				local byteValue = string.byte(uncompressedIDAT, i)
				table.insert(fullArray, byteValue)
			end
        end
    end
end

--make da file
local function saveAndSetTexture(useCustom)
    local currentTime = os.date("%Y%m%d_%H-%M-%S")
    local baseFileName = "lab_" .. tostring(currentTime) .. ".png"
    local filePath = folderInData .. baseFileName
    file.CreateDir(folderInData) 

    -- Update name if the file already exists
    local suffix = 1
    while file.Exists(filePath, "DATA") do
        baseFileName = "lab_" .. tostring(currentTime) .. "_" .. tostring(suffix) .. ".png"
        filePath = folderInData .. baseFileName
        suffix = suffix + 1
    end

    file.Write(filePath, GeneratePixelData(useCustom))

	--set the texture
    local path = "data/" .. filePath 
    RunConsoleCommand("pp_texturize", path)
end
concommand.Add("physTextureLab_generate", function(ply, cmd, args)
        saveAndSetTexture(false)
    end)


--awesome graphical texture browser 
local function OpenFileBrowser()
    if historyPanelOpen then return end
    historyPanelOpen = true

    local fileList = file.Find(folderInData .. "*", "DATA", "datedesc") 
	
    local f = vgui.Create("DFrame")
    f:SetSize(785, 600)
    f:Center()
    f:MakePopup()
    local baseTitle = "Showing " .. #fileList .. " Texture Files in ./data/" .. folderInData
    f:SetTitle(baseTitle)

    f.OnClose = function()
        historyPanelOpen = false
    end

    local Scroll = vgui.Create("DScrollPanel", f)
    Scroll:Dock(FILL)

    local AppList = vgui.Create("DIconLayout", Scroll)
    AppList:Dock(FILL)
    AppList:SetSpaceX(5)
    AppList:SetSpaceY(5)

    local ListLabel = vgui.Create("DLabel", AppList) -- Add a label that will be the only panel on its row
    ListLabel.OwnLine = true -- The magic variable that specifies this item has its own line all for itself
    ListLabel:SetText("Click any icon to apply it as a the new texture.\n(Right click to copy filename to clipboard.)\n")
    ListLabel:SetSize(700, 40)

    for _, fileName in ipairs(fileList) do
        if string.match(fileName, "^lab.*%.png$") then
            local imagePanel = vgui.Create("DImageButton")
            imagePanel:SetSize(64, 64)
            imagePanel:SetImage("data/" .. folderInData .. fileName)
            imagePanel:SetTooltip(fileName)

            imagePanel.DoClick = function()
                RunConsoleCommand("pp_texturize", "data/" .. folderInData .. fileName)
                ExtractTextFromFile(folderInData .. fileName)
            end
            imagePanel.DoRightClick = function()
                f:SetTitle(baseTitle .. " (added file " .. fileName .. " to clipboard.)")
                SetClipboardText(fileName)
            end

            AppList:Add(imagePanel)
        end
    end

    local clearButton = vgui.Create("DButton", f)
    clearButton:Dock(BOTTOM)
	
	local tooManyWarnings = ""
	if #fileList > 3621 then
		tooManyWarnings = " - You have too many textures!!!"
	end
    clearButton:SetText("Delete All Texture History" .. tooManyWarnings)
	clearButton:SetFont("DermaDefaultBold")
	clearButton:SetSize(400, 32)
    clearButton.DoClick = function()
        local confirmationPopup =
            Derma_Query(
            "Are you sure you want to delete all " ..#fileList.." textures?\n\nTip: You can view or manage these files in:\n./garrysmod/data/"..folderInData,
            "Confirmation",
            "Yes",
            function()
                for _, fileName in ipairs(fileList) do
                    if string.match(fileName, "^lab.*%.png$") then
                        file.Delete(folderInData .. fileName)
                    end
                end
                AppList:Clear()
                f:Close() 
                RunConsoleCommand("pp_texturize", "")
            end,
            "No",
            function()
            end
        )
        confirmationPopup:SetDeleteOnClose(true) 
    end
end
concommand.Add("physTextureLab_openTextureBrowser", OpenFileBrowser)

--awesome 8-way color picker
local function OpenColorPicker()   
    if colorPanelOpen then return end
    colorPanelOpen = true
	
    local frame = vgui.Create("DFrame")
    frame:SetSize(790, 321)
	frame:SetScreenLock(true)
	frame:SetPos( oldColorPanelPosX, oldColorPanelPosY )
	if oldColorPanelPosX + oldColorPanelPosY == 0 then frame:Center() end
    frame:SetTitle(addonName .. " - Color Picker")
    frame:MakePopup()
    frame.OnClose = function()
		oldColorPanelPosX, oldColorPanelPosY = frame:GetPos()
        colorPanelOpen = false
    end

	local smallerTables = {}
    local colorCubes = {}
    local rgbPickers = {}

    --split fullArray into 8 smaller color arrays
    local startIndex = 1
    local size = 4
    local previousTable = {} 
	for j = startIndex, size do
		table.insert(previousTable, fullArray[j])
	end

	for i = 1, 8 do
		local endIndex = startIndex + size - 1
		local subTable = {}

		for j = startIndex, endIndex do
			table.insert(subTable, fullArray[j])
		end

		if subTable[1] == 2 and subTable[2] == 0 and subTable[3] == 0 and subTable[4] == 0 then
			subTable = previousTable -- Replace with the previous table
		end

		table.insert(smallerTables, subTable)
		previousTable = subTable
		startIndex = endIndex + 1
	end
	
	--build the cool panel
    for i = 1, 8 do
        local x = 10 + (i - 1) * 86

        -- Color label
        local relativeLuminance = math.Round(
            math.sqrt(--https://alienryderflex.com/hsp.html
                0.299 * ((smallerTables[i][2] / 255) * (smallerTables[i][2] / 255)) +
                0.587 * ((smallerTables[i][3] / 255) * (smallerTables[i][3] / 255)) +
                0.114 * ((smallerTables[i][4] / 255) * (smallerTables[i][4] / 255))
				) * 100, 1) 
        local colorLabel = Label(tostring("R: " .. smallerTables[i][2]) ..
										  "\nG: " .. tostring(smallerTables[i][3]) ..
										  "\nB: " .. tostring(smallerTables[i][4]) .. 
										  "\n\nLum:\n" .. relativeLuminance.."%", frame)
        colorLabel:SetPos(x + 42, 110)
        colorLabel:SetSize(80, 100)
        colorLabel:SetHighlight(true)
        colorLabel:SetColor(Color(smallerTables[i][2], smallerTables[i][3], smallerTables[i][4]))

		local staticLabel = Label(tostring("Shift:"),frame)
        staticLabel:SetPos(x + 41, 182)
        staticLabel:SetSize(80, 100)
        staticLabel:SetColor(Color(200,200,200))
		
        -- Color cube
        local colorCube = vgui.Create("DColorCube", frame)
        colorCube:SetPos(x, 30)
        colorCube:SetSize(80, 80)

        -- Color picker
        local rgbPicker = vgui.Create("DRGBPicker", frame)
        rgbPicker:SetPos(x, 115)
        rgbPicker:SetSize(35, 140)

        local DColorButton = vgui.Create("DColorButton", frame)
        DColorButton:SetPos(x, 264)
        DColorButton:SetSize(80, 40)
        DColorButton:Paint(80, 40)
        local spare = "        "
        if i == 1 then
            DColorButton:SetText(spare .. math.Round(12.5 * i, 1) .. "%\n" .. spare .. "(Dark)")
        elseif i == 8 then
            DColorButton:SetText(spare .. math.Round(12.5 * i, 1) .. "%\n" .. spare .. "(Bright)")
        else
            DColorButton:SetText(spare .. math.Round(12.5 * i, 1) .. "%")
        end
        DColorButton:SetColor(Color(smallerTables[i][2], smallerTables[i][3], smallerTables[i][4]))
		
		--show raw rgb inputs if clicked
		DColorButton.DoClick = function()
			-- Create a popup frame
			local popupFrame = vgui.Create("DFrame")
			popupFrame:SetSize(160, 180)
			--popupFrame:Center()
			-- Get the current mouse position
			local mouseX, mouseY = input.GetCursorPos()
			local popupX = mouseX - 80
			local popupY = mouseY - 160
			popupFrame:SetPos( popupX, popupY )
			popupFrame:SetScreenLock(true)
			popupFrame:SetTitle("Color " .. i)
			popupFrame:SetVisible(true)
			popupFrame:MakePopup()  

			-- Create labels for red, green, and blue
			local redLabel = vgui.Create("DLabel", popupFrame)
			redLabel:SetPos(20, 40)
			redLabel:SetSize(60, 20)
			redLabel:SetText("Red:")

			local greenLabel = vgui.Create("DLabel", popupFrame)
			greenLabel:SetPos(20, 70)
			greenLabel:SetSize(60, 20)
			greenLabel:SetText("Green:")

			local blueLabel = vgui.Create("DLabel", popupFrame)
			blueLabel:SetPos(20, 100)
			blueLabel:SetSize(60, 20)
			blueLabel:SetText("Blue:")

			-- Create three DNumberWang elements
			local redInput = vgui.Create("DNumberWang", popupFrame)
			redInput:SetPos(80, 40)
			redInput:SetSize(60, 20)
			redInput:SetMinMax(0,255)
			redInput:SetValue(colorCubes[i]:GetRGB().r)

			local greenInput = vgui.Create("DNumberWang", popupFrame)
			greenInput:SetPos(80, 70)
			greenInput:SetSize(60, 20)
			greenInput:SetMinMax(0,255)
			greenInput:SetValue(colorCubes[i]:GetRGB().g)

			local blueInput = vgui.Create("DNumberWang", popupFrame)
			blueInput:SetPos(80, 100)
			blueInput:SetSize(60, 20)
			blueInput:SetMinMax(0,255)
			blueInput:SetValue(colorCubes[i]:GetRGB().b)

			-- Create an OK button
			local okBtn = vgui.Create("DButton", popupFrame)
			okBtn:SetPos(20, 130)
			okBtn:SetSize(120, 40)
			okBtn:SetText("OK")
			okBtn.DoClick = function()
				local red = math.Clamp(redInput:GetValue(), 0, 255)
				local green = math.Clamp(greenInput:GetValue(), 0, 255)
				local blue = math.Clamp(blueInput:GetValue(), 0, 255)
				
				fullArray = {}
				for j = 1, 8 do
					if j == i then
						table.insert(fullArray, 0)
						table.insert(fullArray, red)
						table.insert(fullArray, green)
						table.insert(fullArray, blue)
					else
						table.insert(fullArray, 0)
						table.insert(fullArray, colorCubes[j]:GetRGB().r)
						table.insert(fullArray, colorCubes[j]:GetRGB().g)
						table.insert(fullArray, colorCubes[j]:GetRGB().b)
					end
				end
				
				popupFrame:Close()
				frame:Close()
				OpenColorPicker()
			end   
			
			-- Add focus change listener to close the popup when focus is lost
			 popupFrame.OnFocusChanged = function(self, gained)
				if not gained then
					timer.Simple(0.1, function()
						local hasFocus = false
						for _, child in pairs(popupFrame:GetChildren()) do
							if child:HasFocus() then
								hasFocus = true
								break
							end
						end

						if not hasFocus then
							popupFrame:Close()
						end
					end)
				end
			end
		end

        -- Link the color cube and color picker
        rgbPicker.linkedCube = colorCube
        colorCube.linkedLabel = colorLabel
        colorCube.linkedPvw = DColorButton

        -- When the picked color is changed...
        function rgbPicker:OnChange(col)
            -- Get the hue of the RGB picker and the saturation and vibrance of the color cube
            local h = ColorToHSV(col)
            local _, s, v = ColorToHSV(colorCube:GetRGB())

            -- Mix them together and update the color cube
            col = HSVToColor(h, s, v)
            -- Update the color cube
            self.linkedCube:SetColor(col)

            -- Update the label
            local relativeLuminance = math.Round(
                math.sqrt(--https://alienryderflex.com/hsp.html
                    0.299 * ((col.r / 255) * (col.r / 255)) + 
					0.587 * ((col.g / 255) * (col.g / 255)) +
                    0.114 * ((col.b / 255) * (col.b / 255))
					) * 100, 1) 

            self.linkedCube.linkedLabel:SetText("R: " .. col.r .. "\nG: " .. col.g .. "\nB: " .. col.b .. "\n\nLum:\n" .. relativeLuminance.."%")
            self.linkedCube.linkedLabel:SetColor(Color(col.r, col.g, col.b))
            self.linkedCube.linkedPvw:SetColor(Color(col.r, col.g, col.b))
        end

        -- When the color cube is changed...
        function colorCube:OnUserChanged(col)
            local h, s, v = ColorToHSV(col)
            local rgb = HSVToColor(h, 1, 1)

            -- Update the color picker
            --self.linkedPicker:SetRGB(rgb)

            -- Update the label
            local relativeLuminance = math.Round(
                math.sqrt(--https://alienryderflex.com/hsp.html
                    0.299 * ((col.r / 255) * (col.r / 255)) + 
					0.587 * ((col.g / 255) * (col.g / 255)) +
                    0.114 * ((col.b / 255) * (col.b / 255))
					) * 100, 1) 
            self.linkedLabel:SetText("R: " .. col.r .. "\nG: " .. col.g .. "\nB: " .. col.b .. "\n\nLum:\n" .. relativeLuminance.."%")
            self.linkedLabel:SetColor(Color(col.r, col.g, col.b))
            self.linkedPvw:SetColor(Color(col.r, col.g, col.b))
        end

        -- Store the color cube and color picker references
        table.insert(colorCubes, colorCube)
        table.insert(rgbPickers, rgbPicker)

        -- Associate the color cube and color picker
        colorCube.linkedPicker = rgbPicker
		
    end
	
	-- shift buttons:
    for i = 1, 8 do
        local x = 10 + (i - 1) * 86
        local shiftLeftBtn = vgui.Create("DButton", frame)
        shiftLeftBtn:SetPos(x + 38, 239)
        shiftLeftBtn:SetSize(19, 16)
        shiftLeftBtn:SetText("<")
		shiftLeftBtn.DoClick = function()
			fullArray = {}
			for j = 1, 8 do
				table.insert(fullArray, 0)
				table.insert(fullArray, colorCubes[j]:GetRGB().r)
				table.insert(fullArray, colorCubes[j]:GetRGB().g)
				table.insert(fullArray, colorCubes[j]:GetRGB().b)
			end
			
			local indices = { {1, 29}, {5, 1}, {9, 5}, {13, 9}, {17, 13}, {21, 17}, {25, 21}, {29, 25} }
			if i >= 1 and i <= 8 then
			  local tf, tr, tg, tb = fullArray[indices[i][1]], fullArray[indices[i][1] + 1], fullArray[indices[i][1] + 2], fullArray[indices[i][1] + 3]
			  fullArray[indices[i][1]], fullArray[indices[i][1] + 1], fullArray[indices[i][1] + 2], fullArray[indices[i][1] + 3] = 
			  fullArray[indices[i][2]], fullArray[indices[i][2] + 1], fullArray[indices[i][2] + 2], fullArray[indices[i][2] + 3]
			  fullArray[indices[i][2]], fullArray[indices[i][2] + 1], fullArray[indices[i][2] + 2], fullArray[indices[i][2] + 3] = tf, tr, tg, tb
			end

			frame:Close()
			OpenColorPicker()
			
		end
		
        local shiftRightBtn = vgui.Create("DButton", frame)
        shiftRightBtn:SetPos(x + 60, 239)
        shiftRightBtn:SetSize(19, 16)
        shiftRightBtn:SetText(">")
		shiftRightBtn.DoClick = function()
			fullArray = {}
			for j = 1, 8 do
				table.insert(fullArray, 0)
				table.insert(fullArray, colorCubes[j]:GetRGB().r)
				table.insert(fullArray, colorCubes[j]:GetRGB().g)
				table.insert(fullArray, colorCubes[j]:GetRGB().b)
			end
			
			local indices = { {1, 5}, {5, 9}, {9, 13}, {13, 17}, {17, 21}, {21, 25}, {25, 29}, {29, 1} }
			if i >= 1 and i <= 8 then
			  local tf, tr, tg, tb = fullArray[indices[i][1]], fullArray[indices[i][1] + 1], fullArray[indices[i][1] + 2], fullArray[indices[i][1] + 3]
			  fullArray[indices[i][1]], fullArray[indices[i][1] + 1], fullArray[indices[i][1] + 2], fullArray[indices[i][1] + 3] = 
			  fullArray[indices[i][2]], fullArray[indices[i][2] + 1], fullArray[indices[i][2] + 2], fullArray[indices[i][2] + 3]
			  fullArray[indices[i][2]], fullArray[indices[i][2] + 1], fullArray[indices[i][2] + 2], fullArray[indices[i][2] + 3] = tf, tr, tg, tb
			end

			frame:Close()
			OpenColorPicker()
		
		
		end
	end
	
    -- Apply button
    local applyButton = vgui.Create("DButton", frame)
    applyButton:SetText("Apply")
    applyButton:SetPos(699, 30)
    applyButton:SetSize(80, 50)
    applyButton.DoClick = function()
        fullArray = {}
        for i = 1, 8 do
            table.insert(fullArray, 0)
            table.insert(fullArray, colorCubes[i]:GetRGB().r)
            table.insert(fullArray, colorCubes[i]:GetRGB().g)
            table.insert(fullArray, colorCubes[i]:GetRGB().b)
        end
		
        saveAndSetTexture(true)
    end
	
    -- reset button
    local applyButton = vgui.Create("DButton", frame)
    applyButton:SetText("Reset")
    applyButton:SetPos(699, 85)
    applyButton:SetSize(80, 50)
    applyButton.DoClick = function()
        frame:Close() 
		if math.random() > 0.1 then --egg?
			fullArray = defaultArray 
 		else 
			fullArray = math.random() > 0.5 and CGAp1 or CGAp0
			print(addonName .. " - Take me back to 1983")
		end
        RunConsoleCommand("pp_texturize", "")
        OpenColorPicker()
    end
	
    -- rand button
    local applyButton = vgui.Create("DButton", frame)
    applyButton:SetText("Randomize!!")
    applyButton:SetPos(699, 140)
    applyButton:SetSize(80, 50)
    applyButton.DoClick = function()
        GeneratePixelData(false)
        frame:Close()
        OpenColorPicker()
    end

    -- rotate text
	local staticLabel = Label(tostring("Rotate ALL:"),frame)
	staticLabel:SetPos(700, 190)
	staticLabel:SetColor(Color(200,200,200))
		
    -- rotate L button
    local applyButton = vgui.Create("DButton", frame)
    applyButton:SetText("<<<")
    applyButton:SetPos(699, 210)
    applyButton:SetSize(38, 16)
    applyButton.DoClick = function()  
        fullArray = {}
        for i = 1, 8 do
            table.insert(fullArray, 0)
            table.insert(fullArray, colorCubes[i]:GetRGB().r)
            table.insert(fullArray, colorCubes[i]:GetRGB().g)
            table.insert(fullArray, colorCubes[i]:GetRGB().b)
        end
		
		for i = 1, 32-4 do
			table.insert( fullArray, 1, table.remove( fullArray, #fullArray ) )
		end
        frame:Close() 
		OpenColorPicker()
    end
	
    -- rotate R button
    local applyButton = vgui.Create("DButton", frame)
    applyButton:SetText(">>>")
    applyButton:SetPos(740, 210)
    applyButton:SetSize(38, 16)
    applyButton.DoClick = function()  
        fullArray = {}
        for i = 1, 8 do
            table.insert(fullArray, 0)
            table.insert(fullArray, colorCubes[i]:GetRGB().r)
            table.insert(fullArray, colorCubes[i]:GetRGB().g)
            table.insert(fullArray, colorCubes[i]:GetRGB().b)
        end
		
		for i = 1, 4 do
			table.insert( fullArray, 1, table.remove( fullArray, #fullArray ) )
		end
        frame:Close() 
		OpenColorPicker()
    end
			
    -- flip button
    local applyButton = vgui.Create("DButton", frame)
    applyButton:SetText("Flip")
    applyButton:SetPos(699, 231)
    applyButton:SetSize(80, 16)
    applyButton.DoClick = function()  
        fullArray = {}
        for i = 1, 8 do
            table.insert(fullArray, 0)
            table.insert(fullArray, colorCubes[i]:GetRGB().r)
            table.insert(fullArray, colorCubes[i]:GetRGB().g)
            table.insert(fullArray, colorCubes[i]:GetRGB().b)
        end
		
		local newArray = {}
		for i = 1, 8 do
		  local subArray = {}
		  for j = 1, 4 do
			local index = (i - 1) * 4 + j
			table.insert(subArray, fullArray[index])
		  end
		  table.insert(newArray, subArray)
		end
	
		local rev = {}
		for i=#newArray, 1, -1 do
			rev[#rev+1] = newArray[i]
		end
		newArray = rev
		
		fullArray = {}
		for i = 1, #newArray do
		  for j = 1, #newArray[i] do
			table.insert(fullArray, newArray[i][j])
		  end
		end
		
        frame:Close() 
		OpenColorPicker()
    end
	
    -- feature text
	local staticLabel2 = Label(tostring("Hint: Click a color preview to manually set its RGB value."),frame)
	staticLabel2:SetPos(10, 304) --220
	staticLabel2:SetSize(600,16)
	staticLabel2:SetColor(Color(200,200,200))
	
    -- exit button
    local applyButton = vgui.Create("DButton", frame)
    applyButton:SetText("exit")
    applyButton:SetPos(699, 255)
    applyButton:SetSize(80, 50)
    applyButton.DoClick = function()
        frame:Close() 
    end

    --  update all color cubes and labels with initial color
    for i = 1, 8 do
		local toColor = Color(smallerTables[i][2], smallerTables[i][3], smallerTables[i][4])
        colorCubes[i]:SetColor(toColor)
        colorCubes[i]:SetRGB(toColor) --this line is required. else, colorcube may regress to a primary color. hsv rounding error?
    end
	
end
concommand.Add("physTextureLab_openPicker", OpenColorPicker)

--populate utility menu
function phystexturelab.ClientOptionsMenu(self)
    if not IsValid(self) then return end

    self:Help("Custom Texturize Tools:"):SetFont("DermaDefaultBold")
    local bton = self:Button("> Open Custom Texturizer Tool <", "physTextureLab_openPicker")
    bton:SetSize(360, 45)
	bton:SetFont("DermaDefaultBold")

    self:Help("Random Texturize Tools:"):SetFont("DermaDefaultBold")
    local combobox, label = self:ComboBox("Color Gen Method", "physTextureLab_method")
    combobox:SetSortItems(false)
    combobox:AddChoice("Simple Add", 0, false, "color_lab_icons/add.png")
    combobox:AddChoice("Any Brighter", 1, false, "color_lab_icons/norm.png")
    combobox:AddChoice("Monochrome", 2, false, "color_lab_icons/mono.png")
    combobox:AddChoice("Outrun", 3, true, "color_lab_icons/outrun.png")
    combobox:AddChoice("Jitter", 4, false, "color_lab_icons/jitter.png")
    combobox:AddChoice("Expo", 5, false, "color_lab_icons/expo.png")
    combobox:AddChoice("Noisy Expo", 6, false, "color_lab_icons/expo2.png")
    combobox:AddChoice("Swap", 11, false, "color_lab_icons/swap.png")
    combobox:AddChoice("Corruption", 99, false, "color_lab_icons/bitbang.png")
	
    local combobox2, label = self:ComboBox("Invert Channels", "physTextureLab_inversions")
    combobox2:SetSortItems(false)
    combobox2:AddChoice("None", 0, true) --000
    combobox2:AddChoice("Invert ALL", 7, false, "icon16/contrast.png") --111
    combobox2:AddChoice("Invert Red", 1, false, "icon16/flag_red.png") --100
    combobox2:AddChoice("Invert Yellow", 2, false, "icon16/flag_yellow.png") --110
    combobox2:AddChoice("Invert Green", 3, false, "icon16/flag_green.png") --010
    combobox2:AddChoice("Invert Cyan", 4, false, "icon16/flag_blue.png") --011
    combobox2:AddChoice("Invert Blue", 5, false, "icon16/shape_square.png") --001
    combobox2:AddChoice("Invert Violet", 6, false, "icon16/flag_purple.png") --101

    self:NumSlider("Entropy: ", "physTextureLab_entropy", 0, 100, 0)
    self:NumSlider("Intensity: ", "physTextureLab_contrast", 0, 255, 0)

    local bton2 = self:Button("Create Randomly Generated Texture", "physTextureLab_generate")
    --bton2:SetSize(360, 45)
	bton2:SetFont("DermaDefaultBold")

    self:Help("Misc. Controls:"):SetFont("DermaDefaultBold")
	 
    local bton3 = self:Button("View Texture History", "physTextureLab_openTextureBrowser")
	bton3:SetFont("DermaDefaultBold")
	
    local bton4 = self:Button("Disable", "pp_texturize", "")
	bton4:SetFont("DermaDefaultBold")
end

hook.Add("PopulateToolMenu", "PhysTextureLab", function()
        spawnmenu.AddToolMenuOption(
            "Utilities",
            "Phys' Tools",
            "PhysTextureLab",
            "Texture Lab",
            "",
            "",
            phystexturelab.ClientOptionsMenu,
            {}
        ) end)
