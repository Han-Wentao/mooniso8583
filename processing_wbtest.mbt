///|
test "processing code exposes transaction and account meaning" {
  let code = parse_processing_code("002000").unwrap()
  assert_eq(code.transaction(), GoodsAndServices)
  assert_eq(code.source_account(), Checking)
  assert_eq(code.destination_account(), DefaultAccount)
  assert_eq(processing_code("40", "10", "20").unwrap(), "401020")
}

///|
test "minor-unit amount formatting avoids floating point" {
  let amount = parse_minor_amount(4, "000000001234", 12, 2).unwrap()
  assert_eq(amount.minor_units, 1234L)
  assert_eq(amount.display(), "12.34")
  assert_eq(format_minor_amount(1234L, 12).unwrap(), "000000001234")
}

///|
test "currency metadata renders transaction amount" {
  let cny = parse_currency("156").unwrap()
  assert_eq(cny.alpha, Some("CNY"))
  assert_eq(cny.minor_units, Some(2))
  assert_eq(
    describe_transaction_amount("000000001234", "156").unwrap(),
    "CNY 12.34",
  )
  assert_eq(
    describe_transaction_amount("000000001234", "392").unwrap(),
    "JPY 1234",
  )
}
