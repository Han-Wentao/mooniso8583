///|
/// Parsed six-digit processing code (DE3).
pub(all) struct ProcessingCode {
  transaction_type : String
  from_account : String
  to_account : String
} derive(Eq, Debug)

///|
/// Common transaction-type meaning.
pub(all) enum TransactionType {
  GoodsAndServices
  CashWithdrawal
  DebitAdjustment
  CreditAdjustment
  BalanceInquiry
  AccountTransfer
  Payment
  Deposit
  UnknownTransactionType(String)
} derive(Eq, Debug)

///|
/// Common account-type meaning.
pub(all) enum AccountType {
  DefaultAccount
  Savings
  Checking
  Credit
  Universal
  Investment
  ElectronicPurse
  UnknownAccountType(String)
} derive(Eq, Debug)

///|
/// Parse DE3 into three two-digit components.
pub fn parse_processing_code(
  value : String,
) -> Result[ProcessingCode, IsoError] {
  if value.length() != 6 {
    return Err(InvalidProcessingCode(value))
  }
  match validate_numeric_text(3, value) {
    Err(_) => return Err(InvalidProcessingCode(value))
    Ok(_) => ()
  }
  Ok({
    transaction_type: value[0:2].to_owned(),
    from_account: value[2:4].to_owned(),
    to_account: value[4:6].to_owned(),
  })
}

///|
/// Build DE3 from validated two-digit components.
pub fn processing_code(
  transaction_type : String,
  from_account : String,
  to_account : String,
) -> Result[String, IsoError] {
  let value = transaction_type + from_account + to_account
  match parse_processing_code(value) {
    Ok(_) => Ok(value)
    Err(error) => Err(error)
  }
}

///|
/// Map a DE3 transaction type to a named meaning.
pub fn ProcessingCode::transaction(self : ProcessingCode) -> TransactionType {
  match self.transaction_type {
    "00" => GoodsAndServices
    "01" => CashWithdrawal
    "02" => DebitAdjustment
    "20" => CreditAdjustment
    "30" => BalanceInquiry
    "40" => AccountTransfer
    "50" => Payment
    "21" => Deposit
    other => UnknownTransactionType(other)
  }
}

///|
/// Map the source-account component.
pub fn ProcessingCode::source_account(self : ProcessingCode) -> AccountType {
  account_type(self.from_account)
}

///|
/// Map the destination-account component.
pub fn ProcessingCode::destination_account(
  self : ProcessingCode,
) -> AccountType {
  account_type(self.to_account)
}

///|
/// Decode one two-digit account type.
pub fn account_type(value : String) -> AccountType {
  match value {
    "00" => DefaultAccount
    "10" => Savings
    "20" => Checking
    "30" => Credit
    "40" => Universal
    "50" => Investment
    "60" => ElectronicPurse
    other => UnknownAccountType(other)
  }
}

///|
/// Human-readable transaction-type label.
pub fn TransactionType::label(self : TransactionType) -> String {
  match self {
    GoodsAndServices => "goods and services"
    CashWithdrawal => "cash withdrawal"
    DebitAdjustment => "debit adjustment"
    CreditAdjustment => "credit adjustment"
    BalanceInquiry => "balance inquiry"
    AccountTransfer => "account transfer"
    Payment => "payment"
    Deposit => "deposit"
    UnknownTransactionType(value) => "transaction type \{value}"
  }
}

///|
/// Human-readable account-type label.
pub fn AccountType::label(self : AccountType) -> String {
  match self {
    DefaultAccount => "default"
    Savings => "savings"
    Checking => "checking"
    Credit => "credit"
    Universal => "universal"
    Investment => "investment"
    ElectronicPurse => "electronic purse"
    UnknownAccountType(value) => "account type \{value}"
  }
}

///|
/// Parsed unsigned minor-unit amount.
pub(all) struct MinorAmount {
  minor_units : Int64
  digits : String
  scale : Int
} derive(Eq, Debug)

///|
/// Parse a fixed-width numeric amount in minor currency units.
pub fn parse_minor_amount(
  field : Int,
  value : String,
  width : Int,
  scale : Int,
) -> Result[MinorAmount, IsoError] {
  if value.length() != width || width <= 0 || scale < 0 || scale > width {
    return Err(InvalidAmount(value))
  }
  match validate_numeric_text(field, value) {
    Err(_) => return Err(InvalidAmount(value))
    Ok(_) => ()
  }
  let mut amount : Int64 = 0
  for i = 0; i < value.length(); i = i + 1 {
    amount = amount * 10 + (value[i].to_int() - 48).to_int64()
  }
  Ok({ minor_units: amount, digits: value, scale, })
}

///|
/// Format a non-negative minor-unit amount as fixed-width digits.
pub fn format_minor_amount(
  value : Int64,
  width : Int,
) -> Result[String, IsoError] {
  if value < 0 || width <= 0 {
    return Err(InvalidAmount(value.to_string()))
  }
  let text = value.to_string()
  if text.length() > width {
    return Err(InvalidAmount(text))
  }
  Ok(left_pad(text, width, '0'))
}

///|
/// Format a decimal display without floating-point arithmetic.
pub fn MinorAmount::display(self : MinorAmount) -> String {
  if self.scale == 0 {
    return self.minor_units.to_string()
  }
  let padded = left_pad(self.minor_units.to_string(), self.scale + 1, '0')
  let split = padded.length() - self.scale
  padded[0:split].to_owned() + "." + padded[split:].to_owned()
}

///|
/// ISO 4217 numeric code represented by DE49/50/51.
pub(all) struct CurrencyCode {
  numeric : String
  alpha : String?
  minor_units : Int?
} derive(Eq, Debug)

///|
/// Parse a three-digit currency code with selected common metadata.
pub fn parse_currency(value : String) -> Result[CurrencyCode, IsoError] {
  if value.length() != 3 {
    return Err(InvalidCurrency(value))
  }
  match validate_numeric_text(49, value) {
    Err(_) => return Err(InvalidCurrency(value))
    Ok(_) => ()
  }
  let (alpha, minor) = match value {
    "036" => (Some("AUD"), Some(2))
    "124" => (Some("CAD"), Some(2))
    "156" => (Some("CNY"), Some(2))
    "344" => (Some("HKD"), Some(2))
    "356" => (Some("INR"), Some(2))
    "392" => (Some("JPY"), Some(0))
    "410" => (Some("KRW"), Some(0))
    "702" => (Some("SGD"), Some(2))
    "826" => (Some("GBP"), Some(2))
    "840" => (Some("USD"), Some(2))
    "978" => (Some("EUR"), Some(2))
    _ => (None, None)
  }
  Ok({ numeric: value, alpha, minor_units: minor, })
}

///|
/// Combine DE4 and DE49 into an inspectable amount description.
pub fn describe_transaction_amount(
  amount : String,
  currency : String,
) -> Result[String, IsoError] {
  let code = match parse_currency(currency) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let scale = code.minor_units.unwrap_or(2)
  let parsed = match parse_minor_amount(4, amount, 12, scale) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let name = code.alpha.unwrap_or(code.numeric)
  Ok("\{name} \{parsed.display()}")
}
