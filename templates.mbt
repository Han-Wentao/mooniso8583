///|
/// Whether a data element is required, optional, or forbidden by a message template.
pub(all) enum FieldPresence {
  RequiredField
  OptionalField
  ForbiddenField
} derive(Eq, Debug)

///|
/// One field-level rule attached to a business message template.
pub(all) struct TemplateFieldRule {
  field : Int
  presence : FieldPresence
  purpose : String
} derive(Eq, Debug)

///|
/// A practical ISO 8583 message template for one or more exact MTIs.
pub(all) struct MessageTemplate {
  name : String
  mtis : Array[String]
  rules : Array[TemplateFieldRule]
  require_pan_source : Bool
} derive(Debug)

///|
fn required(field : Int, purpose : String) -> TemplateFieldRule {
  { field, presence: RequiredField, purpose, }
}

///|
fn optional(field : Int, purpose : String) -> TemplateFieldRule {
  { field, presence: OptionalField, purpose, }
}

///|
fn forbidden(field : Int, purpose : String) -> TemplateFieldRule {
  { field, presence: ForbiddenField, purpose, }
}

///|
/// Common rules for authorization and financial requests.
fn transaction_request_rules() -> Array[TemplateFieldRule] {
  [
    optional(2, "PAN when not supplied in track data"),
    required(3, "processing code"),
    required(4, "transaction amount"),
    required(7, "transmission date and time"),
    required(11, "systems trace audit number"),
    optional(12, "local transaction time"),
    optional(13, "local transaction date"),
    optional(14, "card expiry date"),
    optional(18, "merchant category code"),
    required(22, "point-of-service entry mode"),
    optional(23, "card sequence number"),
    optional(25, "point-of-service condition code"),
    optional(26, "point-of-service PIN capture code"),
    optional(28, "transaction fee"),
    optional(32, "acquiring institution identifier"),
    optional(35, "track 2 data"),
    optional(37, "retrieval reference number"),
    required(41, "terminal identifier"),
    optional(42, "acceptor identifier"),
    optional(43, "acceptor name and location"),
    required(49, "transaction currency"),
    optional(52, "encrypted PIN data"),
    optional(53, "security control information"),
    optional(54, "additional amounts"),
    optional(55, "EMV integrated-circuit data"),
    optional(60, "network private data"),
    optional(61, "issuer private data"),
    optional(63, "network private data"),
    optional(64, "message authentication code"),
    forbidden(39, "response code belongs to responses"),
    forbidden(90, "original data belongs to reversals and adjustments"),
  ]
}

///|
/// Common rules for authorization and financial responses.
fn transaction_response_rules() -> Array[TemplateFieldRule] {
  [
    optional(2, "PAN echoed when the network profile allows it"),
    required(3, "processing code echoed from request"),
    required(4, "transaction amount echoed from request"),
    required(7, "transmission date and time"),
    required(11, "systems trace audit number"),
    optional(12, "local transaction time"),
    optional(13, "local transaction date"),
    optional(15, "settlement date"),
    optional(32, "acquiring institution identifier"),
    optional(37, "retrieval reference number"),
    optional(38, "authorization identification response"),
    required(39, "response code"),
    required(41, "terminal identifier"),
    optional(42, "acceptor identifier"),
    required(49, "transaction currency"),
    optional(54, "additional amounts"),
    optional(55, "issuer EMV response data"),
    optional(60, "network private data"),
    optional(61, "issuer private data"),
    optional(63, "network private data"),
    optional(64, "message authentication code"),
    forbidden(52, "PIN data must not be echoed in a response"),
    forbidden(90, "ordinary transaction response has no original data"),
  ]
}

///|
/// Common rules for reversal requests and advices.
fn reversal_request_rules() -> Array[TemplateFieldRule] {
  [
    optional(2, "PAN when required by the network profile"),
    required(3, "processing code of the reversed transaction"),
    required(4, "amount of the reversed transaction"),
    required(7, "reversal transmission date and time"),
    required(11, "reversal systems trace audit number"),
    optional(12, "local transaction time"),
    optional(13, "local transaction date"),
    optional(18, "merchant category code"),
    optional(22, "point-of-service entry mode"),
    optional(25, "point-of-service condition code"),
    optional(32, "acquiring institution identifier"),
    optional(35, "track 2 data when retained securely"),
    optional(37, "retrieval reference number"),
    required(41, "terminal identifier"),
    optional(42, "acceptor identifier"),
    required(49, "transaction currency"),
    optional(55, "EMV reversal data"),
    optional(56, "message reason code"),
    optional(60, "network private data"),
    optional(64, "message authentication code"),
    required(90, "original transaction identifiers"),
    optional(95, "replacement amounts"),
    forbidden(39, "response code belongs to reversal responses"),
    forbidden(52, "PIN data must not be copied into a reversal"),
  ]
}

///|
/// Common rules for reversal responses.
fn reversal_response_rules() -> Array[TemplateFieldRule] {
  [
    required(3, "processing code"),
    required(4, "transaction amount"),
    required(7, "transmission date and time"),
    required(11, "systems trace audit number"),
    optional(32, "acquiring institution identifier"),
    optional(37, "retrieval reference number"),
    required(39, "response code"),
    required(41, "terminal identifier"),
    required(49, "transaction currency"),
    optional(56, "message reason code"),
    optional(64, "message authentication code"),
    required(90, "original transaction identifiers"),
    forbidden(52, "PIN data must not be echoed"),
  ]
}

///|
/// Rules for sign-on, echo, key exchange, and sign-off requests.
fn network_request_rules() -> Array[TemplateFieldRule] {
  [
    required(7, "transmission date and time"),
    required(11, "systems trace audit number"),
    optional(12, "local transaction time"),
    optional(13, "local transaction date"),
    optional(32, "acquiring institution identifier"),
    optional(48, "additional network data"),
    optional(53, "security control information"),
    optional(64, "message authentication code"),
    required(70, "network management information code"),
    optional(96, "key management data"),
    optional(128, "secondary message authentication code"),
    forbidden(2, "network management messages carry no PAN"),
    forbidden(35, "network management messages carry no track data"),
    forbidden(39, "response code belongs to the response"),
    forbidden(52, "network management messages carry no PIN block"),
  ]
}

///|
/// Rules for network management responses.
fn network_response_rules() -> Array[TemplateFieldRule] {
  [
    required(7, "transmission date and time"),
    required(11, "systems trace audit number"),
    optional(12, "local transaction time"),
    optional(13, "local transaction date"),
    optional(32, "acquiring institution identifier"),
    required(39, "response code"),
    optional(48, "additional network data"),
    optional(53, "security control information"),
    optional(64, "message authentication code"),
    required(70, "network management information code"),
    optional(96, "key management data"),
    optional(128, "secondary message authentication code"),
    forbidden(2, "network management messages carry no PAN"),
    forbidden(35, "network management messages carry no track data"),
    forbidden(52, "network management messages carry no PIN block"),
  ]
}

///|
/// Authorization request template (0100).
pub fn authorization_request_template() -> MessageTemplate {
  {
    name: "authorization request",
    mtis: ["0100"],
    rules: transaction_request_rules(),
    require_pan_source: true,
  }
}

///|
/// Authorization response template (0110).
pub fn authorization_response_template() -> MessageTemplate {
  {
    name: "authorization response",
    mtis: ["0110"],
    rules: transaction_response_rules(),
    require_pan_source: false,
  }
}

///|
/// Financial request template (0200).
pub fn financial_request_template() -> MessageTemplate {
  {
    name: "financial request",
    mtis: ["0200"],
    rules: transaction_request_rules(),
    require_pan_source: true,
  }
}

///|
/// Financial response template (0210).
pub fn financial_response_template() -> MessageTemplate {
  {
    name: "financial response",
    mtis: ["0210"],
    rules: transaction_response_rules(),
    require_pan_source: false,
  }
}

///|
/// Reversal request/advice template (0400 or 0420).
pub fn reversal_request_template() -> MessageTemplate {
  {
    name: "reversal request or advice",
    mtis: ["0400", "0420"],
    rules: reversal_request_rules(),
    require_pan_source: false,
  }
}

///|
/// Reversal response template (0410 or 0430).
pub fn reversal_response_template() -> MessageTemplate {
  {
    name: "reversal response",
    mtis: ["0410", "0430"],
    rules: reversal_response_rules(),
    require_pan_source: false,
  }
}

///|
/// Network management request template (0800).
pub fn network_management_request_template() -> MessageTemplate {
  {
    name: "network management request",
    mtis: ["0800"],
    rules: network_request_rules(),
    require_pan_source: false,
  }
}

///|
/// Network management response template (0810).
pub fn network_management_response_template() -> MessageTemplate {
  {
    name: "network management response",
    mtis: ["0810"],
    rules: network_response_rules(),
    require_pan_source: false,
  }
}

///|
/// Look up the built-in template for a supported exact MTI.
pub fn template_for_mti(mti : String) -> MessageTemplate? {
  match mti {
    "0100" => Some(authorization_request_template())
    "0110" => Some(authorization_response_template())
    "0200" => Some(financial_request_template())
    "0210" => Some(financial_response_template())
    "0400" | "0420" => Some(reversal_request_template())
    "0410" | "0430" => Some(reversal_response_template())
    "0800" => Some(network_management_request_template())
    "0810" => Some(network_management_response_template())
    _ => None
  }
}

///|
/// Find a rule for one data element.
pub fn MessageTemplate::rule(
  self : MessageTemplate,
  field : Int,
) -> TemplateFieldRule? {
  for rule in self.rules {
    if rule.field == field {
      return Some(rule)
    }
  }
  None
}

///|
/// True when an exact MTI belongs to this template.
pub fn MessageTemplate::accepts_mti(
  self : MessageTemplate,
  mti : String,
) -> Bool {
  for accepted in self.mtis {
    if accepted == mti {
      return true
    }
  }
  false
}

///|
/// Validate required, forbidden, and composite business rules.
pub fn validate_message_template(
  message : IsoMessage,
  template : MessageTemplate,
) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  if !template.accepts_mti(message.mti) {
    issues.push({
      code: "TEMPLATE_MTI",
      field: 0,
      message: "template \{template.name} does not accept MTI \{message.mti}",
      severity: "error",
    })
  }
  for rule in template.rules {
    match rule.presence {
      RequiredField =>
        if !message.has_field(rule.field) {
          issues.push({
            code: "TEMPLATE_REQUIRED",
            field: rule.field,
            message: "field \{rule.field} is required for \{rule.purpose}",
            severity: "error",
          })
        }
      ForbiddenField =>
        if message.has_field(rule.field) {
          issues.push({
            code: "TEMPLATE_FORBIDDEN",
            field: rule.field,
            message: "field \{rule.field} is forbidden: \{rule.purpose}",
            severity: "error",
          })
        }
      OptionalField => ()
    }
  }
  if template.require_pan_source &&
    !message.has_field(2) &&
    !message.has_field(35) {
    issues.push({
      code: "TEMPLATE_PAN_SOURCE",
      field: 2,
      message: "one of field 2 PAN or field 35 track 2 data is required",
      severity: "error",
    })
  }
  issues
}

///|
/// Validate a message with its built-in template.
pub fn validate_known_message_template(
  message : IsoMessage,
) -> Result[Array[ValidationIssue], IsoError] {
  match template_for_mti(message.mti) {
    Some(template) => Ok(validate_message_template(message, template))
    None =>
      Err(TemplateViolation("no built-in template for MTI \{message.mti}"))
  }
}

///|
/// True when the message satisfies the selected template.
pub fn message_matches_template(
  message : IsoMessage,
  template : MessageTemplate,
) -> Bool {
  validate_message_template(message, template).length() == 0
}

///|
/// Return all required field numbers for documentation and diagnostics.
pub fn MessageTemplate::required_fields(self : MessageTemplate) -> Array[Int] {
  let output : Array[Int] = []
  for rule in self.rules {
    if rule.presence == RequiredField {
      output.push(rule.field)
    }
  }
  output
}

///|
/// Return all explicitly forbidden field numbers.
pub fn MessageTemplate::forbidden_fields(self : MessageTemplate) -> Array[Int] {
  let output : Array[Int] = []
  for rule in self.rules {
    if rule.presence == ForbiddenField {
      output.push(rule.field)
    }
  }
  output
}
