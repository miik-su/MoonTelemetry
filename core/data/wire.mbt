///|
// Preflight lengths before entering the generated decoder. Its top-level reader
// treats EOF in a field as end-of-message, so truncated input needs this guard.
pub fn validate_wire(bytes : Bytes) -> Unit raise DataError {
  let mut pos = 0
  while pos < bytes.length() {
    let (tag, next) = varint(bytes, pos)
    pos = next
    guard tag >> 3 != 0 else { raise Invalid("protobuf field number zero") }
    let len = match tag & 7 {
      0 => {
        let (_, next) = varint(bytes, pos)
        pos = next
        0
      }
      1 => 8
      2 => {
        let (length, next) = varint(bytes, pos)
        pos = next
        guard length <= (bytes.length() - pos).to_uint64() else {
          raise Invalid("truncated protobuf field")
        }
        length.to_int()
      }
      5 => 4
      _ => raise Invalid("unsupported protobuf wire type")
    }
    guard len <= bytes.length() - pos else {
      raise Invalid("truncated protobuf field")
    }
    pos += len
  }
}

///|
fn varint(bytes : Bytes, start : Int32) -> (UInt64, Int32) raise DataError {
  for i = 0, value = 0UL; i < 10; {
    guard start + i < bytes.length() else {
      raise Invalid("truncated protobuf varint")
    }
    let b = bytes[start + i].to_int()
    guard i != 9 || b <= 1 else { raise Invalid("protobuf varint overflow") }
    let value = value | ((b & 127).to_uint64() << (7 * i))
    if b < 128 {
      return (value, start + i + 1)
    }
    continue i + 1, value
  } nobreak {
    raise Invalid("protobuf varint overflow")
  }
}
