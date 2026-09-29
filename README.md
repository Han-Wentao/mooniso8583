# MoonISO8583

MoonISO8583 是一个使用 MoonBit 编写的 ISO 8583-1987 报文编解码与业务校验库，面向收单联调、POS/ATM 终端模拟、支付网关适配和交易回放。项目重点处理真正容易出错的部分：位图、固定字段与 LLVAR/LLLVAR、ASCII/BCD 差异、请求响应关联、冲正 DE90、EMV DE55 BER-TLV，以及日志中的卡号和密钥数据保护。

ISO 8583 在不同机构之间通常会形成各自的字段配置。MoonISO8583 提供一套可运行的 1987 基准规格，同时把字段定义、报文模板和传输格式分开，接入方可以替换字段规格，不需要重写位图和编解码器。

## 主要能力

- MTI 解析，支持请求、响应、重发和冲正 MTI 派生。
- 64 位主位图与 128 位主/次位图，支持二进制和 ASCII Hex 表示。
- 固定长度、LLVAR、LLLVAR 字段，支持 ASCII 长度头、BCD 长度头、ASCII/BCD/Binary 内容。
- ISO 8583-1987 的 DE2–DE128 基准字段规格，可自行创建 `FieldSpec` 和 `Packager`。
- ASCII MTI + Binary Bitmap、ASCII MTI + ASCII Hex Bitmap、BCD MTI + Binary Bitmap 三种线格式。
- Processing Code、金额、ISO 4217 常用币种、PAN/Luhn、Track 2、DE54、DE55、DE90 等领域模型。
- `0100/0110`、`0200/0210`、`0400/0410`、`0420/0430`、`0800/0810` 报文模板。
- 请求/响应关联检查，STAN、金额、终端号、币种、RRN、DE90 等关键字段不一致时给出稳定错误。
- 2 字节大端长度头和 4 位 ASCII 长度头，增量处理半包、粘包和连续多包。
- 安全诊断：PAN 保留前六后四，Track 1/2、PIN Data、MAC、密钥数据不输出原文，DE55 只显示长度和 Tag。
- 可预测的 `IsoError` 错误码与 `ValidationIssue` 校验结果，便于网关映射日志和监控指标。

## 处理流程

```text
IsoMessage
   │  字段规格校验 / 业务模板校验 / 领域一致性校验
   ▼
MTI + Bitmap + Data Elements
   │  WireProfile: ASCII / BCD / Binary
   ▼
ISO 8583 payload
   │  FrameHeader: uint16-be 或 ASCII4
   ▼
TCP frame
```

解码按相反方向进行。传输层只负责长度帧，不绑定 Socket、异步运行时或服务端框架。

## 快速开始

### 1. 构造并编码金融请求

```moonbit
let packager = @iso.iso1987_packager()
let request = @iso.message("0200").unwrap()
request.set_field(2, "6222021234567890").unwrap()
request.set_field(3, "000000").unwrap()
request.set_field(4, "000000001500").unwrap()
request.set_field(7, "0916123456").unwrap()
request.set_field(11, "123456").unwrap()
request.set_field(22, "051").unwrap()
request.set_field(41, "TERM0001").unwrap()
request.set_field(49, "156").unwrap()

let issues = @iso.validate_message_template(
  request,
  @iso.financial_request_template(),
)
assert_eq(issues.length(), 0)

let payload = @iso.pack_message(
  packager,
  @iso.ascii_binary_profile(),
  request,
).unwrap()
```

调用方包的 `moon.pkg`：

```text
import {
  "Han-Wentao/mooniso8583" @iso,
}
```

### 2. 解码并生成响应

```moonbit
let received = @iso.unpack_message(
  packager,
  @iso.ascii_binary_profile(),
  payload,
).unwrap()

let response = @iso.response_skeleton(received, "00").unwrap()
response.set_field(38, "A12345").unwrap()
assert_true(@iso.response_correlates(received, response))
```

`response_skeleton` 只复制关联所需字段，不会把 DE52 PIN Data 带入响应。

### 3. 增量处理 TCP 数据

```moonbit
let decoder = @iso.stream_decoder(
  @iso.BinaryBigEndian16,
  8192,
).unwrap()

let frames = decoder.feed(socket_chunk).unwrap()
for frame in frames {
  let message = @iso.unpack_message(
    packager,
    @iso.ascii_binary_profile(),
    frame,
  ).unwrap()
  // 处理一条完整报文
}
```

连接关闭时调用 `decoder.finish()`，可以区分正常结束和残留半包。

## 三个可运行场景

### 授权请求与响应

终端构造 `0100`，先检查必填字段，再完成位图和字段编码；模拟发卡方解码后生成 `0110`，校验 MTI、STAN、金额、终端号和币种是否与请求对应。输出使用安全诊断，不泄露完整 PAN 或 DE55 值。

```bash
moon run examples/authorization
```

### 消费冲正

网关保留原始 `0200`，超时后用新的 STAN 和传输时间生成 `0400`。库自动从原交易构造 42 位 DE90，并检查 Processing Code、金额、终端、币种和原交易标识。DE52 不会复制到冲正报文。

```bash
moon run examples/reversal
```

### 网络管理 Sign-on

接入程序生成 `0800 + DE70=001`，添加 2 字节大端长度头，模拟半包/粘包环境下的收包；对端返回 `0810 + DE39=00`，请求与响应按 STAN 和 DE70 关联。

```bash
moon run examples/network_management
```

## 字段规格和线格式

`iso1987_packager()` 使用 ASCII 内容和常见 ISO 8583-1987 长度。`iso1987_bcd_packager()` 将适合的数字字段改为 BCD 表示。实际机构规范有差异，尤其是 DE48、DE60–DE63、DE100 以后字段；接入时应按接口文档建立独立 `Packager`，不要直接假设基准规格等于某家网络规范。

内置线格式：

| API | MTI | Bitmap | 典型用途 |
| --- | --- | --- | --- |
| `ascii_binary_profile()` | 4 字节 ASCII | 8/16 字节二进制 | 常见 TCP 私有网络 |
| `ascii_hex_profile()` | 4 字节 ASCII | 16/32 字节 ASCII Hex | 文本网关、联调日志 |
| `bcd_binary_profile()` | 2 字节 BCD | 8/16 字节二进制 | 带宽敏感或历史终端协议 |

## 业务模板与领域校验

报文模板只规定通用的必填、可选和禁用字段；机构私有要求应在上层追加。模板校验与字段编码校验分开，因此可以明确区分“字段格式错误”和“这类交易不允许出现该字段”。

常用入口：

- `validate_message_fields`：检查长度、字符集、padding 和字段规格。
- `validate_message_template`：检查必填、禁用字段和 PAN 来源。
- `validate_common_domains`：检查日期、时间、STAN、RRN、响应码、DE2/DE35、DE14/DE35 一致性。
- `validate_response_correlation`：关联请求与响应。
- `validate_reversal_correlation`：确认 DE90 指向正确原交易。

## DE55 BER-TLV

DE55 支持 1–4 字节 BER Tag、短长度和 1–4 字节长定长、constructed TLV、递归查询和重新编码。解析器拒绝 indefinite length、非最短长度、非法高 Tag 编码、截断值和超过 16 层的嵌套。

```moonbit
let nodes = @iso.parse_de55(
  "9F260811223344556677889F270180",
).unwrap()
let cryptogram = @iso.find_tlv(nodes, "9F26").unwrap()
assert_eq(cryptogram.value.length(), 8)
```

这里处理的是 BER-TLV 结构，不解释 EMV Tag 的业务含义，也不实现 EMV Kernel 或脱机认证。

## 日志安全

不要直接打印 `IsoMessage`。使用：

```moonbit
println(@iso.safe_message_dump(message, packager))
```

默认策略：

| 字段 | 日志行为 |
| --- | --- |
| DE2 | 前六后四，其余替换为 `*` |
| DE35 / DE45 | 隐藏有效期、服务码和全部轨道数据 |
| DE52 | 完全隐藏 PIN Data |
| DE53 / DE96 | 隐藏安全控制和密钥管理数据 |
| DE55 | 仅显示字节数和 Tag 列表 |
| DE64 / DE128 | 完全隐藏 MAC |

安全诊断降低误打日志的风险，但不能代替 PCI DSS 流程、密钥隔离、HSM 或访问控制。

## 错误处理

编解码 API 返回 `Result[..., IsoError]`。`IsoError::code()` 提供稳定代码，`IsoError::message()` 提供可读原因。批量校验返回 `Array[ValidationIssue]`，一次可以报告多个缺失或冲突字段。

例如，截断 LLVAR、位图长度错误、BCD nibble 非法、DE55 非最短长度、DE90 日期错误和超长 TCP frame 都有独立错误类型。

## 与常见实现的定位区别

| 项目/类型 | 主要定位 | MoonISO8583 的取舍 |
| --- | --- | --- |
| jPOS | Java 支付平台，覆盖 Channel、MUX、交易管理等完整基础设施 | 不做交换平台，只提供 MoonBit 原生编解码、校验和传输帧 |
| j8583 | Java ISO 8583 报文库 | 提供 MoonBit 类型和多后端构建，增加严格 BER-TLV、DE90 关联与安全诊断 |
| pyiso8583 | Python 配置驱动编解码 | 保留可配置字段模型，同时面向静态编译和 Wasm/JS/Native 目标 |
| 手写字符串拼接 | 快速但难以处理次位图、变长头和截断错误 | 字段规格、位图和错误偏移统一处理，并用 round-trip 测试覆盖 |

MoonISO8583 目前不是 jPOS 替代品。它适合嵌入网关、模拟器和测试工具，网络连接池、持久化队列、路由、HSM、密钥生命周期由宿主系统负责。

## 明确不做

- 不实现 PIN Block 的生成、翻译或校验。
- 不实现 MAC/签名算法和密钥存储，只把相关字段当作受保护的二进制数据。
- 不实现 HSM、EMV Kernel、3-D Secure、银行卡清算规则或争议处理。
- 不提供 TCP 服务端、连接池、超时重试和交易数据库。
- 不承诺内置 1987 profile 与任何特定银行或卡组织私有规范完全一致。
- 暂不实现 ISO 8583:1993/2003 的完整字段语义。

这些边界让库保持可审计。密码学和在线交易状态机应由专门组件承担。

## 工具链与持续集成

项目要求 `moonc >= 0.10.14`。本地可以先运行 `moonc -v`，再执行下面的版本检查；版本过低时应按 MoonBit 官方安装方式升级，不要用旧编译器生成提交物：

```bash
python tools/check_moonc_version.py --minimum 0.10.14
```

GitHub Actions 会在每次 push 和 pull request 中执行格式检查、有效源码门槛、Wasm GC/Wasm/JavaScript/Native 四个目标的检查与构建、跨后端测试，以及三个端到端示例。工作流中的版本门禁和显式 `moon build` 让验收要求可以直接复现。

## 测试和验收

```bash
moon fmt
moon check --target wasm-gc --deny-warn
moon check --target wasm --deny-warn
moon check --target js --deny-warn
moon build --target wasm-gc --deny-warn
moon build --target js --deny-warn
moon test --target wasm-gc
moon test --target js
moon run examples/authorization
moon run examples/reversal
moon run examples/network_management
python tools/count_effective_moonbit.py --check-core 3000
```

GitHub CI 额外运行 Native check/build/test，并执行 `moonc >= 0.10.14` 的版本门禁。当前仓库有 **81 个测试**，覆盖位图、BCD、字段编解码、报文 round-trip、PAN/Track 2、DE54、DE55、DE90、模板、请求响应关联、流式半包/粘包和安全日志。

源码统计使用保守口径：排除测试、示例、生成目录、空行、整行注释，并将大型字段规格表 `profile_1987.mbt` 单独列出。2026 年 9 月 29 日复核结果：

| 分类 | 文件 | 物理行 | 有效行 |
| --- | ---: | ---: | ---: |
| 核心算法（不含规格表） | 20 | 5288 | **4396** |
| ISO 8583-1987 字段规格表 | 1 | 302 | 282 |
| 测试 | 18 | 1042 | 886 |
| 三个示例 | 3 | 105 | 102 |

核心算法单独超过 3000 行，字段规格表没有用于满足该门槛。可随时运行统计脚本复核。

## 工程状态

- 版本：`0.1.0`
- 许可证：Apache-2.0
- 默认目标：Wasm GC
- CI：检查、构建、测试覆盖 Wasm GC、Wasm、JavaScript、Native
- 工具链门禁：`moonc >= 0.10.14`
- 提交历史：按功能切片提交，包含 20 个以上可独立审查的实现、测试、示例和工程提交

## 原创与参考

项目为原创 MoonBit 实现，没有移植其他 ISO 8583 库的源码。ISO 8583 字段编号和行业术语属于协议知识；实现结构、错误体系、编解码器、业务模板、流式帧、诊断策略和测试均在本项目中编写。对标项目只用于界定功能边界，不构成源码移植。

## 许可证

Apache License 2.0，见 `LICENSE`。
