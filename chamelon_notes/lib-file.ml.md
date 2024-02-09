### name n id
- string -> int -> Tag.t * Cstruct.t
- creates an Entry with a NAME tag and the string n (the name) converted to a cstruct
### create_inline id contents
- int -> Cstruct.t -> Tag.t
- returns a STRUCT tag with length field set to the length of contents (the file itself)
### create_ctz id ~pointer ~file_size
- int -> pointer:int64 -> file_size:int64 -> Tag.t * Cstruct.t
- Creates a cstruct cs of size 8 * 2 bytes
- The pointer is written to cs at offset 0
- The file size value is written to cs at offset 8
- Returns an Entry consisting of a newly created STRUCT tag and cs
- **comment from littlefs/SPEC.md (amended to reflect change to 64-bit):**
	- `These files are stored in a skip-list in reverse, with a pointer to the head of the skip-list... CTZ-struct fields:`
	- `File head (64-bits) - Pointer to the block that is the head of the file's CTZ skip-list.`
	- `File size (64 bits) - Size of the file in bytes.`
### ctz_of_cstruct cs
- Cstruct.t -> (int64 * int64) option
- If the length of cs is less than 16 bytes, returns None 
- Otherwise, gets the pointer and the file size from cs and returns them
### n_pointers
- int -> int
- Maps 0 to 0 and 1 to 1
- Returns log<sub>2</sub>(n) if n is a power of 2 and 1 otherwise
- Used to calculate the file size equation described in littlefs/DESIGN.md recursively
### of_block index cs
- int -> Cstruct.t -> int64 list * Cstruct.t
- Takes a block and its index
- If index is a power of 2, reads a list of log<sub>2</sub>index pointers from the block
- If index is not a power of 2 but >=1, reads a list containing one pointer from the block
- If index = 0 then reads an empty list from the block
- Finds the length of the data region by subtracting the length of the pointers read from the length of the block
- Truncates the block to the data region and return it along with the list of pointers
### last_block_index ~file_size ~block_size
- file_size:int -> block_size:int -> int
- Calls aux with block_index = 0
- Gives you the last skip list index that a file of size file_size will be written to
- Recursive implementation of the following equation (from littlefs/DESIGN.md):

![](https://camo.githubusercontent.com/5438e3ffcd58b42c3d7faa596de021411c5db45423281a8eb4506be1e631d6ca/68747470733a2f2f6c617465782e636f6465636f67732e636f6d2f7376672e6c617465783f6e2532302533442532302535436c6566742535436c666c6f6f72253543667261632537424e2d2535436672616325374277253744253742382537442535436c65667425323825354374657874253742706f70636f756e742537442535436c656674253238253543667261632537424e253744253742422d322535436672616325374277253744253742382537442537442d3125354372696768742532392b322535437269676874253239253744253742422d32253543667261632537427725374425374238253744253744253543726967687425354372666c6f6f72)

where n is the index, N is the file size, w is the word width (64) and B is the block size
#### aux block_index bytes_to_write
- int -> int -> int
- If block_index is a power of two, can_write = block_size - the length of log<sub>2</sub>index pointers
- If block_index is not a power of two but >= 1, can_write = block_size - the length of one pointer
- Else, can_write = block_size
- If the result >= bytes_to_write then returns block_index
- Else, calls aux recursively with block_index incremented by 1 and bytes_to_write decremented by can_write
### first_byte_on_index ~block_size index
- block_size:int -> int -> int
- If the previous index = 0 then returns 0
- Else:
	- If the previous index is a power of two, subtracts the length of log<sub>2</sub>index pointers from block_size
	- If the previous index is not a power of 2 but >= 1 then subtracts the length of one pointer from block_size
	- Else (previous index is 0), block_size does not change
	- Adds the result above to the result of a call to first_byte_on_index with the same block_size and the index decremented by 1
	- Gives you the size offset of the skip list at a block index without the pointers in bytes (i.e. the size in bytes of the file at the start of this block)
