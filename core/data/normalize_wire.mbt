///|
// Normalize unpacked repeated primitives before invoking the pinned decoder.
fn normalize_wire(
  bytes : BytesView,
  kind : String,
  depth : Int32,
  fields_seen : Array[Int32],
  limits~ : Limits = Limits::default(),
) -> Bytes raise {
  guard depth <= limits.max_nesting_depth else {
    raise Invalid("protobuf nesting limit exceeded")
  }
  let b = @buffer.Buffer()
  let mut pos = 0
  while pos < bytes.length() {
    fields_seen[0] += 1
    guard fields_seen[0] <= limits.max_total_fields_per_request else {
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
    if wire == 0 &&
      field is Some(f) &&
      enum_limit(f.name) >= 0 &&
      fields_seen.length() > 1 {
      let (value, _) = varint(bytes, pos)
      if value > enum_limit(f.name).to_uint64() {
        fields_seen[1] += 1
      }
    }
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
        bytes[pos:end],
        f.kind,
        depth + 1,
        fields_seen,
        limits~,
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
      b.write_bytes(bytes[start:end])
    }
    pos = end
  }
  b.to_bytes()
}
