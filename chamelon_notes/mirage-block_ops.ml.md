`Provide an intermediate interface that implements block operations on top of the sector-based API provided by a Mirage_block.S implementer.
### module Make(Sectors : Mirage_block.S)
- Include all of the definitions in Mirage_block.S
- Type specifications for connect and block_count functions
#### type t
- Type representing the internal state of the block device
- Record containing sectors, sector size, number of sectors and block size
#### sector_of_block t n
- t -> int64 -> int64
- byte_of_n gets the size of n blocks in bytes
- This is divided by the number of sectors to get the sector index of block n
#### block_count t
- t -> int
- Returns the number of sectors * (sector size / block size) to get the number of blocks
#### connect ~block_size sectors
- block_size:int -> Sectors.t -> Lwt.t
- Queries the characteristics of the block device sectors and returns type t with the provided characteristics
- Lwt used for concurrent programming
#### write t block_number
- t -> int64 -> Cstruct.t list -> (unit, write_error) result Lwt.t
- sector_of_block converts a block index for a given t to a sector index
##### Sectors.write
- Writes data from cstruct list buffer onto the block device starting at the given sector index
#### read t block_number
- t -> int64 -> Cstruct.t list -> (unit, error) result Lwt.t
- sector_of_block converts a block index for a given t to a sector index
##### Sectors.read
- Reads data from the sector of t starting from the sector index into a cstruct list buffer
