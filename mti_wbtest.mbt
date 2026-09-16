///|
test "MTI parsing names all four digits" {
  let parsed = parse_mti("0200").unwrap()
  assert_eq(parsed.version, Iso1987)
  assert_eq(parsed.message_class, Financial)
  assert_eq(parsed.function, Request)
  assert_eq(parsed.origin, Acquirer)
  assert_true(parsed.is_request())
  assert_true(parsed.is_transaction())
}

///|
test "MTI response repeat and reversal derivation" {
  assert_eq(response_mti("0200").unwrap(), "0210")
  assert_eq(repeat_mti("0200").unwrap(), "0201")
  assert_eq(reversal_mti("0200").unwrap(), "0400")
  assert_eq(response_mti("0420").unwrap(), "0430")
}

///|
test "reserved MTI digits remain inspectable" {
  let parsed = parse_mti("6709").unwrap()
  assert_eq(parsed.version, ReservedVersion(6))
  assert_eq(parsed.message_class, FeeCollection)
  assert_eq(parsed.function, Request)
  assert_eq(parsed.origin, OtherOrigin(9))
}
