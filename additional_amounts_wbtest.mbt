///|
test "DE54 parses and formats multiple additional amounts" {
  let ledger = additional_amount("00", "01", "156", false, 12345L).unwrap()
  let available = additional_amount("00", "02", "156", true, 234L).unwrap()
  let text = format_additional_amounts([ledger, available])
  assert_eq(text.length(), 40)
  let decoded = parse_additional_amounts(text).unwrap()
  assert_eq(decoded.length(), 2)
  assert_eq(decoded[0].kind(), LedgerBalance)
  assert_eq(decoded[1].kind(), AvailableBalance)
  assert_eq(decoded[0].display().unwrap(), "CNY 123.45")
  assert_eq(decoded[1].display().unwrap(), "CNY -2.34")
}

///|
test "DE54 signed amounts retain debit and credit direction" {
  let credit = parse_additional_amount_component("0001156C000000001234").unwrap()
  let debit = parse_additional_amount_component("0002156D000000000050").unwrap()
  assert_eq(credit.signed_minor_units(), 1234L)
  assert_eq(debit.signed_minor_units(), -50L)
  assert_eq(find_additional_amount([credit, debit], "02"), Some(debit))
}

///|
test "DE54 rejects malformed component boundaries" {
  match parse_additional_amounts("0001156C00000000123") {
    Err(InvalidAmount(_)) => ()
    _ => fail("expected invalid amount")
  }
  match parse_additional_amount_component("0001156X000000001234") {
    Err(InvalidAmount(_)) => ()
    _ => fail("expected invalid sign")
  }
}
