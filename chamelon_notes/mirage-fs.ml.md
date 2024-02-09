### module Make(Sectors: Mirage_block.S) (Clock : Mirage_clock.PCLOCK)
- This_Block is an instance of the Make module in Block_ops
#### type lookahead
- Stores the lookahead buffer used for block allocation
- offset is the block number at which the lookahead buffer begins
- blocks is list of block pointers in the lookahead buffer
#### type t
 - Type representing the littlefs block information and block device:
	 - block : This_Block.t (the intermediate interface between the block device and the chamelon block operations)
	 - block_size : int
	 - program_block_size : int (used to align metadata blocks with padding if necessary)
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
- If there is an error, returns it
- Else, if index=1 conses pointer to l and returns the list of pointers
- Else, creates a cstruct data of size t.block_size and reads the block at block number pointer into data
- Calls File.of_block to get the pointer region of the block as a list
- If the pointer list is empty, conses pointer to l and returns l
- Else, takes the head of the pointer list as next and calls itself with the same block, pointer consed to l (as part of an Ok result), index decremented by 1 and pointer set to next
- Gets all of the pointers associated with a file
##### follow_links t visited
- t -> (int64 * int64) list -> Chamelon.Entry.link -> (int64 list, This_Block.error) Lwt_result.t
- takes a block t, a list of visited pointers and a Link
- Checks if the Link matches a Data Link (corresponding to a block) with a pointer and length
- If it does, converts length (file_size) to an int (from int64) and calls File.last_block_index on file_size with the block size of t to get the block index
- Calls get_ctz_pointers on the block with the block index and the pointer and returns the result
- Else, matches the Link to a Metadata Link
- If the metadata pair pointers in this Link are already in visited, returns a \`Disconnected Error
- Else, calls block_of_block_pair on the metadata pair pointers to get the most recent revision of this metadata block
- If this does not return an error (\`Block, \`Chamelon \`Corrupt, \`Disconnected) and matches to an Ok result with a block, calls Blocked.linked_blocks on the block to get a list of Links
- Accumulates a list of pointers to all used blocks in the filesystem by using a function which recursively calls follow_links on every element in the list of Links and appends the result to the list
- Returns any errors that are raised
##### last_block t pair
- t -> int64 * int64 -> (int64 * int64, [> \`Block of This_Block.error | \`Chamelon of [> \`Corrupt ]]) Lwt_result.t
- `[last_block t pair] returns the last blockpair in the hardtail linked list starting at [pair], which may well be [pair] itself`
- Calls block_of_block_pair to get the most recent revision on disk
- Finds the first hardtail entry in the block
- If this entry matches to None, returns pair
- Else, calls Chamelon.Dir.hard_tail_links on the entry
- If the result matches to None, returns pair
- Else, calls last_block on the result
#### module Allocate
##### unused t used_blocks
- t -> int64 list -> int * int64 list
- Creates IntSet, an instance of the Set module parameterised with the Int64 type
- Gets the number of blocks currently on disk by calling This_Block.block_count
- Sets prev_offset to be the value of the offset of the lookahead buffer of t
- Takes the minimum of 256 and the number of blocks, divides the result by 4 and takes the maximum of the result and 16
- I.e., if there are more than 256 blocks on disk, allocation size is 64 blocks, else the allocation size is between 16 and 64 depending on the number of blocks
- If the sum of prev_offset and alloc_size is greater than or equal to the block count on disk then the current offset is set to 0, else it's set to the sum
- Creates a list of size alloc_size and populates the list with Int64 values corresponding to the list index + the current offset
- Converts the list to an Intset - pool
- Converts used_blocks to an Intset
- Takes the diff of pool and the used_blocks set, i.e. the block pointers in pool that are not in the set of used blocks
- Returns a list containing the elements in the resulting set after the diff
##### populate_lookahead ~except t
- except:int64 list -> t -> (int * int64 list, [> \`No_space]) result Lwt.t
- Calls Traverse.follow_links on t with an empty list and the root pair of the filesystem
- If this call results in an error, returns a \`No_space error
- Else, takes the resulting list used_blocks and calls unused on used_blocks appended to except
- I.e., gives a result with an int offset and a list of free block pointers apart from the ones specified in except - these are then used by the caller to update the values of t.lookahead
##### get_blocks t n : (int64 list, write_error) result Lwt.t
- t -> int -> (int64 list, write_error) result Lwt.t
- If n is less than or equal to 0, returns an empty list with an Ok result
- Calls aux on t and n with an empty list as the accumulator
###### get_block t
- t -> (int64, 'a) result Lwt.t
- Gets the list of block pointers in the lookahead buffer
- Takes the first index and updates the value of blocks to reflect this
- Returns an Ok result containing the block pointer
###### aux t acc n
- t -> int64 list -> int -> (int64 list, [> \`No_space ]) result Lwt.t
- Matches the block list in the buffer to multiple cases
- `if we have exactly enough blocks, just return the whole list`
- If the length of the buffer is equal to n, empties the lookahead buffer and returns its contents appended to acc
- `if we have enough in the lookahead buffer, just grab the first one n times`
- If the length of the buffer is greater than n:
	- Creates a list of indices from 0 to n-1
	- Uses this list to iterate from 0 to n-1
	- For each index i, checks if acc is now an error and returns an error in that case
	- Else, calls get_block t to get the first block in the lookahead buffer
	- If this results in an error, returns the error
	- Else, acc remains an Ok result and the block pointer is consed to its list
- `this is our sad case: not enough blocks in the lookahead allocator to satisfy the request. Claim the blocks that are there already, and try to get more; if the allocator can't give us any, give up`
- Else:
	- Calls populate_lookahead with except set to the current contents of the buffer appended to acc
	- If the result is an empty list, returns a \`No_space error
	- Else, updates the lookahead buffer with the resulting offset and blocks list
	- Appends the previous contents of the buffer to acc
	- Calls aux with n decremented by the length of the buffer before it was updated
##### get_block_pair t
- `[get_block_pair fs] wraps get_blocks fs 2 to return a pair for the caller's convenience`
- t -> (int64 * int64, [> \`No_space]) result Lwt.t
- calls get_blocks t 2
- If the output maps to a list of block pointers, returns an Ok result containing the first to elements
- If it returns anything else, returns a \`No_space error
#### module Find
##### entries_of_name t block_pair name
- t -> int64 * int64 -> string 9(((int64 * int64) * Chamelon.Entry.t list) list [> \`Not_found of key]) Lwt_result.t
- Gets a list of lists of uncompacted entries in the directory which starts in the most recent metadata block in block_pair by calling all_entries_in_dir on t and block_pair
- The resulting list of lists is split by block
- Calls entries_matching_names on each of these lists
- Uses List.filter_map on the result to create a list where:
	- For each directory pointer and uncompacted entry list pair, checks if the list is empty
	- If it is, append None to the list
	- Else, append the pair to the list
- Returns the directory pointer * entry list option list
###### entries_of_id entries key
- Chamelon.Entry list -> int -> Chamelon.Entry list
- Uses List.find_all to select the entries from the list whose id values match id
###### id_of_key entries key
- Chamelon.Entry list -> string -> int option
- data_matches converts a cstruct c to a string and returns true if the resulting string matches key, else false
- tag_matches returns true if a tag t is a NAME tag else false
- Returns the id of the first entry in entries that has a NAME tag and whose associated filename matches key if it exists, else returns None
###### entries_matching_name (block, entries)
- Calls Chamelon.Entry.compact to compact the list of entries
- Calls id_of_key on the compacted entry list
- If no id is found, returns a \`No_id error
- Else, calls entries_of_id on this id to filter the entries with this id
- Compacts this list of entries and returns it along with block
##### find_first_blockpair_of_directory t block_pair key
- `[find_first_blockpair_of_directory t head l] finds and enters the segments in [l] recursively until none remain. It returns 'No_id if an entry is not present and 'No_structs if an entry is present, but does not represent a valid directory.` 
- t -> int64 * int64 -> string list -> [> \`Basename_on of int64 * int64 | \`No_id of string | \`No_structs] Lwt.t
- If the list of segments is empty, returns a \`Basename_on type containing the blockpair pointers
- Else, calls entries_of_name on the first segment in the list
- If the result is an error, or the list of lists of entries is empty, returns a \`No_id type containing the segment
- Else:
- `just look at the last entry with this name, and get the entries`
- Takes the last entry list from the result
- Uses List.filter_map with function Chamelon.Dir.of_entry l to get a list of directory pointers
- If the list is empty, returns a \`No_structs type
- Else, calls itself with head set to the first pointer pair in this list and key set to the rest of the segments
#### module File_read
- type specifications for get and get_partial functions
##### get_ctz t key (pointer, file_size)
- t -> 'a -> int64 * int -> (string, [> \`Not_found of 'a]) result Lwt.t
- last_block_index is used to get the index of the last block that the file is stored in
- read_block is called with an empty list, reading the file data into this list
- The list is concatenated and trimmed to length file_size
- Converts the file data into a string and returns an Ok result containing this string
###### read_block l index pointer
- int -> int64 -> (Cstruct.t list, This_Block.error) result Lwt.t
- Calls This_Block.read on the block device at block number pointer to read t.block_size bytes into cstruct data
- If this results in an error, returns the error
- Else, calls Chamelon.File.of_block on index and data to separate the pointers and data region of the block
- Uses Cstruct.sub on data to get the portion of data containing the block pointers
- Conses data_region to l 
- If pointers is empty, returns an Ok result containing l
- Else, calls itself with the index decremented by 1 and pointer set to the head of the pointer list
##### get_value t parent_dir_head filename
- t -> directory_head -> string -> ([> \`Ctz of int64 * int | \`Inline of string], [> \`Not_found of string | \`Value_expected of string]) result
- Calls Find.entries_of_name on filename to get the list of directory pointers and their entries which correspond to this filename
- If error or empty list is returned then returns \`Not_found error
- Else, reverses the list and takes the second element of the first pair to get the last set of entries from this list
- Calls List.find_opt to find an entry in this list with either an INLINE or a CTZ tag
- If an INLINE tag is found, returns an Ok result containing an \`Inline type with the inline file data
- If a neither tag type is identified, tries to find a DIR tag in the list of entries
- Returns a \`Value_expected error if it matches, and a \`Not_found error otherwise
- Else (must be a CTZ tag), calls File.ctz_of_cstruct on the entry data
- If the result matches to a pointer and a file size, returns an Ok result containing a \`Ctz type with the pointer and file size
- Else, returns a \`Value_expected error
##### get t key : (string, error) result Lwt.t
- t -> key -> (string, error) result Lwt.t
- Splits a key into a list of its segments
- If the list is empty, returns a \`Value_expected error containing the key
- If the list only has one value (the filename), calls get_value on the filename with the root pair as the parent directory, passing the value to map_result
- Else (is a directory), gets the segment list and removes the last segment to get the parent directory - dirname
- calls Find.find_first_blockpair_of_directory on dirname to get the directory pointers at the base of this key, i.e. the directory in which the file is stored
- If this returns a \`Basename_on type with the pointers, calls get_value on the directory pointers and the filename and passes the result to map_result
- Else, returns a \`Not_found error containing the key
###### map_result
- ([< \`Ctz of int64 * int | \`Inline of string ],  [< \`Not_found of string | \`Value_expected of string ])  result ->  (string, [> \`Not_found of key | \`Value_expected of key ]) result Lwt.t
- Matches a result type to an action
- If the result is an Ok result containing an \`Inline type, returns an Ok result containing the inline file data
- If the result is an Ok result containing a \`Ctz type, calls get_ctz on the pointer and file size
- The \`Not_found and \`Value_expected errors are returned with their strings converted to the Mirage_kv.Key type
#####  address_of_index t ~desired_index (pointer, index)
- t -> desired_index:int -> int64 * int -> (int64, [> \`Not_found of key]) result Lwt.t
- If the current index matches desired_index, returns an Ok result containing the pointer associated with the current index
- Creates a cstruct data of size t.block_size
- Calls This_block.read to read the data at disk from block number pointer to data
- If this returns an error, returns a \`Not_found error containing an empty Mirage_kv.Key
- Else, gets the pointer region of the block by calling Chamelon.File.of_block
- `worst case: we want an index that's between our index and (our index / 2), so we can't jump to it (or this index isn't a multiple of 2, so we only have one link); we just have to iterate backward until we get there`
- If desired_index is greater than half the current index, or there is no more than one pointer stored in this block, tries to identify the pointer in this list
- If there is no match, returns a \`Not_found error containing an empty Mirage_kv.Key
- Else, calls itself on the pointer with index decremented by 1
- Else (desired_index <= index / 2 and there are at least two pointers stored), tries to identify the pointer to block with index = index / 2
- If this there is no match, returns a \`Not_found error containing an empty Mirage_kv.Key
- Else, calls itself on the pointer to index / 2 with index = index / 2
##### get_ctz_partial t key ~offset ~length (pointer, file_size)
- t -> key -> offset:int -> length:int -> int64 * int -> (string, [> \`Not_found of key]) result Lwt.t
- Takes the value of last_byte to be the minimum of the file size and the offset + length
- Calls Chamelon.File.last_block_index on the file size to get the last block index where this file is stored (last_overall_block_index)
- Calls Chamelon.File.last_block_index on last_byte to get index of the block containing the start of the slice of the file to be read (last_byte_of_interest_index)
- Calls address_of_index with desired_index set to last_byte_of_index, pointer set to pointer (which points to the last block index) and index set to last_overall_block_index to get the pointer to the block containing the last byte to be read
- If this results in an error, returns the error
- Else, calls Chamelon.File.last_block_index on offset to get the index of the block containing the end of the slice of the file to be read (offset_index)
- Calls read_raw_blocks on offset_index with an empty list, starting at last_byte_of_interest_index and its associated pointer, last_byte_of_interest_pointer
- If this returns an error, returns a \`Not_found error containing key
- Else, if this returns an empty list, returns an Ok result containing an empty string
- `since our list is just the raw block contents of the relevant bit of the file, we probably need to drop some bytes from the beginning in order to correctly return the file starting at the right offset`
- Else, calls Chamelon.File.first_byte_on_index on offset_index to get the number of bytes of the file at the start of this block index (first_block_offset)
- `this calculation is correct *if* we correctly identified the first block associated with this offset. Otherwise it's wrong garbage nonsense, so let's hope we got that first block correct :sweat_smile:`
- Subtracts offset by first_block_offset and shifts the cstruct view of the first block in the list by this number of bytes
- Concatenates the shifted cstruct and the rest of the cstructs in the list, then converts the resulting cstruct to a string
- `we need to trim the results to either: (1) the requested length, if offset + length is < file_size (2) the file size minus the offset, if offset + length is > file_size`
- Sets final_length as described above and returns an Ok result containing a substring of the converted cstruct of length final_length
- This function reads a region of a CTZ file from offset bytes to (offset + length) bytes
###### read_raw_blocks ~offset_index l index pointer
- offset_index:int -> Cstruct.t list -> int -> int64 -> (Cstruct.t list, This_Block.error) result Lwt.t
- Creates a cstruct data of size t.block_size
- Calls This_Block.read to read the data on disk at pointer into data
- If this results in an error, returns the error
- Else, gets the pointer list and data region by calling Chamelon.File.of_block on data with index
- Creates an accumulator accumulated_data, the value of which is the data region consed to l
- If index <= offset_index () returns an Ok result containing accumulated_data
- Else, checks the pointer list
- If it is empty, returns an Ok result containing accumulated_data
- Else, calls read_raw_blocks with l set to accumulated_data, index decremented by 1, and pointer set to the head of the pointer list
##### get_partial t key ~offset ~length : (string, error) result Lwt.t
- t -> key -> offset:int -> length:int -> (string, error) result Lwt.t
- If the offset is negative, returns a \`Not_found error containing key
- If the length is <= 0, returns a \`Not_found error containing key
- Else, splits the key into its segments
- If the segment list is empty, returns a \`Value_expected error containing the key
- If the list only has one value (the filename), calls get_value on the filename with the root pair as the parent directory, passing the value to map_result
- Else (is a directory), gets the segment list and removes the last segment to get the parent directory - dirname
- calls Find.find_first_blockpair_of_directory on dirname to get the directory pointers at the base of this key, i.e. the directory in which the file is stored
- If this returns a \`Basename_on type with the pointers, calls get_value on the directory pointers and the filename and passes the result to map_result
- Else, returns a \`Not_found error containing the key
###### map_result
- ([< \`Ctz of int64 * int | \`Inline of string ],  [< \`Not_found of string | \`Value_expected of string ])  result ->  (string, [> \`Not_found of key | \`Value_expected of key ]) result Lwt.t
- Matches a result type to an action
- If the result is an Ok result containing an \`Inline type:
	- Tries to return an Ok result containing a slice of the inline file data from offset to the minimum of (offset + length) and (inline file length - offset)
	- If this results in an Invalid_argument exception, returns a \`Not_found error containing the key
- If the result is an Ok result containing a \`Ctz type, calls get_ctz_partial
- The \`Not_found and \`Value_expected errors are returned with their strings converted to the Mirage_kv.Key type
#### module File_write
- `[set_in_drectory directory_head t filename data] creates entries in [directory] for [filename] pointing to [data]`
- type specification for set_in_directory function
##### write_ctz_block t blocks written index so_far data
- `write_ctz_block continues writing a CTZ 'data' to 't' from the block list 'blocks'.`
- t -> int64 list -> (int * int64) list -> int -> int -> string -> ((int * int64) list, [> \`No_space]) result Lwt.t
- `we purposely don't reverse the list because we're going to want the *last* block for inclusion in the ctz structure`
- If so_far is greater than or equal to the length of data, then return Ok result containing written (i.e. the entire string has been written)
- If blocks is an empty list, returns a \`No_space error
- Else, creates a cstruct of size t.block_size
- Calls Chamelon.File.n_pointers on index to get the size of the skip list at this index
- Multiplies the size by 8 to get the length of the list in the cstruct
- Sets data_length to the minimum of t.block_size minus the length of the list and the length of data minus so_far (i.e. if the rest of data will fit in this block, then that is the amount to write, otherwise write to the rest of this block)
- `the 0th item in the skip list is always (index - 1). Only exception is the last block in the list (the first block in the file), which has no skip list`
- If written is empty, do nothing
- `the first entry in the skip list should be for block _last_index, which is index - 1`
- Else, writes the pointer in the first (index, pointer) pair of written to the cstruct at offset 0 (i.e. 0th item/first entry in the skip list the pointer to the previous block, index-1)
- For the i<sup>th</sup> item in the skip list from i=1:
	- The destination index is set to the current index divided by 2<sup>i</sup>
	- The point index is set to the pointer associated with destination_block_index in written
	- The pointer is written to the cstruct at offset i * 8
- Copies data_length bytes of the string data starting from from offset so_far into the cstruct at offset skip_list_length, i.e. after the skip list
- Calls This_Block.write to write the cstruct to disk at block number pointer
- If this results in an error, returns a \`No_space error
- Else, calls write_ctz_block with the current (index, pointer) pair consed to written, index incremented by 1 and so_far incremented by data_length
##### write_ctz t data
- `Get the correct number of blocks to write 'data' as a CTZ, then write it.`
- t -> string -> ((int * int64) list, write_error) result Lwt.t
- Gets the length of the string data (which corresponds to the number of bytes in this file)
- Calls Chamelon.File.last_block_index on data_length to get the number of blocks needed to store this file minus 1
- Calls Allocate.get_blocks on t (a block device) with value last_block_index + 1 to get the required number of blocks
- If this results in an error, returns the error
- Else, calls write_ctz_block with blocks set to the resulting list of block pointers, written set to an empty list, index and so_far set to 0 and the string data
##### write_in_ctz dir block_pair t filename data entries
- `Find the correct directory structure in which to write the metadata entry for the CTZ pointer. Write the CTZ, then write the metadata.`
- int64 * int64 -> t -> string -> string -> Chamelon.Entry.t list -> (unit, write_error) result Lwt.t
- Calls Read.block_of_block_pair on dir_block_pair to get the most recent version of the metadata block at these pointers (root)
- If this results in an error, returns a \`Not_found error containing filename as a key
- Else, if the block has a hardtail, calls write_in_ctz with dir_block_pair set to the hardtail entry
- Else, gets the length of the string data (which corresponds to the number of bytes in this file)
- Calls write_ctz on data
- If this results in an error, returns the error
- If this results in an Ok result containing an empty list, returns a \`No_space error
- `the file has been written; find an ID and write the appropriate metadata`
- Else (Ok result containing a list of (index, pointer) pairs that have been written to), finds the largest id stored in root
- If this results in None, sets next to 1, else sets next to n+1 where n is the largest id
- Calls Chamelon.File.name to create a NAME tag and entry for filename
- Calls Chamelon.Entry.ctime on next to create a USERATTR tag and entry for the file creation time (by calling Clock.now_d_ps)
- Calls Chamelon.File.create_ctz to create a CTZ tag and entry containing the pointer to the last block in the file and the file size
- Appends these entries to entries
- Calls Chamelon.Block.add_commit on root with the appended list
- Calls Write.block_to_block pair to write the new block at the addresses in dir_block_pair
- If this results in a \`No_space error, returns a \`No_space error
- If this results in any other error, returns a \`Not_found error containing filename as a key
- Else, returns an Ok result
