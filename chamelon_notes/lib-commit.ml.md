### type t
- type representing a commit:
	- entries : Entry.t list
	- seed_tag : Cstruct.t
	- last_tag : Cstruct.t
	- start_crc : Optint.t `either the default CRC or the CRC of the revision count (for the first commit in a block)
### let create starting_xor_tag preceding_crc
- Cstruct.t -> Optint.t -> t
- Creates a commit with an empty list of entries where the seed tag and the last tag are both set to starting_xor_tag, and the start crc is set to preceding_crc
### let addv t entries
- t -> Entry.t list -> t
- `unfortunately we need to serialize all the entries in order to get the crc`
- Calls Entry.to_cstructv and discards the serialized entry list to get its last tag
- Creates a new commit with the list of entries appended to the existing list where the seed tag is set to the existing last tag, the last tag is set to the last tag found in the previous step and the start_crc stays the same
### let commit_after {last_tag; \_} entries
- t -> Entry.t list -> t
- Calls Entry.to_cstructv to get the serialized entry list and its last tag
- `the crc for any entry that's after another one (any non-first entry on a block) doesn't depend on the revision count, so its calculation is more straightforward`
- Creates a default CRC-32 checksum
- `we get the final result whther we do a lognot on this or, uh, not, which indicates to me that maybe we're not actually using this value`
- Creates a new commit with the same entries and seed tag, the last tag set to the last tag found above and the default checksum
### of_entries_filter_crc starting_xor_tag preceding_crc entries
- Cstruct.t -> Optint.t -> Entry.t list -> t
- `we don't want to include the CRC tag in the read-back entry list, since we calculate that on write in our own code`
- Uses List.filter to get rid of any CRC entries in entries
- Calls create to make a commit with tag starting_xor_tag and start crc preceding_crc
- Passes this commit to addv along with entries

`serialization and deserialization`
### into_cstruct ~filter_hardtail ~starting_offset ~program_block_size ~starting_xor_tag ~next_commit_valid cs t
- `[into_cstruct cs t] writes [t] to [cs] starting at offset 0. It returns the raw (not XOR'd with the tag before it) value of the last tag of the commit as serialized (i.e., the CRC tag), for use in writing any commits that may follow [t].`
- `Unlike other modules the corresponding 'to_cstruct' function is not provided, because the caller is expected to be writing into a larger buffer as part of a block write of a set of commits.`
- filter_hardtail:bool -> starting_offset:int -> program_block_size:int -> starting_xor_tag:Cstruct.t -> next_commit_valid:bool -> Cstruct.t -> t -> int * Cstruct.t
- `we would like to be sure that we don't write any hardtail entries, since the block level will be handling that`
- If filter_hardtail is set to true then all hardtail tags are removed from entries using List.filter
- Calculates the size of the padding by finding the length of the commit and subtracting it from program_block_size
- `for a lot of future calculation, we'll need to know where writing the (non-CRC) entries into the buffer completed`
- Writes the commit into the buffer cs and gets a pointer to the final (CRC) entry in the commit along with the tag of the final non-CRC entry by calling Entry.into_cstructv on cs and entries
- Creates a new CRC tag where:
	- If next_commit_valid is set to true, the valid state bit in the CRC chunk is set to 0 (true) and 1 (false) otherwise
	- The length is increased by the length of the padding
- entry_region is the part of the cstruct with the non-CRC entries
- tag_region, crc_region and padding_region are the parts of the cstruct containing the CRC tag, the CRC-32 code and the padding
- `since the crc includes the tag for the crc itself, we need to write the tag before we can calculate the crc value for the buffer`
- Uses Tag.into_cstruct to xor the CRC tag with the final non-CRC tag and write it into a cstruct
- Uses Checkseum to create a CRC-32 from entry_region at offset 0 of length crc_tag_pointer (i.e. all of the data before the CRC tag) using start_crc
- `the crc in t is the crc of all the entries, so we can use that input to a crc calculation of the tag`
- Uses Checkseum to create a CRC-32 now including the final CRC tag, with seed_crc
- Writes the new CRC to crc_region
- `set the padding bytes to an obvious value`
- Sets all the bytes in padding_region to 1
- Returns the crc tag as a cstruct along with the number of bytes written subtracted by starting_offset
### of_cstructv ~starting_offset:_ ~program_block_size ~starting_xor_tag ~preceding_crc cs
- starting_offset:int -> program_block_size:'a -> starting_xor_tag:Cstruct.t -> preceding_crc:Optint.t -> Cstruct.t -> t list
- `we don't have a good way to know how many valid entries there are (since we filter out the CRC tags), so we have to keep trying for the whole block`
- Uses Entry.of_cstructv to get the list of entries, the crc tag and the number of bytes read from cs
- `'read' includes padding from CRC tags, so all reads after the first one should be aligned with the program block size`
- Calls of_entries_filter_crc on the list of entries with starting_xor_tag to get a commit with the crc entry removed
- If there is only one commit in cs, returns this commit consed to an empty list
- Else, shifts the view of cs by the amount of bytes read
- `only the first commit ever has a nonzero starting offset, so all our recursive calls should set it to 0`
- Returns this commit consed to the result of recursively calling of_cstructv on the shifted cs with preceding_crc set to the default value, starting_offset set to 0 and starting_xor_tag set to the crc tag