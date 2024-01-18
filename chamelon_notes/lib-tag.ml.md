`tags are the only thing in littlefs stored in big-endian.`
`be careful when editing to remember this :)`
### type abstract_type
- LFS_TYPE_NAME [@id 0x0] ` associates IDs with file names and file types OR initializes them as files, directories, or superblocks `
- LFS_TYPE_STRUCT [@id 0x2] ` gives an id a structure (inline or CTZ) `
- LFS_TYPE_USERATTR [@id 0x3] ` 'user-defined', gross. "currently no standard user attributes" so we can just ignore them `
- LFS_TYPE_SPLICE [@id 0x4] ` create or delete file with a given ID depending on chunk info `
- LFS_TYPE_CRC [@id 0x5] ` CRC-32 for commits to the metadata block; polynomial of 0x04c11db7 initialized with 0xffffffff `
- LFS_TYPE_TAIL [@id 0x6] ` tail pointer for the metadata pair; hard or soft `
- LFS_TYPE_GSTATE [@id 0x7] ` global state entries; currently, only movestate `
- `data checksummed includes all metadata since previous CRC tag, including the CRC tag itself`
### type t
**(comments from littlefs/SPEC.md)**
- type representing the tag:
	- valid : bool `(1 bit) Indicates if the tag is valid. `
	- type3 : (abstract_type * Cstruct.uint8) `(11 bits) Type of the tag. This field is broken down further into a 3-bit abstract type and an 8-bit chunk field. Note that the value 0x000 is invalid and not assigned a type. `
		`i. Type1 (3-bits) - Abstract type of the tag. Groups the tags into 8 categories that facilitate bitmasked lookups.
		`ii. Chunk (8-bits) - Chunk field used for various purposes by the different abstract types. type1+chunk+id form a unique identifier for each tag in the metadata block.`
	- id : int `(10-bits) File id associated with the tag. Each file in a metadata block gets a unique id which is used to associate tags with that file. The special value 0x3ff is used for any tags that are not associated with a file, such as directory and global metadata.`
	- length : int ` (10-bits) Length of the data in bytes. The special value 0x3ff indicates that this tag has been deleted. `
### size = 4
`tags are always 32-bits, with internal numerical representations big-endian`
### xor ~into arg
- into:Cstruct.t -> Cstruct.t -> unit
- `it doesn't really need to be tags, it could be any 4-byte cstruct`
- Takes a 32-bit struct 'into' and splits it into four 8-bit regions
- XORs the 8-bit int stored in each region of 'into' with the 8-bit int stored in the corresponding region of the cstruct 'arg'
- The result of each xor is stored in the corresponding region of 'into'
### delete id
- int -> t
- creates a SPLICE tag with length 0 and the given id
### of_cstruct ~xor_tag_with cs
- xor_tag_with:Cstruct.t -> Cstruct.t -> (t, [> \`Msg of string ]) result
- Truncates the cstruct cs to 32-bits to get the tag region
- Checks if the tag belongs to one of the special invalid tags
- Calls xor on cs with xor_tag_with and checks if the result is a special invalid tag
- Casts the 32-bit tag in cs to an int
- Uses bitmasking to get the tag attributes from this int, i.e.:
	- get the abstract type by ANDing the leading 4 bits of r with 0111
	- get the chunk by ANDing the leading 12 bits of r with 000011111111
	- get the id by ANDing the leading 22 bits of r with 0000000000001111111111
	- get the length by ANDing r with 00000000000000000000001111111111
-  If the abstract type evaluates to None, returns an Error
- Else, combines the abstract_type and chunk into type3 and returns result containing Ok and the tag attributes
### into_cstruct_raw cs t
- Cstruct.t -> t -> unit
- ANDs both the id and the length fields of the tag with 001111111111
- `most significant bit (31): valid or no?`
- `this is inverted from what we'd expect the value to be --`
- `the spec isn't as explicit about this as I would be if I were writing something where 1 was no and 0 was yes :/`
- Sets the MSB of the first byte of the cstruct to 0 if the tag is valid and 1 otherwise
- `bits 30, 29, and 28: abstract type`
- ANDs the int value of the abstract type with 0111, shifts it 4 bits to the left and ORs it with the first byte
- `bits 27, 26, 25, 24 : first nibble of chunk`
- masks the lower 4 bits of the chunk by ANDing the chunk with 11110000
- ORs the result with the first byte
- Writes the first byte to the cstruct
- `bits 23, 22, 21, 20 : second nibble of chunk`
- ANDs chunk with 00001111, masking the upper 4 bits of the chunk and shifts the result 4 bits to the left
- `bits 19, 18, 17, 16 : most significant 4 bits of id`
- Then ANDs id with 001111000000 to get the upper 4 bits of id and shifts it 6 bits to the left
- ORs the two results above to get the second byte, which is written to the cstruct
- `bits 15, 14, 13, 12, 11, 10 : least significant 6 bits of id`
- ANDs 000000111111 with id to get the lower 6 bits of id and shifts the result two bits to the left
- `bits 9, 8: most significant two bits of length`
- ANDs 001100000000 with length to get the upper 2 bits of length and shifts the result 8 bits to the right
- ORs the two results above to get the third byte, which is written to the cstruct
- `bits 7, 6, 5, 4, 3, 2, 1, 0 : least significant 8 bits of length`
- ANDs 11111111 with length to get the lower 8 bits of length and writes the result to the cstruct
### into_cstruct ~xor_tag_with cs t
- xor_tag_with:Cstruct.t -> t -> Cstruct.t
- calls into_cstruct_raw on cs and t, then calls xor on cs and xor_tag_with