# Idea Inbox LAN protocol v1

仅用于用户主动配对的一部安卓与一台 Windows 电脑。JSON 字段中的 version 必须为 1；不兼容时拒绝写入。
TLS 监听于用户所选私有 IPv4 地址；默认端口 47381。客户端关闭代理、重定向及系统根证书信任，按配对二维码校验证书 DER 的 SHA-256。

## 数据模型

Revision 字段：id、ideaId、deviceId（UUID v4）、parents（父修订 ID 列表）、text、archived、deleted、createdAt、editedAt。
内容不允许为空，最多 32000 个 UTF-16 code units。时间用于展示与排序，不参与版本覆盖决策。
每个 idea 只有一个根版本，所有后续版本必须引用同一 idea 的既存父版本并保留 createdAt。
接收方验证整个合并后的有向图：父版本齐全、归属一致、无环、相同 ID 的规范内容完全一致。
验证失败整批拒绝；验证成功后在 SQLite 事务内提交新修订。

没有被其他修订引用为父版本的修订为当前 head。多个 head 构成冲突。
手动合并创建一个同时引用所有当前 head 的新修订；历史不会物理删除。
删除和恢复均为新修订。删除与并发编辑不会按时间戳静默解决。

## 配对

电脑生成 256-bit 随机单次凭据，二维码包含：

- kind: idea-inbox-pair
- version: 1
- deviceId: 电脑设备 ID
- endpoint: HTTPS 私有 IPv4 地址及端口
- fingerprint: 证书 DER SHA-256 小写十六进制
- secret: base64url 随机凭据

配对码两分钟过期。POST /pair 发送 version、deviceId、secret。
验证成功即消耗配对码，电脑展示手机 ID 并要求用户确认（最多等待一分钟）。
批准后生成新的 256-bit token，安全存储对端身份并返回 version、deviceId、token。
一次只允许一个配对请求在处理；新配对替换旧对端，需用户明确确认。
返回丢失时，用户重新生成二维码配对，不降级认证。

## 同步

除 /pair 外均需 Authorization: Bearer <token>。请求包含 version 与手机 deviceId。
凭据或设备不一致返回拒绝；每次请求读取完整请求体后再次确认信任仍有效。

1. POST /inventory：电脑返回 version、deviceId、ids（所有已提交修订 ID）。
2. 手机取得本地修订快照，计算电脑缺少的修订。
3. POST /exchange：发送 version、deviceId、known（快照的全部 ID）、revisions（电脑缺少的修订）。
4. 电脑校验并事务提交后返回 version、deviceId、revisions（手机缺少的电脑修订）、received（已接收的上传 ID）。
5. 手机校验并事务提交响应修订后，POST /ack 发送 version、deviceId、ids（手机已持久化的全部 ID）。
6. 电脑记录手机确认，返回 version、deviceId、ok。手机再记录电脑持有的修订。

初始版交换完整 ID 清单，按 ID 去重，不依赖游标或设备时钟。修订最多 10000 条；单个请求或响应最多 16 MiB。
超出限制必须明确报错，不能截断或默默跳过。此限制意味着在未实现分页前，过大的历史集合可能需要应用升级才能继续同步。

## 故障语义

- /exchange 返回前断线：已提交的电脑数据保留。重试按 ID 去重。
- 手机提交后、/ack 到达前断线：修订保留，下一次同步重新确认，待同步计数可能暂时偏高。
- 同步期间本地新增：快照外变更保持为待同步，下次传输。
- 本地编辑框打开期间收到新修订：保存时检测 head 集合已变化，拒绝覆盖并要求重新打开。
- 导入备份保留原始修订 ID，属于相同的合并流程；不导入设备密钥或配对状态。
- 本版未提供可信对端的恶意数据证明、速率限制、分页或大规模协同；尚未经过独立安全审计。
