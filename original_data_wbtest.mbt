///|
test "DE90 round trip preserves original identifiers" {
  let data = original_data("0200", "123456", "0916123456", "123456", "987654").unwrap()
  let wire = data.to_string()
  assert_eq(wire.length(), 42)
  let decoded = parse_original_data(wire).unwrap()
  assert_eq(decoded.original_mti, "0200")
  assert_eq(decoded.acquiring_institution_id, "00000123456")
  assert_eq(decoded.forwarding_institution_id, "00000987654")
}

///|
test "DE90 derives from and matches an original transaction" {
  let original = message("0200").unwrap()
  original.set_field(7, "0916123456").unwrap()
  original.set_field(11, "123456").unwrap()
  original.set_field(32, "123456").unwrap()
  let data = original_data_from_message(original).unwrap()
  assert_true(data.matches(original))
  let reversal = message("0400").unwrap()
  attach_original_data(reversal, original).unwrap()
  assert_eq(reversal.field(90), Some(data.to_string()))
}

///|
test "DE90 validates date and required source fields" {
  match parse_original_data("020012345613321234560000012345600000000000") {
    Err(InvalidOriginalData(_)) => ()
    _ => fail("expected invalid date")
  }
  let original = message("0200").unwrap()
  match original_data_from_message(original) {
    Err(MissingField(11)) => ()
    _ => fail("expected STAN requirement")
  }
}
