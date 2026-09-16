///|
test "data kind validation reports exact offset" {
  match validate_numeric_text(4, "12A4") {
    Err(InvalidCharacter(4, 2, "numeric")) => ()
    _ => fail("expected numeric character error")
  }
  validate_alphanumeric_text(41, "TERM-01", true).unwrap()
  validate_printable_text(48, "key=value").unwrap()
}

///|
test "fixed numeric fields canonicalize with zero padding" {
  let spec = fixed_numeric(4, "Amount", 12)
  assert_eq(canonical_field_value(spec, "1234").unwrap(), "000000001234")
  match canonical_field_value(spec, "1234567890123") {
    Err(FieldTooLong(4, 12, 13)) => ()
    _ => fail("expected field too long")
  }
}

///|
test "binary logical length counts decoded bytes" {
  let spec = binary_hex(55, "ICC data", 255, true)
  assert_eq(field_logical_length(spec, "9F0206000000000100"), 9)
  assert_eq(field_max_logical_length(spec), 255)
  validate_binary_hex_text(55, "9F0206000000000100").unwrap()
}

///|
test "message validation collects independent field failures" {
  let specs = [
    fixed_numeric(3, "Processing code", 6),
    fixed_numeric(4, "Amount", 12),
  ]
  let pkg = packager("mini", specs).unwrap()
  let msg = message("0200").unwrap()
  msg.set_field(3, "00X000").unwrap()
  msg.set_field(99, "unexpected").unwrap()
  let issues = validate_message_fields(msg, pkg)
  assert_eq(issues.length(), 2)
  assert_false(fields_are_valid(msg, pkg))
}
