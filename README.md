# MoonISO8583

MoonISO8583 是一个使用 MoonBit 编写的 ISO 8583-1987 支付交易报文库。它面向收单联调、终端模拟器和支付网关测试，提供 MTI、位图、字段规格、ASCII/BCD 编解码、常用复合字段解析与可复现诊断。

项目目前处于 0.1.0 开发阶段。最终文档会给出安装、三个完整示例、支持范围、验收命令和安全边界。

## 范围

- 支持主位图和次位图，以及 2–128 数据元。
- 支持固定长度、LLVAR、LLLVAR，ASCII 与 BCD 长度头。
- 支持授权、金融、冲正和网络管理消息模板。
- 支持 Processing Code、Track 2、DE54、DE55 BER-TLV、DE90。
- 不实现 HSM、PIN block、MAC 密码学、EMV Kernel 或 TCP 服务端。

## 许可证

Apache-2.0。
