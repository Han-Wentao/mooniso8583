///|
/// Parsed DE7 transmission date and time (MMDDhhmmss).
pub(all) struct TransmissionDateTime {
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
} derive(Eq, Debug)

///|
/// Parsed DE12 local time (hhmmss).
pub(all) struct LocalTransactionTime {
  hour : Int
  minute : Int
  second : Int
} derive(Eq, Debug)

///|
/// Parsed DE13 local date (MMDD).
pub(all) struct LocalTransactionDate {
  month : Int
  day : Int
} derive(Eq, Debug)

///|
/// Parsed DE14 card expiration (YYMM).
pub(all) struct CardExpiration {
  year : Int
  month : Int
} derive(Eq, Debug)

///|
/// Parsed systems trace audit number.
pub(all) struct Stan {
  text : String
  number : Int
} derive(Eq, Debug)

///|
/// Parsed retrieval reference number.
pub(all) struct RetrievalReference {
  text : String
} derive(Eq, Debug)

///|
/// Parsed response-code metadata.
pub(all) struct ResponseCodeInfo {
  code : String
  approved : Bool
  category : String
  meaning : String
} derive(Eq, Debug)

///|
/// Common network management operations carried in DE70.
pub(all) enum NetworkManagementOperation {
  SignOn
  SignOff
  EchoTest
  Cutover
  KeyChange
  UnknownNetworkOperation(String)
} derive(Eq, Debug)

///|
fn two_decimal(value : String, offset : Int) -> Int {
  (value[offset].to_int() - 48) * 10 + value[offset + 1].to_int() - 48
}

///|
fn valid_month_day(month : Int, day : Int) -> Bool {
  if month < 1 || month > 12 || day < 1 {
    return false
  }
  let maximum = match month {
    2 => 29
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
  day <= maximum
}

///|
fn require_decimal_width(
  field : Int,
  value : String,
  width : Int,
) -> Result[Unit, IsoError] {
  if value.length() != width {
    return Err(InvalidLength(field, width, value.length()))
  }
  match validate_numeric_text(field, value) {
    Ok(_) => Ok(())
    Err(_) => Err(InvalidNumeric(field, value))
  }
}

///|
/// Parse DE7 with calendar and clock range checks.
pub fn parse_transmission_datetime(
  value : String,
) -> Result[TransmissionDateTime, IsoError] {
  match require_decimal_width(7, value, 10) {
    Err(_) => return Err(InvalidDateTime(value))
    Ok(_) => ()
  }
  let month = two_decimal(value, 0)
  let day = two_decimal(value, 2)
  let hour = two_decimal(value, 4)
  let minute = two_decimal(value, 6)
  let second = two_decimal(value, 8)
  if !valid_month_day(month, day) || hour > 23 || minute > 59 || second > 59 {
    return Err(InvalidDateTime(value))
  }
  Ok({ month, day, hour, minute, second, })
}

///|
/// Parse DE12 local transaction time.
pub fn parse_local_transaction_time(
  value : String,
) -> Result[LocalTransactionTime, IsoError] {
  match require_decimal_width(12, value, 6) {
    Err(_) => return Err(InvalidDateTime(value))
    Ok(_) => ()
  }
  let hour = two_decimal(value, 0)
  let minute = two_decimal(value, 2)
  let second = two_decimal(value, 4)
  if hour > 23 || minute > 59 || second > 59 {
    return Err(InvalidDateTime(value))
  }
  Ok({ hour, minute, second, })
}

///|
/// Parse DE13 local transaction date.
pub fn parse_local_transaction_date(
  value : String,
) -> Result[LocalTransactionDate, IsoError] {
  match require_decimal_width(13, value, 4) {
    Err(_) => return Err(InvalidDateTime(value))
    Ok(_) => ()
  }
  let month = two_decimal(value, 0)
  let day = two_decimal(value, 2)
  if !valid_month_day(month, day) {
    return Err(InvalidDateTime(value))
  }
  Ok({ month, day, })
}

///|
/// Parse DE14 card expiration date.
pub fn parse_card_expiration(
  value : String,
) -> Result[CardExpiration, IsoError] {
  match require_decimal_width(14, value, 4) {
    Err(_) => return Err(InvalidDateTime(value))
    Ok(_) => ()
  }
  let year = two_decimal(value, 0)
  let month = two_decimal(value, 2)
  if month < 1 || month > 12 {
    return Err(InvalidDateTime(value))
  }
  Ok({ year, month, })
}

///|
/// True after the supplied two-digit calendar month has passed.
pub fn CardExpiration::expired_at(
  self : CardExpiration,
  year : Int,
  month : Int,
) -> Bool {
  self.year < year || (self.year == year && self.month < month)
}

///|
/// Parse a six-digit STAN while preserving leading zeroes.
pub fn parse_stan(value : String) -> Result[Stan, IsoError] {
  match require_decimal_width(11, value, 6) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let mut number = 0
  for i = 0; i < 6; i = i + 1 {
    number = number * 10 + value[i].to_int() - 48
  }
  Ok({ text: value, number, })
}

///|
/// Return the next STAN with six-digit wraparound.
pub fn Stan::next(self : Stan) -> Stan {
  let next = (self.number + 1) % 1000000
  { text: decimal_width(next, 6).unwrap(), number: next, }
}

///|
/// Parse a 12-character retrieval reference number.
pub fn parse_retrieval_reference(
  value : String,
) -> Result[RetrievalReference, IsoError] {
  if value.length() != 12 {
    return Err(InvalidLength(37, 12, value.length()))
  }
  match validate_alphanumeric_text(37, value, false) {
    Err(error) => Err(error)
    Ok(_) => Ok({ text: value, })
  }
}

///|
/// Validate an eight-character terminal identifier.
pub fn validate_terminal_id(value : String) -> Result[Unit, IsoError] {
  if value.length() != 8 {
    return Err(InvalidLength(41, 8, value.length()))
  }
  match validate_printable_text(41, value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if value.trim().length() == 0 {
    return Err(InvalidCharacter(41, 0, "blank terminal identifier"))
  }
  Ok(())
}

///|
/// Interpret widely used ISO 8583 response codes without imposing one network dialect.
pub fn parse_response_code(
  value : String,
) -> Result[ResponseCodeInfo, IsoError] {
  match require_decimal_width(39, value, 2) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let info = match value {
    "00" => (true, "approved", "approved or completed successfully")
    "01" => (false, "referral", "refer to card issuer")
    "03" => (false, "configuration", "invalid merchant or acceptor")
    "05" => (false, "decline", "do not honor")
    "12" => (false, "format", "invalid transaction")
    "13" => (false, "format", "invalid amount")
    "14" => (false, "account", "invalid account number")
    "30" => (false, "format", "format error")
    "41" => (false, "card", "lost card")
    "43" => (false, "card", "stolen card")
    "51" => (false, "funds", "insufficient funds")
    "54" => (false, "card", "expired card")
    "55" => (false, "authentication", "incorrect PIN")
    "57" => (false, "restriction", "transaction not permitted to cardholder")
    "58" => (false, "restriction", "transaction not permitted to terminal")
    "61" => (false, "limit", "amount limit exceeded")
    "68" => (false, "timeout", "response received too late")
    "75" => (false, "authentication", "PIN tries exceeded")
    "91" => (false, "availability", "issuer or switch unavailable")
    "94" => (false, "duplicate", "duplicate transmission")
    "96" => (false, "system", "system malfunction")
    _ => (false, "network-defined", "network-specific response code")
  }
  Ok({ code: value, approved: info.0, category: info.1, meaning: info.2, })
}

///|
/// Parse common DE70 operation codes.
pub fn parse_network_management_code(
  value : String,
) -> Result[NetworkManagementOperation, IsoError] {
  match require_decimal_width(70, value, 3) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  Ok(
    match value {
      "001" => SignOn
      "002" => SignOff
      "101" => KeyChange
      "201" => Cutover
      "301" => EchoTest
      other => UnknownNetworkOperation(other)
    },
  )
}

///|
fn domain_issue(
  field : Int,
  code : String,
  message : String,
) -> ValidationIssue {
  { code, field, message, severity: "error", }
}

///|
/// Validate common field domains and cross-field consistency.
pub fn validate_common_domains(message : IsoMessage) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  let checks : Array[(Int, (String) -> Result[Unit, IsoError])] = [
    (7, fn(value) { parse_transmission_datetime(value).map(fn(_) { () }) }),
    (11, fn(value) { parse_stan(value).map(fn(_) { () }) }),
    (12, fn(value) { parse_local_transaction_time(value).map(fn(_) { () }) }),
    (13, fn(value) { parse_local_transaction_date(value).map(fn(_) { () }) }),
    (14, fn(value) { parse_card_expiration(value).map(fn(_) { () }) }),
    (37, fn(value) { parse_retrieval_reference(value).map(fn(_) { () }) }),
    (39, fn(value) { parse_response_code(value).map(fn(_) { () }) }),
    (41, validate_terminal_id),
    (70, fn(value) { parse_network_management_code(value).map(fn(_) { () }) }),
  ]
  for check in checks {
    match message.field(check.0) {
      None => ()
      Some(value) =>
        match (check.1)(value) {
          Ok(_) => ()
          Err(error) =>
            issues.push(domain_issue(check.0, error.code(), error.message()))
        }
    }
  }
  match (message.field(2), message.field(35)) {
    (Some(pan), Some(track_text)) =>
      match parse_track2(track_text) {
        Ok(track) =>
          if track.pan != pan {
            issues.push(
              domain_issue(
                35, "PAN_TRACK_MISMATCH", "field 2 PAN and field 35 Track 2 PAN differ",
              ),
            )
          }
        Err(_) => ()
      }
    _ => ()
  }
  match (message.field(14), message.field(35)) {
    (Some(expiry), Some(track_text)) =>
      match parse_track2(track_text) {
        Ok(track) =>
          if track.expiration != expiry {
            issues.push(
              domain_issue(
                14, "EXPIRY_TRACK_MISMATCH", "field 14 expiry and field 35 Track 2 expiry differ",
              ),
            )
          }
        Err(_) => ()
      }
    _ => ()
  }
  if message.has_field(12) != message.has_field(13) {
    issues.push(
      domain_issue(
        12, "LOCAL_DATETIME_PAIR", "fields 12 local time and 13 local date should be supplied together",
      ),
    )
  }
  let parsed_mti = parse_mti(message.mti)
  match parsed_mti {
    Ok(mti) => {
      if mti.message_class == NetworkManagement && !message.has_field(70) {
        issues.push(
          domain_issue(
            70, "NETWORK_CODE_REQUIRED", "network management message requires field 70",
          ),
        )
      }
      if mti.message_class != NetworkManagement && message.has_field(70) {
        issues.push(
          domain_issue(
            70, "NETWORK_CODE_UNEXPECTED", "field 70 is reserved for network management traffic",
          ),
        )
      }
      if mti.message_class == Reversal && !message.has_field(90) {
        issues.push(
          domain_issue(
            90, "ORIGINAL_DATA_REQUIRED", "reversal message requires field 90",
          ),
        )
      }
    }
    Err(error) => issues.push(domain_issue(0, error.code(), error.message()))
  }
  issues
}
