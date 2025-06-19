// DO NOT EDIT!

///|
pub fn wasmExportRun() -> Int {
  let result : Result[Unit, Unit] = run()
  let lowered = match result {
    Ok(_payload) => 0
    Err(_payload2) => 1
  }
  return lowered
}

///|
pub fn cabi_realloc(
  src_offset : Int,
  src_size : Int,
  dst_alignment : Int,
  dst_size : Int
) -> Int {
  @ffi.cabi_realloc(src_offset, src_size, dst_alignment, dst_size)
}
