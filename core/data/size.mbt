///|
pub fn Envelope::wire_size(self : Envelope) -> Int64 {
  match self {
    Future(_, bytes, _) => bytes.length().to_int64()
    Logs(x) => @protobuf.Sized::size_of(x).to_int64()
    // Conservative correction for zigzag fields and parent length prefixes.
    Metrics(x) =>
      @protobuf.Sized::size_of(x).to_int64() +
      self.count().to_int64() * 32L +
      128L
    Traces(x) => @protobuf.Sized::size_of(x).to_int64()
  }
}
