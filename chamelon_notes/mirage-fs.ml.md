### module Make(Sectors: Mirage_block.S) (Clock : Mirage_clock.PCLOCK)
- This_Block is an instance of the Make module in Block_ops
#### type lookahead
- Stores the lookahead buffer used for block allocation
- Contains an offset and a list of block indices
- blocks is an int64 list containing a bitmap of the blocks stored in the lookahead buffer **(need to confirm this)**
#### type t
 - Type representing the state of the littlefs block:
	 - block : This_Block.t (the internal state of the block device)
	 - block_size : int
	 - program_block_size : int
	 - lookahead : lookahead ref (a reference to the lookahead buffer - used to update buffer)
	 - file_size_max : Cstruct.uint64
	 - name_length_max : Cstruct.uint32
	 - new_block_mutex : Lwt_mutex.t  (Lwt mutex for concurrent programming)
#### module Read
##### block_of_block_number {block_size; block; program_block_size; \_} block_location
- t -> int64 -> (Chamelon.Block.t)
- `` get the wodge of data at this block number, and attempt to parse it ``
- calls This_Block.read on the provided block at the provided index into a cstruct
- calls Chamelon.block.of_cstruct to get the block (which in this case is a revision count and series of commits) and returns result containing Ok and the block
- returns Error (\`Chamelon \`Corrupt) if this fails
##### block_of_block_pair t (l1, l2)
- t -> int64 * int64 -> (Chamelon.Block.t, [> \`Block of This_Block error | \`Chamelon of [> \`Corrupt ]]) Lwt_result.t
- `` get the blocks at pair (first, second), parse them, and return whichever is more recent ``
#### module Traverse
##### get_ctz_pointers t l index pointer
- t -> (int64 list, This_Block.error) result -> int -> int64 -> (int64 list, This_Block.error) Lwt_result.t
- The int64 list in l is the list of pointers, index is the specified block index and pointer is the current pointer
- This_Block.read t.block pointer [data] reads a cstruct into the list appended which takes label 'data'
- Chamelon.File.of_block is used to get the pointers and cstruct with offset starting at data region
- If the list of pointers from data is empty, returns the current pointer consed to l
- Else, takes the head of the pointer list and calls itself with pointer consed to l, index decremented by one and the head as the current pointer
##### follow_links t visited
- t -> (int64 * int64) list -> Chamelon.Entry.link -> (int64 list, This_Block.error) Lwt_result.t
- 
#### module Find
##### entries_of_name : t -> directory_head -> string -> (blockwise_entry_list list, [\`No_id of key | \`Not_found of key]) result Lwt.t
- ``[entries_of_name t head name] scans [head] (and any subsequent blockpairs in the directory's hardtail list) for `id` entries matching [name]. If an `id` is found for [name], all entries matching `id` from the directory are returned (compacted).
##### find_first_blockpair_of_directory : t -> directory_head -> string list -> [\`Basename_on of directory_head | \`No_id of string | \`No_structs] Lwt.t
- ``[find_first_blockpair_of_directory t head l] finds and enters the segments in [l] recursively until none remain. It returns \`No_id if an entry is not present and \`No_structs if an entry is present, but does not represent a valid directory.
#### module File_read
- type specifications for get and get_partial functions
##### get_ctz t key (pointer, file_size)
- t -> 'a -> int64 * int -> (string, [> \`Not_found of 'a]) result Lwt.t
- \`Not_found is a type variable
- last_block_index is used to get the index of the last block that the file is stored in
- read_block is called with an empty list, reading the ctz entries into this list
- The list is concatenated and trimmed to length file_size
- Copies the content of the list into a string and returns result containing Ok and this string 
###### read_block l index pointer
- int -> int64 -> (Cstruct.t list, This_Block.error) result Lwt.t
- Reads data from cstruct stored in t's block into cstruct 'data'
- Uses Chamelon.File.of_block to get pointers and data_region
- pointer_region is the section of data containing the pointers
- Debug information about the current block index stored
- Calls itself with data_region consed to l, index decremented by 1 and head of pointers as the current pointer
##### get_value t parent_dir_head filename
- t -> directory_head -> string -> ([> \`Ctz of int64 * int | \`Inline of string], [> \`Not_found of string | \`Value_expected of string]) result
- \`Ctz and \`Inline are type variables
- Calls Find.entries_of_name
- If error or empty list is returned then returns Error with \`Not_found type
- Reverses the list and takes the second element of the first pair to get the last block from the list of blocks
- Identifies whether the entries correspond to an inline file, a ctz or a directory (error)
- Gets the ctz id from entry by calling Chamelon.File.ctz_of_cstruct
- Returns result containing Ok and \`Ctz type, which changes the file size type in ctz id to a string
##### get t key : (string, error) result Lwt.t
- t -> key -> (string, error) result Lwt.t
- \`Value_expected and \`Basename_on are type variables
- Splits key into a string list on t's segments
- If key refers to a file, calls get_value on the head of the string list starting at root directory and passes the result to map_result
- If key refers to a directory, takes dirname which is the string list with the last entry (filename) stripped
- calls Find.find_first_blockpair_of_directory on dirname and passes result to map_result or returns result containing Error and \`Not_found
###### map_result
- ([< \`Ctz of int64 * int | \`Inline of string ],  [< \`Not_found of string | \`Value_expected of string ])  result ->  (string, [> \`Not_found of key | \`Value_expected of key ]) result Lwt.t
- Calls get_ctz on a match with an Ok result with a \`Ctz containing pointer and file size
- Returns Ok \`Inline result as is
- Converts the strings associated with Error  \`Not_found\\\`Value_expected results to keys and returns them
#####  address_of_index t ~desired_index (pointer, index)
- t -> desired_index:int -> int64 * int -> (int64, [> \`Not_found of key]) result Lwt.t
- If the current block index is the desired index then returns the current pointer
- Reads data from cstruct stored in t's block into cstruct 'data'
- Catches and logs read error, returning Error result containing \`Not_found and empty key
- Calls Chamelon.File.of_block to get pointers from t's block
- `worst case: we want an index that's between our index and (our index / 2), so we can't jump to it (or this index isn't a multiple of 2, so we only have one link); we just have to iterate backward until we get there
- Checks if the desired index is greater than half of the current index, or if there are less than two pointers
- If this is the case, either calls itself with the head of pointers and index decremented by 1 (go to previous block), or returns Error result with containing \`Not_found and empty key if the pointer list does not have a head
- Otherwise, either calls itself with the second value of pointers index halved or returns Error result with containing \`Not_found and empty key if the match fails
##### get_ctz_partial t key ~offset ~length (pointer, file_size)
- t -> key -> offset:int -> length:int -> int64 * int -> (string, [> \`Not_found of key]) result Lwt.t
- last_byte is the minimum of the file size and the sum of the two labelled arguments offset and length, i.e. caller can get up to file_size amount of data from blocks
- Uses Chamelon.File.last_block_index to get the last block index of the file, which is used to get the index of the last byte to read by calling Chamelon.File.last_block_index with file_size=last_byte
- Calls address_of_index t with the index of the last byte to read as the desired index and the last block index as the start index
- The result of this is a pointer to the last byte of interest
- Chamelon.File.last_block_index is called with file_size=offset to get offset_index, the block index of the starting block to read from
- read_raw_blocks is called with offset_index and the pointer to and block index of the last byte of interest
- Returns result containing Ok and "" if the list is empty 
- ``since our list is just the raw block contents of the relevant bit of the file, we probably need to drop some bytes from the beginning in order to correctly return the file starting at the right offset
- Calls Chamelon.File.first_byte_on_index with offset_index to get the offset of the first block
- (regarding the line below) ``this calculation is correct *if* we correctly identified the first block associated with this offset. Otherwise it's wrong garbage nonsense, so let's hope we got that first block correct :sweat_smile:
- Shifts the offset of the first block in the list to the offset subtracted by the first block offset as explained in the first comment in this method
- The first block is consed to the front of the block list and the list is concatenated into one cstruct before being converted into a string
- ``we need to trim the results to either:
	``- the requested length, if offset + length is < file size
	``- the file size minus the offset, if offset + length is > file_size
###### read_raw_blocks ~offset_index l index pointer
- offset_index:int -> Cstruct.t list -> int -> int64 -> (Cstruct.t list, This_Block.error) result Lwt.t
- Reads data from cstruct stored in t's block into cstruct 'data'
- Calls Chamelon.File.of_block to get pointers and data_region from data
- Conses the data_region to input l to get accumulated_data
- If the current index is not greater than offset_index or the pointer array is empty then returns result containing Ok and accumulated_data
- Otherwise, calls itself with accumulated data, current index decremented by 1 and the head of the pointer list
#### module File_write
- `` [set_in_drectory directory_head t filename data] creates entries in [directory] for [filename] pointing to [data]``
- type specification for set_in_directory function
##### write_ctz_block t blocks written index so_far data
- t -> int64 list -> (int * int64) list -> int -> int -> string -> ((int * int64) list, [> \`No_space]) result Lwt.t
- \`No_space is a type variable
- ``we purposely don't reverse the list because we're going to want the *last* block for inclusion in the ctz structure
- If so_far is greater than or equal to the length of data, then return result containing Ok and written
- Otherwise, if blocks is empty, return result containing Error and \`No_space
- Otherwise, the head and tail of the list blocks are separated in the last pattern, with the head of blocks being a pointer
- An empty cstruct block_cs of size t.block_size is created
- Chamelon.File.n_pointers is used to get the number of CTZ pointers for the block at this index, and the space taken up by these pointers (skip_list_length) is calculated by multplying the result by 8
- The length of the data to write to this block is the minimum of the space available in the block (t.block_size - skip_list_length) and the length of data left to write ((String.length data) - so_far)
- ``the 0th item in the skip list is always (index - 1). Only exception is the last block in the list (the first block in the file), which has no skip list
- If written is empty, does nothing
- ``the first entry in the skip list should be for block _last_index, which is index - 1
- Otherwise, the first entry of written is mapped to (\_last_index, last_pointer) and last_pointer is written to block_cs at offset 0
- The CTZ pointers are written by iterating from 1 to skip_list_size - 1
- For each value of n_skip_list, the destination_block_index is found by dividing the index by 1 left-shifted n_skip_list times
- Then, point_index is found by getting the pointer from written and is written to block_cs at offset (n_skip_list * 8)
- data_length characters are copied from data at offset so_far to the cstruct block_cs at offset skip_list_length (its data region)
- This_Block.write is called to write block_cs to t's block, returning a result Error \`No_space if an error is encountered
- Calls itself, consing (index, pointer) to written, incrementing index by 1 and incrementing so_far by data_length
##### write_ctz t data
- t -> string -> ((int * int64) list, write_error) result Lwt.t
- ``Get the correct number of blocks to write 'data' as a CTZ, then write it.
- Calls Chamelon.File.last_block_index with file_size being the length of the data to write to get the last block index
- Uses Allocate.get_blocks with last_block_index + 1 to get blocks
- Calls write_ctz_block with blocks=blocks, written=[], index=0, so_far=0 and data=data
##### write_in_ctz dir block_pair t filename data entries
- int64 * int64 -> t -> string -> string -> Chamelon.Entry.t list -> (unit, write_error) result Lwt.t
- ``Find the correct directory structure in which to write the metadata entry for the CTZ pointer. Write the CTZ, then write the metadata.
- Calls Read.block_of_block_pair to get directory root block, or returns result containing Error, \`Not_found and filename key
- If the directory has a hardtail next_blockpair where the directory continues, calls itself with dir_block_pair=next_blockpair
- Otherwise, gets data length and calls write_ctz
- If the file is written with no errors, then the head of written is matched with (\_last_index, last_pointer)
- The block id next is set to 1 if the root directory does not contain any block ids, or 1 more than the highest idea otherwise
- A CTZ ID is created by calling Chamelon.File.create_ctz with id next
