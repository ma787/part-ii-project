### create_ctz id ~pointer ~file_size
- int -> pointer:int64 -> file_size:int64 -> Tag.t * Cstruct.t
- Creates a cstruct struct of size 8 * 2
- The pointer is written to the struct at offset 0
- The file size value is written to the struct at offset 8
- An LFS_TYPE_STRUCT tag is created
### ctz_of_cstruct cs
- Cstruct.t -> (int64 * int64) option
- Returns None if the cstruct length is less than 16
- Calls Cstruct.LE on the two int64 values (pointer and file size) stored in the cstruct, i.e. converts the integers to little endian
### n_pointers
- int -> int
- Maps 0 to 0 and 1 to 1
- Returns log<sub>2</sub>(n) if n is a power of 2 and 1 otherwise
- **Question**
	- A block can have anywhere between 1 and log<sub>2</sub>(n) pointers to other blocks
	- This is because if n is divisible by 2<sup>x</sup> then block n has a pointer to block n-2<sup>x</sup>
	- But this function returns 1 if n is not a power of 2
	- So why does it still work?
### of_block index cs
- int -> Cstruct.t -> int64 list * Cstruct.t
- Creates a list of pointers from the cstruct
- Calculates the offset where the pointers end in a block and returns a cstruct with that offset along with the pointers
### last_block_index ~file_size ~block_size
- int -> Cstruct.t -> int64 list * Cstruct.t
- Works out the available space to write to by subtracting the number of pointers * pointer size (8) from the block size
- If the available space is greater than the given file size then the current block index is returned
- Otherwise, the next block is checked and the amount of bytes to write is decremented by the amount of available space in the current block
- Returns the last block index that a file of size file_size is stored in, starting from index 0
### first_byte_on_index ~block_size index
- block_size:int -> int -> int
- Returns 0 if index is 0
- Subtracts the size of the pointers on the previous block from the provided block size
- This gives you the size of the free space on the previous block
- Adds this to the result of calling first_byte_on_index on the previous index
- Gives you the free space from a given block index to index 0
