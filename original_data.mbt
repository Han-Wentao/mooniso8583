///|
/// Structured representation of DE90 Original Data Elements.
pub(all) struct OriginalDataElements {
  original_mti : String
  original_stan : String
  original_transmission_datetime : String
  acquiring_institution_id : String
  forwarding_institution_id : String
} derive(Eq, Debug)

///|
/// Parse the fixed 42-digit DE90 layout.
pub fn parse_original_data(
  value : String,
) -> Result[OriginalDataElements, IsoError] {
  if value.length() != 42 {
    return Err(InvalidOriginalData("DE90 must contain 42 digits"))
  }
  match validate_numeric_text(90, value) {
    Err(_) =>
      return Err(InvalidOriginalData("DE90 contains a non-decimal character"))
    Ok(_) => ()
  }
  let original_mti = value[0:4].to_owned()
  match parse_mti(original_mti) {
    Err(_) => return Err(InvalidOriginalData("invalid original MTI"))
    Ok(_) => ()
  }
  let transmission = value[10:20].to_owned()
  match validate_transmission_datetime(transmission) {
    Err(_) =>
      return Err(InvalidOriginalData("invalid original transmission date/time"))
    Ok(_) => ()
  }
  Ok({
    original_mti,
    original_stan: value[4:10].to_owned(),
    original_transmission_datetime: transmission,
    acquiring_institution_id: value[20:31].to_owned(),
    forwarding_institution_id: value[31:42].to_owned(),
  })
}

///|
/// Validate MMDDhhmmss without assigning a year or timezone.
pub fn validate_transmission_datetime(value : String) -> Result[Unit, IsoError] {
  if value.length() != 10 {
    return Err(InvalidDateTime(value))
  }
  match validate_numeric_text(7, value) {
    Err(_) => return Err(InvalidDateTime(value))
    Ok(_) => ()
  }
  let month = decimal_pair(value, 0)
  let day = decimal_pair(value, 2)
  let hour = decimal_pair(value, 4)
  let minute = decimal_pair(value, 6)
  let second = decimal_pair(value, 8)
  if month < 1 ||
    month > 12 ||
    day < 1 ||
    day > 31 ||
    hour > 23 ||
    minute > 59 ||
    second > 59 {
    return Err(InvalidDateTime(value))
  }
  let maximum_day = days_in_month_without_year(month)
  if day > maximum_day {
    return Err(InvalidDateTime(value))
  }
  Ok(())
}

///|
/// Parse two decimal digits at a known-valid offset.
fn decimal_pair(value : String, offset : Int) -> Int {
  (value[offset].to_int() - 48) * 10 + value[offset + 1].to_int() - 48
}

///|
/// Conservative month length; February accepts day 29.
fn days_in_month_without_year(month : Int) -> Int {
  match month {
    2 => 29
    4 | 6 | 9 | 11 => 30
    _ => 31
  }
}

///|
/// Normalize an institution identifier to eleven decimal digits.
fn normalize_institution_id(value : String) -> Result[String, IsoError] {
  if value.length() > 11 {
    return Err(InvalidOriginalData("institution identifier exceeds 11 digits"))
  }
  match validate_numeric_text(90, value) {
    Err(_) => Err(InvalidOriginalData("institution identifier is not numeric"))
    Ok(_) => Ok(left_pad(value, 11, '0'))
  }
}

///|
/// Build DE90 from individual original-message identifiers.
pub fn original_data(
  original_mti : String,
  original_stan : String,
  original_transmission_datetime : String,
  acquiring_institution_id : String,
  forwarding_institution_id : String,
) -> Result[OriginalDataElements, IsoError] {
  match parse_mti(original_mti) {
    Err(_) => return Err(InvalidOriginalData("invalid original MTI"))
    Ok(_) => ()
  }
  if original_stan.length() != 6 {
    return Err(InvalidOriginalData("STAN must contain six digits"))
  }
  match validate_numeric_text(11, original_stan) {
    Err(_) => return Err(InvalidOriginalData("STAN is not numeric"))
    Ok(_) => ()
  }
  match validate_transmission_datetime(original_transmission_datetime) {
    Err(_) => return Err(InvalidOriginalData("invalid transmission date/time"))
    Ok(_) => ()
  }
  let acquiring = match normalize_institution_id(acquiring_institution_id) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let forwarding = match normalize_institution_id(forwarding_institution_id) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    original_mti,
    original_stan,
    original_transmission_datetime,
    acquiring_institution_id: acquiring,
    forwarding_institution_id: forwarding,
  })
}

///|
/// Render the 42-digit wire representation.
pub fn OriginalDataElements::to_string(self : OriginalDataElements) -> String {
  self.original_mti +
  self.original_stan +
  self.original_transmission_datetime +
  self.acquiring_institution_id +
  self.forwarding_institution_id
}

///|
/// Build DE90 from fields available in an original message.
pub fn original_data_from_message(
  message : IsoMessage,
) -> Result[OriginalDataElements, IsoError] {
  let stan = match message.field(11) {
    Some(value) => value
    None => return Err(MissingField(11))
  }
  let transmission = match message.field(7) {
    Some(value) => value
    None => return Err(MissingField(7))
  }
  let acquiring = message.field(32).unwrap_or("0")
  let forwarding = message.field(33).unwrap_or("0")
  original_data(message.mti, stan, transmission, acquiring, forwarding)
}

///|
/// Check that DE90 refers to the supplied original message.
pub fn OriginalDataElements::matches(
  self : OriginalDataElements,
  message : IsoMessage,
) -> Bool {
  if self.original_mti != message.mti {
    return false
  }
  if message.field(11) != Some(self.original_stan) {
    return false
  }
  if message.field(7) != Some(self.original_transmission_datetime) {
    return false
  }
  let acquiring = message.field(32).unwrap_or("0")
  let forwarding = message.field(33).unwrap_or("0")
  match
    (normalize_institution_id(acquiring), normalize_institution_id(forwarding)) {
    (Ok(a), Ok(f)) =>
      a == self.acquiring_institution_id && f == self.forwarding_institution_id
    _ => false
  }
}

///|
/// Attach a rendered DE90 to a reversal or advice message.
pub fn attach_original_data(
  target : IsoMessage,
  original : IsoMessage,
) -> Result[Unit, IsoError] {
  let data = match original_data_from_message(original) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  target.set_field(90, data.to_string())
}
