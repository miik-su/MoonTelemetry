///|
pub fn Envelope::wire_size(self : Envelope) -> Int64 {
  match self {
    Future(_, bytes, _) => bytes.length().to_int64()
    Logs(x) => @protobuf.Sized::size_of(x).to_int64()
    Metrics(x) => @protobuf.Sized::size_of(x).to_int64()
    Traces(x) => @protobuf.Sized::size_of(x).to_int64()
  }
}
