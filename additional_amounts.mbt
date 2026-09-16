///|
/// One twenty-character component of DE54 Additional Amounts.
pub(all) struct AdditionalAmount {
  account_type : String
  amount_type : String
  currency : String
  sign : UInt16
  amount : String
} derive(Eq, Debug)

///|
/// Named meaning for common DE54 amount type codes.
pub(all) enum AdditionalAmountType {
  LedgerBalance
  AvailableBalance
  CashAmount
  PurchaseAmount
  CreditLimit
  UnknownAdditionalAmount(String)
} derive(Eq, Debug)

///|
/// Parse one fixed-width DE54 component.
pub fn parse_additional_amount_component(
  value : String,
) -> Result[AdditionalAmount, IsoError] {
  if value.length() != 20 {
    return Err(InvalidAmount(value))
  }
  let account = value[0:2].to_owned()
  let amount_type = value[2:4].to_owned()
  let currency = value[4:7].to_owned()
  let sign = value[7]
  let amount = value[8:20].to_owned()
  match validate_numeric_text(54, account) {
    Err(_) => return Err(InvalidAmount(value))
    Ok(_) => ()
  }
  match validate_numeric_text(54, amount_type) {
    Err(_) => return Err(InvalidAmount(value))
    Ok(_) => ()
  }
  match parse_currency(currency) {
    Err(_) => return Err(InvalidAmount(value))
    Ok(_) => ()
  }
  if sign != 'C' && sign != 'D' {
    return Err(InvalidAmount(value))
  }
  match validate_numeric_text(54, amount) {
    Err(_) => return Err(InvalidAmount(value))
    Ok(_) => ()
  }
  Ok({ account_type: account, amount_type, currency, sign, amount, })
}

///|
/// Parse concatenated DE54 amount components.
pub fn parse_additional_amounts(
  value : String,
) -> Result[Array[AdditionalAmount], IsoError] {
  if value.length() == 0 || value.length() % 20 != 0 {
    return Err(InvalidAmount(value))
  }
  let result : Array[AdditionalAmount] = []
  let mut offset = 0
  while offset < value.length() {
    let component = value[offset:offset + 20].to_owned()
    match parse_additional_amount_component(component) {
      Ok(amount) => result.push(amount)
      Err(error) => return Err(error)
    }
    offset += 20
  }
  Ok(result)
}

///|
/// Build one DE54 component from validated pieces.
pub fn additional_amount(
  account_type_code : String,
  amount_type_code : String,
  currency : String,
  debit : Bool,
  minor_units : Int64,
) -> Result[AdditionalAmount, IsoError] {
  if account_type_code.length() != 2 || amount_type_code.length() != 2 {
    return Err(InvalidAmount(account_type_code + amount_type_code))
  }
  match validate_numeric_text(54, account_type_code) {
    Err(_) => return Err(InvalidAmount(account_type_code))
    Ok(_) => ()
  }
  match validate_numeric_text(54, amount_type_code) {
    Err(_) => return Err(InvalidAmount(amount_type_code))
    Ok(_) => ()
  }
  match parse_currency(currency) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let amount = match format_minor_amount(minor_units, 12) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    account_type: account_type_code,
    amount_type: amount_type_code,
    currency,
    sign: if debit {
      'D'
    } else {
      'C'
    },
    amount,
  })
}

///|
/// Render one DE54 component.
pub fn AdditionalAmount::to_string(self : AdditionalAmount) -> String {
  self.account_type +
  self.amount_type +
  self.currency +
  self.sign.to_int().unsafe_to_char().to_string() +
  self.amount
}

///|
/// Render multiple DE54 components in wire order.
pub fn format_additional_amounts(values : Array[AdditionalAmount]) -> String {
  let out = StringBuilder()
  for value in values {
    out.write_string(value.to_string())
  }
  out.to_string()
}

///|
/// Decode the amount type code into a useful label.
pub fn AdditionalAmount::kind(self : AdditionalAmount) -> AdditionalAmountType {
  match self.amount_type {
    "01" => LedgerBalance
    "02" => AvailableBalance
    "40" => CashAmount
    "41" => PurchaseAmount
    "61" => CreditLimit
    other => UnknownAdditionalAmount(other)
  }
}

///|
/// Signed minor units from the component.
pub fn AdditionalAmount::signed_minor_units(self : AdditionalAmount) -> Int64 {
  let mut value : Int64 = 0
  for i = 0; i < self.amount.length(); i = i + 1 {
    value = value * 10 + (self.amount[i].to_int() - 48).to_int64()
  }
  if self.sign == 'D' {
    0L - value
  } else {
    value
  }
}

///|
/// Render the component with currency metadata and decimal scale.
pub fn AdditionalAmount::display(
  self : AdditionalAmount,
) -> Result[String, IsoError] {
  let currency = match parse_currency(self.currency) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let scale = currency.minor_units.unwrap_or(2)
  let unsigned = match parse_minor_amount(54, self.amount, 12, scale) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let sign = if self.sign == 'D' { "-" } else { "" }
  let name = currency.alpha.unwrap_or(currency.numeric)
  Ok("\{name} \{sign}\{unsigned.display()}")
}

///|
/// Find the first component with the requested amount type.
pub fn find_additional_amount(
  values : Array[AdditionalAmount],
  amount_type : String,
) -> AdditionalAmount? {
  for value in values {
    if value.amount_type == amount_type {
      return Some(value)
    }
  }
  None
}
