///|
test "PAN validation and masking" {
  let pan = parse_pan("6222021234567894").unwrap()
  assert_eq(pan.length, 16)
  assert_eq(pan.issuer_prefix, "622202")
  assert_eq(pan.masked, "622202******7894")
  assert_true(pan_luhn_valid("6222021234567894"))
  assert_false(pan_luhn_valid("6222021234567891"))
}

///|
test "Track 2 parses structured payment data" {
  let track = parse_track2("6222021234567894=25121234567890").unwrap()
  assert_eq(track.expiration, "2512")
  assert_eq(track.service_code, "123")
  assert_eq(track.discretionary, "4567890")
  assert_eq(track.to_string(), "6222021234567894=25121234567890")
  assert_eq(track.masked(), "622202******7894=25121234567890")
}

///|
test "Track 2 BCD round trip uses D separator and F padding" {
  let track = parse_track2("6222021234567894=25121234567890").unwrap()
  let encoded = track2_to_bcd(track).unwrap()
  let decoded = track2_from_bcd(encoded).unwrap()
  assert_eq(decoded.to_string(), "6222021234567894=25121234567890")
  assert_eq(hex_encode(encoded), "6222021234567894D25121234567890F")
}

///|
test "invalid PAN and Track 2 are rejected" {
  match parse_pan("123456789012") {
    Err(InvalidPan(_)) => ()
    _ => fail("expected invalid PAN")
  }
  match parse_track2("6222021234567894=25") {
    Err(InvalidTrack2(_)) => ()
    _ => fail("expected incomplete Track 2")
  }
}
