///|
test "message keeps fields sorted and replaces values" {
  let msg = message("0200").unwrap()
  msg.set_field(41, "TERM0001").unwrap()
  msg.set_field(3, "000000").unwrap()
  msg.set_field(11, "123456").unwrap()
  msg.set_field(11, "654321").unwrap()
  assert_eq(msg.field_numbers(), [3, 11, 41])
  assert_eq(msg.field(11), Some("654321"))
  assert_eq(msg.remove_field(3), true)
  assert_eq(msg.has_field(3), false)
}

///|
test "hex round trip uses uppercase canonical text" {
  let bytes = hex_decode("00a17Fff").unwrap()
  assert_eq(hex_encode(bytes), "00A17FFF")
}

///|
test "packager rejects duplicate definitions" {
  let one = fixed_numeric(3, "Processing code", 6)
  match packager("bad", [one, one]) {
    Err(DuplicateField(3)) => ()
    _ => fail("expected duplicate field error")
  }
}

///|
test "stable errors expose code and message" {
  let error = FieldTooLong(2, 19, 20)
  assert_eq(error.code(), "ISO015")
  assert_true(error.message().contains("maximum length"))
}
