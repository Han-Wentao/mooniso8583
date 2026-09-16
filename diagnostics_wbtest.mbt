///|
fn sensitive_message() -> IsoMessage {
  let message = message("0200").unwrap()
  message.set_field(2, "6222021234567890").unwrap()
  message.set_field(3, "000000").unwrap()
  message.set_field(4, "000000001500").unwrap()
  message.set_field(35, "6222021234567890=29122011234567890").unwrap()
  message.set_field(41, "TERM0001").unwrap()
  message.set_field(52, "0011223344556677").unwrap()
  message.set_field(55, "9F260811223344556677889F270180").unwrap()
  message.set_field(64, "AABBCCDDEEFF0011").unwrap()
  message
}

///|
test "safe dump masks PAN track PIN chip data and MAC" {
  let message = sensitive_message()
  let dump = safe_message_dump(message, iso1987_packager())
  assert_true(dump.contains("622202******7890"))
  assert_true(dump.contains("REDACTED TRACK2"))
  assert_true(dump.contains("REDACTED PIN DATA"))
  assert_true(dump.contains("tags=[9F26,9F27]"))
  assert_true(dump.contains("REDACTED MAC"))
  assert_false(dump.contains("6222021234567890"))
  assert_false(dump.contains("0011223344556677"))
  assert_false(dump.contains("1122334455667788"))
  assert_false(dump.contains("AABBCCDDEEFF0011"))
}

///|
test "safe field display handles invalid sensitive values defensively" {
  assert_eq(safe_field_display(2, "not-a-pan"), "[REDACTED PAN len=9]")
  assert_eq(safe_field_display(35, "broken"), "[REDACTED TRACK2 len=6]")
  assert_eq(safe_field_display(45, "B622202"), "[REDACTED TRACK1 len=7]")
  assert_true(safe_field_display(55, "XYZ").contains("invalid-encoding"))
}

///|
test "structured diagnostics preserve public values and sensitivity metadata" {
  let message = sensitive_message()
  let fields = safe_field_diagnostics(message, iso1987_packager())
  let amount = fields[2]
  let pan = fields[0]
  assert_eq(amount.sensitivity, PublicField)
  assert_eq(amount.display, "000000001500")
  assert_eq(pan.sensitivity, MaskedAccountData)
  assert_eq(pan.display, "622202******7890")
}

///|
test "safe layout reports offsets without leaking values" {
  let message = sensitive_message()
  let dump = safe_layout_dump(
    message,
    iso1987_packager(),
    ascii_binary_profile(),
  ).unwrap()
  assert_true(dump.contains("bitmap offset="))
  assert_true(dump.contains("DE55 offset="))
  assert_false(dump.contains("1122334455667788"))
  assert_false(dump.contains("0011223344556677"))
}

///|
test "sensitive field inventory is deterministic" {
  let message = sensitive_message()
  assert_eq(sensitive_fields(message), [2, 35, 52, 55, 64])
  let dump = safe_message_dump(message, iso1987_packager())
  assert_false(diagnostic_contains_raw_value(dump, 2, "6222021234567890"))
  assert_true(
    diagnostic_contains_raw_value(
      "bad 6222021234567890 log", 2, "6222021234567890",
    ),
  )
  assert_false(diagnostic_contains_raw_value(dump, 4, "000000001500"))
}
