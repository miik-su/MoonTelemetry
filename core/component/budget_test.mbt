///|
test "failed reservation is atomic and release restores capacity" {
  let b = @component.MemoryBudget::new(100L)
  assert_true(b.reserve(80L))
  assert_false(b.reserve(21L))
  assert_eq(b.used(), 80L)
  b.release(80L)
  assert_eq(b.available(), 100L)
}
