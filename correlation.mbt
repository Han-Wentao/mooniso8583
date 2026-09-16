///|
/// Build a stable validation issue for message-pair correlation.
fn correlation_issue(
  code : String,
  field : Int,
  message : String,
) -> ValidationIssue {
  { code, field, message, severity: "error", }
}

///|
/// Compare a field that must exist in both messages and remain unchanged.
fn require_echoed_field(
  request : IsoMessage,
  response : IsoMessage,
  field : Int,
  issues : Array[ValidationIssue],
) -> Unit {
  match (request.field(field), response.field(field)) {
    (None, _) =>
      issues.push(
        correlation_issue(
          "CORRELATION_REQUEST_MISSING",
          field,
          "request is missing correlation field \{field}",
        ),
      )
    (Some(_), None) =>
      issues.push(
        correlation_issue(
          "CORRELATION_RESPONSE_MISSING",
          field,
          "response is missing echoed field \{field}",
        ),
      )
    (Some(expected), Some(actual)) =>
      if expected != actual {
        issues.push(
          correlation_issue(
            "CORRELATION_MISMATCH",
            field,
            "field \{field} changed from \{expected} to \{actual}",
          ),
        )
      }
  }
}

///|
/// Compare an optional request field only when the response echoes it.
fn compare_if_echoed(
  request : IsoMessage,
  response : IsoMessage,
  field : Int,
  issues : Array[ValidationIssue],
) -> Unit {
  match (request.field(field), response.field(field)) {
    (Some(expected), Some(actual)) =>
      if expected != actual {
        issues.push(
          correlation_issue(
            "CORRELATION_MISMATCH",
            field,
            "optional echoed field \{field} changed from \{expected} to \{actual}",
          ),
        )
      }
    _ => ()
  }
}

///|
/// Validate that a response belongs to a particular request.
pub fn validate_response_correlation(
  request : IsoMessage,
  response : IsoMessage,
) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  let request_mti = match parse_mti(request.mti) {
    Ok(value) => value
    Err(_) => {
      issues.push(
        correlation_issue(
          "CORRELATION_REQUEST_MTI",
          0,
          "request has invalid MTI \{request.mti}",
        ),
      )
      return issues
    }
  }
  if !request_mti.is_request() {
    issues.push(
      correlation_issue(
        "CORRELATION_NOT_REQUEST",
        0,
        "MTI \{request.mti} is not request-like",
      ),
    )
  }
  match response_mti(request.mti) {
    Ok(expected) =>
      if response.mti != expected {
        issues.push(
          correlation_issue(
            "CORRELATION_RESPONSE_MTI",
            0,
            "expected response MTI \{expected}, got \{response.mti}",
          ),
        )
      }
    Err(_) =>
      issues.push(
        correlation_issue(
          "CORRELATION_RESPONSE_MTI",
          0,
          "cannot derive a response MTI from \{request.mti}",
        ),
      )
  }
  require_echoed_field(request, response, 11, issues)
  match request_mti.message_class {
    Authorization | Financial => {
      require_echoed_field(request, response, 3, issues)
      require_echoed_field(request, response, 4, issues)
      require_echoed_field(request, response, 41, issues)
      require_echoed_field(request, response, 49, issues)
      compare_if_echoed(request, response, 2, issues)
      compare_if_echoed(request, response, 32, issues)
      compare_if_echoed(request, response, 37, issues)
      compare_if_echoed(request, response, 42, issues)
    }
    Reversal => {
      require_echoed_field(request, response, 3, issues)
      require_echoed_field(request, response, 4, issues)
      require_echoed_field(request, response, 41, issues)
      require_echoed_field(request, response, 49, issues)
      require_echoed_field(request, response, 90, issues)
      compare_if_echoed(request, response, 37, issues)
    }
    NetworkManagement => {
      require_echoed_field(request, response, 70, issues)
      compare_if_echoed(request, response, 32, issues)
    }
    _ => ()
  }
  if !response.has_field(39) {
    issues.push(
      correlation_issue(
        "CORRELATION_RESPONSE_CODE", 39, "response must contain field 39 response code",
      ),
    )
  }
  if response.has_field(52) {
    issues.push(
      correlation_issue(
        "CORRELATION_SENSITIVE_ECHO", 52, "response must not echo PIN data",
      ),
    )
  }
  issues
}

///|
/// True when request and response pass all correlation checks.
pub fn response_correlates(request : IsoMessage, response : IsoMessage) -> Bool {
  validate_response_correlation(request, response).length() == 0
}

///|
/// Copy a field from source when present.
fn copy_field_if_present(
  source : IsoMessage,
  target : IsoMessage,
  field : Int,
) -> Result[Unit, IsoError] {
  match source.field(field) {
    Some(value) => target.set_field(field, value)
    None => Ok(())
  }
}

///|
/// Build a minimal response skeleton with correlation fields and response code.
pub fn response_skeleton(
  request : IsoMessage,
  response_code : String,
) -> Result[IsoMessage, IsoError] {
  if response_code.length() != 2 {
    return Err(TemplateViolation("response code must contain two digits"))
  }
  match validate_numeric_text(39, response_code) {
    Err(_) =>
      return Err(TemplateViolation("response code must contain two digits"))
    Ok(_) => ()
  }
  let mti = match response_mti(request.mti) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let response = match message(mti) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let parsed = match parse_mti(request.mti) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let common = [7, 11, 12, 13, 32, 37]
  for field in common {
    match copy_field_if_present(request, response, field) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  let class_fields = match parsed.message_class {
    Authorization | Financial => [3, 4, 41, 42, 49]
    Reversal => [3, 4, 41, 49, 90]
    NetworkManagement => [70]
    _ => []
  }
  for field in class_fields {
    match copy_field_if_present(request, response, field) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  match response.set_field(39, response_code) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  Ok(response)
}

///|
/// Validate that a reversal points to and preserves key data from its original transaction.
pub fn validate_reversal_correlation(
  original : IsoMessage,
  reversal : IsoMessage,
) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  let reversal_mti_value = match parse_mti(reversal.mti) {
    Ok(value) => value
    Err(_) => {
      issues.push(
        correlation_issue(
          "REVERSAL_MTI",
          0,
          "reversal has invalid MTI \{reversal.mti}",
        ),
      )
      return issues
    }
  }
  if reversal_mti_value.message_class != Reversal {
    issues.push(
      correlation_issue(
        "REVERSAL_MTI",
        0,
        "MTI \{reversal.mti} is not a reversal message",
      ),
    )
  }
  match reversal.field(90) {
    None =>
      issues.push(
        correlation_issue(
          "REVERSAL_ORIGINAL_DATA", 90, "reversal is missing DE90 original data elements",
        ),
      )
    Some(value) =>
      match parse_original_data(value) {
        Err(error) =>
          issues.push(
            correlation_issue("REVERSAL_ORIGINAL_DATA", 90, error.message()),
          )
        Ok(data) =>
          if !data.matches(original) {
            issues.push(
              correlation_issue(
                "REVERSAL_ORIGINAL_MISMATCH", 90, "DE90 does not identify the supplied original message",
              ),
            )
          }
      }
  }
  for field in [3, 4, 41, 49] {
    require_echoed_field(original, reversal, field, issues)
  }
  compare_if_echoed(original, reversal, 2, issues)
  compare_if_echoed(original, reversal, 32, issues)
  compare_if_echoed(original, reversal, 37, issues)
  compare_if_echoed(original, reversal, 42, issues)
  if reversal.field(11) == original.field(11) {
    issues.push(
      correlation_issue(
        "REVERSAL_STAN_REUSED", 11, "reversal should use a new STAN while DE90 retains the original STAN",
      ),
    )
  }
  if reversal.has_field(52) {
    issues.push(
      correlation_issue(
        "REVERSAL_PIN_COPIED", 52, "PIN data must not be copied into a reversal",
      ),
    )
  }
  issues
}

///|
/// Build a reversal request skeleton with a new STAN and transmission time.
pub fn reversal_skeleton(
  original : IsoMessage,
  reversal_stan : String,
  reversal_transmission_datetime : String,
) -> Result[IsoMessage, IsoError] {
  if reversal_stan.length() != 6 {
    return Err(TemplateViolation("reversal STAN must contain six digits"))
  }
  match validate_numeric_text(11, reversal_stan) {
    Err(_) =>
      return Err(TemplateViolation("reversal STAN must contain six digits"))
    Ok(_) => ()
  }
  match validate_transmission_datetime(reversal_transmission_datetime) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let mti = match reversal_mti(original.mti) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let reversal = match message(mti) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let copied = [2, 3, 4, 12, 13, 18, 22, 25, 32, 35, 37, 41, 42, 49, 55, 60]
  for field in copied {
    match copy_field_if_present(original, reversal, field) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  match reversal.set_field(7, reversal_transmission_datetime) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match reversal.set_field(11, reversal_stan) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match attach_original_data(reversal, original) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  Ok(reversal)
}
