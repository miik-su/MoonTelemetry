///|
pub(all) struct Limits {
  max_records_per_request : Int32
  max_attributes_per_record : Int32
  max_total_fields_per_request : Int32
  max_nesting_depth : Int32
}

///|
pub fn Limits::default() -> Limits {
  {
    max_records_per_request: 100000,
    max_attributes_per_record: 256,
    max_total_fields_per_request: 1000000,
    max_nesting_depth: 64,
  }
}
