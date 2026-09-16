///|
fn valid_financial_request() -> IsoMessage {
  let request = message("0200").unwrap()
  request.set_field(2, "6222021234567890").unwrap()
  request.set_field(3, "000000").unwrap()
  request.set_field(4, "000000001500").unwrap()
  request.set_field(7, "0916123456").unwrap()
  request.set_field(11, "123456").unwrap()
  request.set_field(22, "051").unwrap()
  request.set_field(41, "TERM0001").unwrap()
  request.set_field(49, "156").unwrap()
  request
}

///|
test "financial template accepts a complete purchase request" {
  let request = valid_financial_request()
  let template = financial_request_template()
  assert_true(message_matches_template(request, template))
  assert_eq(validate_known_message_template(request).unwrap().length(), 0)
}

///|
test "transaction template reports required forbidden and PAN rules" {
  let request = message("0200").unwrap()
  request.set_field(39, "00").unwrap()
  let issues = validate_message_template(request, financial_request_template())
  assert_true(issues.length() >= 8)
  assert_true(
    issues.any(fn(issue) {
      issue.code == "TEMPLATE_REQUIRED" && issue.field == 3
    }),
  )
  assert_true(
    issues.any(fn(issue) {
      issue.code == "TEMPLATE_FORBIDDEN" && issue.field == 39
    }),
  )
  assert_true(issues.any(fn(issue) { issue.code == "TEMPLATE_PAN_SOURCE" }))
}

///|
test "track 2 can supply the request PAN source" {
  let request = valid_financial_request()
  request.remove_field(2) |> ignore
  request.set_field(35, "6222021234567890=29122011234567890").unwrap()
  assert_true(message_matches_template(request, financial_request_template()))
}

///|
test "reversal template requires original data and excludes PIN" {
  let reversal = message("0400").unwrap()
  reversal.set_field(3, "000000").unwrap()
  reversal.set_field(4, "000000001500").unwrap()
  reversal.set_field(7, "0916123556").unwrap()
  reversal.set_field(11, "123457").unwrap()
  reversal.set_field(41, "TERM0001").unwrap()
  reversal.set_field(49, "156").unwrap()
  reversal.set_field(52, "0011223344556677").unwrap()
  let issues = validate_message_template(reversal, reversal_request_template())
  assert_true(
    issues.any(fn(issue) {
      issue.field == 90 && issue.code == "TEMPLATE_REQUIRED"
    }),
  )
  assert_true(
    issues.any(fn(issue) {
      issue.field == 52 && issue.code == "TEMPLATE_FORBIDDEN"
    }),
  )
  reversal.remove_field(52) |> ignore
  reversal.set_field(90, "020012345609161234560000000000000000000000").unwrap()
  assert_true(message_matches_template(reversal, reversal_request_template()))
}

///|
test "network management templates keep payment credentials out" {
  let request = message("0800").unwrap()
  request.set_field(7, "0916123456").unwrap()
  request.set_field(11, "000001").unwrap()
  request.set_field(70, "001").unwrap()
  assert_true(
    message_matches_template(request, network_management_request_template()),
  )
  request.set_field(2, "6222021234567890").unwrap()
  let issues = validate_message_template(
    request,
    network_management_request_template(),
  )
  assert_true(
    issues.any(fn(issue) {
      issue.field == 2 && issue.code == "TEMPLATE_FORBIDDEN"
    }),
  )
}

///|
test "template MTI sets and rule inventories are inspectable" {
  let reversal = reversal_request_template()
  assert_true(reversal.accepts_mti("0400"))
  assert_true(reversal.accepts_mti("0420"))
  assert_false(reversal.accepts_mti("0200"))
  assert_true(reversal.required_fields().contains(90))
  assert_true(reversal.forbidden_fields().contains(52))
  assert_eq(reversal.rule(90).unwrap().presence, RequiredField)
  assert_true(template_for_mti("0300") is None)
}

///|
test "using the wrong template reports the actual MTI" {
  let request = valid_financial_request()
  let issues = validate_message_template(
    request,
    authorization_request_template(),
  )
  assert_true(issues.any(fn(issue) { issue.code == "TEMPLATE_MTI" }))
  match validate_known_message_template(message("0300").unwrap()) {
    Err(TemplateViolation(_)) => ()
    _ => fail("unsupported MTI should be explicit")
  }
}
