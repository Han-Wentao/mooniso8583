///|
fn correlated_request() -> IsoMessage {
  let request = message("0200").unwrap()
  request.set_field(2, "6222021234567890").unwrap()
  request.set_field(3, "000000").unwrap()
  request.set_field(4, "000000001500").unwrap()
  request.set_field(7, "0916123456").unwrap()
  request.set_field(11, "123456").unwrap()
  request.set_field(32, "123456").unwrap()
  request.set_field(37, "609160123456").unwrap()
  request.set_field(41, "TERM0001").unwrap()
  request.set_field(42, "MERCHANT0000001").unwrap()
  request.set_field(49, "156").unwrap()
  request
}

///|
test "response skeleton preserves transaction correlation fields" {
  let request = correlated_request()
  let response = response_skeleton(request, "00").unwrap()
  assert_eq(response.mti, "0210")
  assert_eq(response.field(39), Some("00"))
  assert_true(response_correlates(request, response))
}

///|
test "response correlation catches STAN amount MTI and sensitive echo" {
  let request = correlated_request()
  let response = response_skeleton(request, "05").unwrap()
  response.set_mti("0110").unwrap()
  response.set_field(4, "000000009999").unwrap()
  response.set_field(11, "654321").unwrap()
  response.set_field(52, "0011223344556677").unwrap()
  let issues = validate_response_correlation(request, response)
  assert_true(
    issues.any(fn(issue) { issue.code == "CORRELATION_RESPONSE_MTI" }),
  )
  assert_true(
    issues.any(fn(issue) {
      issue.field == 4 && issue.code == "CORRELATION_MISMATCH"
    }),
  )
  assert_true(
    issues.any(fn(issue) {
      issue.field == 11 && issue.code == "CORRELATION_MISMATCH"
    }),
  )
  assert_true(
    issues.any(fn(issue) { issue.code == "CORRELATION_SENSITIVE_ECHO" }),
  )
}

///|
test "network response correlates on STAN and network code" {
  let request = message("0800").unwrap()
  request.set_field(7, "0916123456").unwrap()
  request.set_field(11, "000001").unwrap()
  request.set_field(70, "001").unwrap()
  let response = response_skeleton(request, "00").unwrap()
  assert_eq(response.mti, "0810")
  assert_eq(response.field(70), Some("001"))
  assert_true(response_correlates(request, response))
}

///|
test "reversal skeleton creates fresh identifiers and DE90" {
  let original = correlated_request()
  let reversal = reversal_skeleton(original, "123457", "0916123556").unwrap()
  assert_eq(reversal.mti, "0400")
  assert_eq(reversal.field(11), Some("123457"))
  assert_eq(reversal.field(7), Some("0916123556"))
  assert_true(reversal.has_field(90))
  assert_eq(validate_reversal_correlation(original, reversal).length(), 0)
}

///|
test "reversal correlation detects wrong original and reused STAN" {
  let original = correlated_request()
  let reversal = reversal_skeleton(original, "123457", "0916123556").unwrap()
  reversal.set_field(11, "123456").unwrap()
  reversal.set_field(4, "000000000100").unwrap()
  let other = correlated_request()
  other.set_field(11, "999999").unwrap()
  let issues = validate_reversal_correlation(other, reversal)
  assert_true(
    issues.any(fn(issue) { issue.code == "REVERSAL_ORIGINAL_MISMATCH" }),
  )
  assert_true(
    issues.any(fn(issue) {
      issue.field == 4 && issue.code == "CORRELATION_MISMATCH"
    }),
  )
}

///|
test "response code and reversal identifiers are validated" {
  let request = correlated_request()
  match response_skeleton(request, "A0") {
    Err(TemplateViolation(_)) => ()
    _ => fail("response code must be numeric")
  }
  match reversal_skeleton(request, "12345", "0916123556") {
    Err(TemplateViolation(_)) => ()
    _ => fail("reversal STAN length must be checked")
  }
}
