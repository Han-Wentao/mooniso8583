///|
test "common ISO date and time fields parse strict ranges" {
  assert_eq(parse_transmission_datetime("0916235959").unwrap().month, 9)
  assert_eq(parse_local_transaction_time("235959").unwrap().second, 59)
  assert_eq(parse_local_transaction_date("0229").unwrap().day, 29)
  assert_eq(parse_card_expiration("2912").unwrap().year, 29)
  for value in ["1331235959", "0230235959", "0916240000", "0916236060"] {
    match parse_transmission_datetime(value) {
      Err(InvalidDateTime(_)) => ()
      _ => fail("invalid transmission time should fail: \{value}")
    }
  }
}

///|
test "expiration compares at month precision" {
  let expiry = parse_card_expiration("2912").unwrap()
  assert_false(expiry.expired_at(29, 12))
  assert_true(expiry.expired_at(30, 1))
  assert_false(expiry.expired_at(29, 11))
}

///|
test "STAN preserves zeroes and wraps after 999999" {
  let stan = parse_stan("000009").unwrap()
  assert_eq(stan.number, 9)
  assert_eq(stan.next().text, "000010")
  assert_eq(parse_stan("999999").unwrap().next().text, "000000")
}

///|
test "response code metadata distinguishes approvals and failures" {
  let approved = parse_response_code("00").unwrap()
  let declined = parse_response_code("51").unwrap()
  let private = parse_response_code("99").unwrap()
  assert_true(approved.approved)
  assert_false(declined.approved)
  assert_eq(declined.category, "funds")
  assert_eq(private.category, "network-defined")
}

///|
test "network operation codes have named semantics" {
  assert_eq(parse_network_management_code("001"), Ok(SignOn))
  assert_eq(parse_network_management_code("301"), Ok(EchoTest))
  assert_eq(
    parse_network_management_code("999"),
    Ok(UnknownNetworkOperation("999")),
  )
}

///|
test "common domain validation detects cross-field mismatches" {
  let message = message("0200").unwrap()
  message.set_field(2, "6222021234567890").unwrap()
  message.set_field(14, "3012").unwrap()
  message.set_field(35, "4111111111111111=29122011234567890").unwrap()
  message.set_field(12, "246060").unwrap()
  message.set_field(70, "001").unwrap()
  let issues = validate_common_domains(message)
  assert_true(issues.any(fn(issue) { issue.code == "PAN_TRACK_MISMATCH" }))
  assert_true(issues.any(fn(issue) { issue.code == "EXPIRY_TRACK_MISMATCH" }))
  assert_true(issues.any(fn(issue) { issue.code == "LOCAL_DATETIME_PAIR" }))
  assert_true(issues.any(fn(issue) { issue.code == "NETWORK_CODE_UNEXPECTED" }))
}

///|
test "network and reversal domain requirements are explicit" {
  let network = message("0800").unwrap()
  let network_issues = validate_common_domains(network)
  assert_true(
    network_issues.any(fn(issue) { issue.code == "NETWORK_CODE_REQUIRED" }),
  )
  let reversal = message("0400").unwrap()
  let reversal_issues = validate_common_domains(reversal)
  assert_true(
    reversal_issues.any(fn(issue) { issue.code == "ORIGINAL_DATA_REQUIRED" }),
  )
}

///|
test "RRN terminal and response validators reject bad widths" {
  assert_eq(
    parse_retrieval_reference("609160123456").unwrap().text,
    "609160123456",
  )
  assert_eq(validate_terminal_id("TERM0001"), Ok(()))
  match parse_retrieval_reference("SHORT") {
    Err(InvalidLength(37, 12, 5)) => ()
    _ => fail("RRN width should be exact")
  }
  match parse_response_code("A0") {
    Err(InvalidNumeric(39, _)) => ()
    _ => fail("response code should be decimal")
  }
}
