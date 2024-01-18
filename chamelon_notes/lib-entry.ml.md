### type t = Tag.t * Cstruct.t
### type link = | Metadata of (int64 * int64) | Data of (int64 * int64)
### sizeof t
- 'a * Cstruct.t -> int
- finds the length of the cstruct and adds it to the size of the tag (which is always 4 as tags are always 32 bits)
### info_of_entry (tag, data)
- Tag.t * Cstruct.t -> (string * [> \`Dictionary | \`Value]) option
- If the tag matches to the NAME type and its file type is an inline file, then an option is returned with the name converted to a string along with the \`Value type
- If the tag matches to the NAME type and its file type is a CTZ file, then an option is returned with the name converted to a string along with the \`Dictionary type
- Else, returns None
### ctime id (d, ps)
- int -> int * int64 -> Tag.t * Cstruct.t
- `` [ctime id d,ps] returns a creation time entry for [id] at [d,ps]``
- Creates a 12-byte cstruct in which the first 4 bytes are set to d and the latter 8 bytes are set to ps
- Creates a USERATTR tag of length 12 bytes and returns it along with the cstruct
### ctime_of_cstruct
- Cstruct.t -> (int * int64) option
- Returns none if the given cstruct is less than 12 bytes
- Otherwise, gets d and ps from the cstruct and returns an option with (d, ps)
### into_cstruct ~xor_tag_with cs t
- xor_tag_with:Cstruct.t -> Cstruct.t -> Tag.t * Cstruct.t -> unit
- calls Tag.into_cstruct on the arguments, taking the tag from t
- copies the contents of the cstruct containing d, ps to cs so that they are stored after the tag