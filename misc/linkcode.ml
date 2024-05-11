(* need to find solution for inline files for this to work *)
  let link old_path new_path =
    fs_connect () >>= fun t ->
      let create_hardlink file_type to_pair dir_pair =
        Fs.Find.find_first_blockpair_of_directory t dir_pair Mirage_kv.Key.(segments @@ v new_path) >>=  function (* find parent directory to create new hardlink in*)
        | `Basename_on new_path_parent ->
          let entry = 
            if file_type = 0x00 then Chamelon.Dir.mkdir ~to_pair 1 
            else if file_type = 0x01 then Chamelon.File.write_inline in
          Fs.Write.block_to_block_pair t (Chamelon.Block.of_entries ~revision_count:1 [entry]) new_path_parent >>= (function
          | Ok () -> Lwt.return @@ Ok ()
          | Error _ -> Lwt.return @@ Error `No_space)
        | _ -> Lwt.return @@ Error `Not_found in
      Fs.Find.find_first_blockpair_of_directory t root_pair Mirage_kv.Key.(segments @@ v old_path) >>= function
      | `Basename_on pair -> (Fs.Find.entries_of_name t pair old_path >>= function
        | Ok compacted -> 
          let entries = snd List.(hd @@ rev compacted) in
          let struct_match n =  List.find_opt (fun (tag, _data) ->
            Chamelon.Tag.((fst tag.type3) = LFS_TYPE_STRUCT) &&
            Chamelon.Tag.((snd tag.type3) = n)) in
          (match struct_match 0x00 entries with
          | None -> 
            begin 
              match struct_match 0x01 entries, struct_match 0x02 entries with
              | None, None -> Lwt.return @@ Error `Not_found
              | Some (tag, _data), None ->
              | None, Some (_tag, data) ->
            end
          | Some (_tag, data) -> 
            match Chamelon.Dir.dirstruct_of_cstruct data with
            | None -> Lwt.return @@ Error `Not_found
            | Some to_pair -> create_hardlink to_pair root_pair >>= function
              | Ok _ -> Lwt.return @@ Ok ()
              | Error `Not_found -> Fs.mkdir t root_pair Mirage_kv.Key.(segments @@ parent @@ v new_path) >>= (function
                | Ok dir_pair -> create_hardlink to_pair dir_pair
                | Error _ -> Lwt.return @@ Error `No_space)
              | Error _ -> Lwt.return @@ Error `No_space)
        | _ -> Lwt.return @@ Error `Not_found)
      | `No_id _ | `No_structs -> Lwt.return @@ Error `Not_found
