///|
/// ISO 8583 version digit.
pub(all) enum MtiVersion {
  Iso1987
  Iso1993
  Iso2003
  NationalVersion
  PrivateVersion
  ReservedVersion(Int)
} derive(Eq, Debug)

///|
/// Message class digit.
pub(all) enum MessageClass {
  Authorization
  Financial
  FileAction
  Reversal
  Reconciliation
  Administrative
  FeeCollection
  NetworkManagement
  ReservedClass(Int)
} derive(Eq, Debug)

///|
/// Message function digit.
pub(all) enum MessageFunction {
  Request
  RequestResponse
  Advice
  AdviceResponse
  Notification
  NotificationAcknowledgement
  Instruction
  InstructionAcknowledgement
  ReservedFunction(Int)
} derive(Eq, Debug)

///|
/// Message origin digit.
pub(all) enum MessageOrigin {
  Acquirer
  AcquirerRepeat
  Issuer
  IssuerRepeat
  OtherOrigin(Int)
} derive(Eq, Debug)

///|
/// Parsed four-digit message type indicator.
pub(all) struct Mti {
  text : String
  version : MtiVersion
  message_class : MessageClass
  function : MessageFunction
  origin : MessageOrigin
} derive(Eq, Debug)

///|
/// Parse an MTI into named components.
pub fn parse_mti(text : String) -> Result[Mti, IsoError] {
  if !valid_mti_text(text) {
    return Err(InvalidMti(text))
  }
  let version_digit = text[0].to_int() - 48
  let class_digit = text[1].to_int() - 48
  let function_digit = text[2].to_int() - 48
  let origin_digit = text[3].to_int() - 48
  let version = match version_digit {
    0 => Iso1987
    1 => Iso1993
    2 => Iso2003
    8 => NationalVersion
    9 => PrivateVersion
    other => ReservedVersion(other)
  }
  let message_class = match class_digit {
    1 => Authorization
    2 => Financial
    3 => FileAction
    4 => Reversal
    5 => Reconciliation
    6 => Administrative
    7 => FeeCollection
    8 => NetworkManagement
    other => ReservedClass(other)
  }
  let function = match function_digit {
    0 => Request
    1 => RequestResponse
    2 => Advice
    3 => AdviceResponse
    4 => Notification
    5 => NotificationAcknowledgement
    6 => Instruction
    7 => InstructionAcknowledgement
    other => ReservedFunction(other)
  }
  let origin = match origin_digit {
    0 => Acquirer
    1 => AcquirerRepeat
    2 => Issuer
    3 => IssuerRepeat
    other => OtherOrigin(other)
  }
  Ok({ text, version, message_class, function, origin, })
}

///|
/// Human-readable version label.
pub fn MtiVersion::label(self : MtiVersion) -> String {
  match self {
    Iso1987 => "ISO 8583:1987"
    Iso1993 => "ISO 8583:1993"
    Iso2003 => "ISO 8583:2003"
    NationalVersion => "national"
    PrivateVersion => "private"
    ReservedVersion(value) => "reserved version \{value}"
  }
}

///|
/// Human-readable message class label.
pub fn MessageClass::label(self : MessageClass) -> String {
  match self {
    Authorization => "authorization"
    Financial => "financial"
    FileAction => "file action"
    Reversal => "reversal"
    Reconciliation => "reconciliation"
    Administrative => "administrative"
    FeeCollection => "fee collection"
    NetworkManagement => "network management"
    ReservedClass(value) => "reserved class \{value}"
  }
}

///|
/// Human-readable function label.
pub fn MessageFunction::label(self : MessageFunction) -> String {
  match self {
    Request => "request"
    RequestResponse => "request response"
    Advice => "advice"
    AdviceResponse => "advice response"
    Notification => "notification"
    NotificationAcknowledgement => "notification acknowledgement"
    Instruction => "instruction"
    InstructionAcknowledgement => "instruction acknowledgement"
    ReservedFunction(value) => "reserved function \{value}"
  }
}

///|
/// Human-readable origin label.
pub fn MessageOrigin::label(self : MessageOrigin) -> String {
  match self {
    Acquirer => "acquirer"
    AcquirerRepeat => "acquirer repeat"
    Issuer => "issuer"
    IssuerRepeat => "issuer repeat"
    OtherOrigin(value) => "other origin \{value}"
  }
}

///|
/// True when this MTI is a request-like message.
pub fn Mti::is_request(self : Mti) -> Bool {
  self.function == Request ||
  self.function == Advice ||
  self.function == Notification ||
  self.function == Instruction
}

///|
/// True when this MTI is a response or acknowledgement.
pub fn Mti::is_response(self : Mti) -> Bool {
  self.function == RequestResponse ||
  self.function == AdviceResponse ||
  self.function == NotificationAcknowledgement ||
  self.function == InstructionAcknowledgement
}

///|
/// True for authorization and financial traffic.
pub fn Mti::is_transaction(self : Mti) -> Bool {
  self.message_class == Authorization || self.message_class == Financial
}

///|
/// Derive the ordinary response MTI by incrementing the function digit.
pub fn response_mti(text : String) -> Result[String, IsoError] {
  let parsed = match parse_mti(text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let function_digit = text[2].to_int() - 48
  if function_digit % 2 != 0 || function_digit >= 7 {
    return Err(InvalidMti(text))
  }
  let out = StringBuilder()
  out.write_string(text[0:2].to_owned())
  out.write_char((48 + function_digit + 1).unsafe_to_char())
  out.write_string(text[3:4].to_owned())
  ignore(parsed)
  Ok(out.to_string())
}

///|
/// Convert a request/advice to its acquirer-repeat form.
pub fn repeat_mti(text : String) -> Result[String, IsoError] {
  let parsed = match parse_mti(text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let origin = match parsed.origin {
    Acquirer => 1
    Issuer => 3
    AcquirerRepeat => 1
    IssuerRepeat => 3
    OtherOrigin(_) => return Err(InvalidMti(text))
  }
  let out = StringBuilder()
  out.write_string(text[0:3].to_owned())
  out.write_char((48 + origin).unsafe_to_char())
  Ok(out.to_string())
}

///|
/// Derive a reversal request MTI while retaining version and origin.
pub fn reversal_mti(text : String) -> Result[String, IsoError] {
  let parsed = match parse_mti(text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if parsed.message_class != Authorization && parsed.message_class != Financial {
    return Err(InvalidMti(text))
  }
  let out = StringBuilder()
  out.write_string(text[0:1].to_owned())
  out.write_char('4')
  out.write_string(text[2:4].to_owned())
  Ok(out.to_string())
}

///|
/// Compact description used in diagnostics.
pub fn Mti::describe(self : Mti) -> String {
  "\{self.text} \{self.version.label()} \{self.message_class.label()} \{self.function.label()} from \{self.origin.label()}"
}
