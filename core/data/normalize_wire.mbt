///|
// Normalize unpacked repeated primitives before invoking the pinned decoder.
fn normalize_wire(
  bytes : Bytes,
  kind : String,
  depth : Int32,
  fields_seen : Array[Int32],
) -> Bytes raise {
  guard depth <= 64 else { raise Invalid("protobuf nesting limit exceeded") }
  let b = @buffer.Buffer()
  let mut pos = 0
  while pos < bytes.length() {
    fields_seen[0] += 1
    guard fields_seen[0] <= 1000000 else {
      raise Invalid("protobuf field limit exceeded")
    }
    let start = pos
    let (tag, next) = varint(bytes, pos)
    pos = next
    let number = (tag >> 3).to_int()
    let wire = (tag & 7).to_int()
    let mut field = None
    for f in descriptor(kind) {
      if f.number == number {
        field = Some(f)
      }
    }
    let content_start = pos
    let len = match wire {
      0 => {
        let (_, next) = varint(bytes, pos)
        next - pos
      }
      1 => 8
      5 => 4
      2 => {
        let (len, next) = varint(bytes, pos)
        pos = next
        guard len <= (bytes.length() - pos).to_uint64() else {
          raise Invalid("truncated protobuf")
        }
        len.to_int()
      }
      _ => raise Invalid("invalid wire type")
    }
    guard len <= bytes.length() - pos else {
      raise Invalid("truncated protobuf")
    }
    let end = pos + len
    if field is Some(f) && wire == 2 && !descriptor(f.kind).is_empty() {
      let nested = normalize_wire(
        bytes[pos:end].to_owned(),
        f.kind,
        depth + 1,
        fields_seen,
      )
      @protobuf.write_uint64(b, tag)
      @protobuf.write_bytes(b, nested)
    } else if field is Some(f) &&
      (
        (wire == 1 && (f.kind == "packed64" || f.kind == "packedDouble")) ||
        (wire == 0 && f.kind == "packedUInt")
      ) {
      @protobuf.write_uint32(b, ((number << 3) + 2).reinterpret_as_uint())
      @protobuf.write_bytes(b, bytes[content_start:end].to_owned())
    } else {
      b.write_bytes(bytes[start:end].to_owned())
    }
    pos = end
  }
  b.to_bytes()
}
