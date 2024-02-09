### type t = Tag.t * Cstruct.t
### type link = | Metadata of (int64 * int64) | Data of (int64 * int64)
### sizeof t
- 'a * Cstruct.t -> int
- Finds the length of the cstruct and adds it to the size of the tag (which is always 4 as tags are always 32 bits)
### info_of_entry (tag, data)
- Tag.t * Cstruct.t -> (string * [> \`Dictionary | \`Value]) option
- If the tag matches to the NAME type and its file type is an inline file, then an option is returned with the name converted to a string along with the \`Value type
- If the tag matches to the NAME type and its file type is a CTZ file, then an option is returned with the name converted to a string along with the \`Dictionary type
- Else, returns None
### ctime id (d, ps)
- int -> int * int64 -> Tag.t * Cstruct.t
- ``[ctime id d,ps] returns a creation time entry for [id] at [d,ps]``
- Creates a 12-byte cstruct in which the first 4 bytes are set to d and the latter 8 bytes are set to ps
- Creates a USERATTR tag of length 12 bytes and returns it along with the cstruct
### ctime_of_cstruct
- Cstruct.t -> (int * int64) option
- Returns none if the given cstruct is less than 12 bytes
- Otherwise, gets d and ps from the cstruct and returns an option with (d, ps)
### into_cstruct ~xor_tag_with cs t
- xor_tag_with:Cstruct.t -> Cstruct.t -> Tag.t * Cstruct.t -> unit
- Calls Tag.into_cstruct on xor_tag_with, cs and the tag in entry t
- Copies the contents of the tag's data region to the tag that has been converted to a cstruct
### links (tag, data)
- Tag.t * Cstruct.t -> link option
- Checks if the tag is a struct tag, i.e. directory, in-line or ctz:
	- If the tag is a directory tag, returns an option with a link containing a pointer to the first metadata pair in the directory
	- If the tag is a ctz tag, returns an option with a link containing the pointer to head of the skip list and the file size
	- If the tag is an inline tag, returns None
- If the tag is a hardtail, returns an option with a link containing a pointer to the next metadata pair in the directory
- Otherwise, returns None
- A link is either a pointer to a pair of metadata blocks (which can be directories) or a pointer and file size which uniquely identifies a file
### compact entries
- (Tag.t * 'a) list -> (Tag.t * 'a) list (i.e., t list -> t list)
- ``[compact l] checks to see whether [l] contains any deletion entries; if so, it removes the entries to be deleted and the corresponding deletion entry, and returns the resulting list. See littlefs documentation on compaction for more information.``
- If an entry in the list has a splice tag, remove_entries_matching is called with that tag's id and the list, otherwise the tag is appended to the list
- The above function is called on the existing list using List.fold_left to create a new list
#### remove_entries_matching id l
- int -> (Tag.t * 'a) list -> (Tag.t * 'a) list
- Uses List.filter_map which applies f to every element of a list and removes those which evaluate to None
- The function applied checks if the id of each tag in the list is equal to id, and returns None if they match
### lenv_less_hardtail l
- (Tag.t * Cstruct.t) list -> int
- `[lenv_less_hardtail l] gives the number of bytes necessary to store [l], not including any hardtail entries present in [l].`
- Uses List.fold_left to create a sum of the lengths of the entries where any valid hardtail tags are excluded from the sum
### into_cstructv ~starting_xor_tag cs l
- starting_xor_tag:Cstruct.t -> Cstruct.t -> (Tag.t * Cstruct.t) list -> int * Cstruct.t
- `currently this takes a 't list', and therefore is pretty straightforward. This function exists so we can do better once 't list' is replaced with more complicated`
- cs is a cstruct which should have a length at least equal to the sum of the lengths of the entries in l
- For each entry in l:
	- Converts the entry to a cstruct and XORs it with the previous tag by calling into_cstruct
	- Stores the cstruct in the region of cs starting at the current pointer
	- Converts the current tag to a cstruct and increments the pointer to cs by the size of the current entry
	- Incremented pointer and current tag cstruct passed to function for the next entry of the list
	- Initial values of the pointer and tag are 0 and starting_xor_tag
- Returns the pointer to the final (CRC) entry in cs and the tag of the final non-CRC entry in l
### to_cstructv ~starting_xor_tag l
- starting_xor_tag:Cstruct.t -> (Tag.t * Cstruct.t) list -> Cstruct.t * Cstruct.t
- ``TODO: this is also not quite right; in cases where we filter out a hardtail, we'll have a gap at the end of the cstruct``
- Creates a cstruct cs with size equal to the total length in bytes of the entries in l
- Calls into_cstructv on starting_xor_tag, cs and l
- Returns the last tag and cs
- Serialises a list of entries
### of_cstructv ~starting_xor_tag cs
- starting_xor_tag:Cstruct.t -> Cstruct.t -> (Tag.t * Cstruct.t) list * Cstruct.t * int
- ``[of_cstructv cs] returns [(l, t, s)] where [l] is the list of (tag, entry) pairs discovered preceding the next CRC entry. [t] the last tag (un-xor'd) for use in seeding future reads or writes. [s] the number of bytes read from [cs], including (if present and read) the CRC tag, data and any padding``
- Calls gather with an empty list, starting_xor_tag, 0 and cs
#### tag ~xor_tag_with cs
- xor_tag_with:Cstruct.t -> Cstruct.t -> (Tag.t * Cstruct.t) option
- First checks if cs is big enough to store a tag, and returns None if not
- Uses Tag.of_cstruct to xor the tag in cs with xor_tag_with and get the tag from cs
- Returns None if the call to Tag.of_cstruct returned Error
- If cs is big enough to store the data region associated with this tag, then truncates cs to the data region and returns the tag along with the data region, i.e. an Entry
- Else, returns None
#### gather (l, last_tag, s) cs
- (Tag.t * Cstruct.t) list * Cstruct.t * int ->  Cstruct.t -> (Tag.t * Cstruct.t) list * Cstruct.t * int
- Gets the entry in cs by calling tag with xor_tag_with=last_tag
- If this Returns none, returns l reversed along with last_tag and s
- Else, checks if the tag of this entry is a CRC tag
- If it matches, returns l reversed, this tag as a cstruct and s incremented by the size of the entry
- Else, calls gather with this entry added to the head of l, this tag as a cstruct, s incremented by the size of the entry and cs with its view shifted by the size of the entry
