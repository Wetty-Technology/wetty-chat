**全局说明：**

- **网关/路由规则：** HTTP API 请求路径遵循 `/<模块key>/<具体业务>` 的格式。
- **请求/响应格式：** HTTP API 默认使用 `application/json`，统一返回标准格式 `{ "code": 200, "msg": "success", "data": {} }`。以下API未说明res即无需data数据块。
- **鉴权：** 除注册/登录接口外，所有 HTTP/WS/File 请求均需要在 Header (如 `Authorization: Bearer <token>`) 或连接参数中携带 Token。Token长度为100位：
	- 1~32位 为用户uuid
	- 33~64位 为用户永续key（32位）
	- 65~68位 为客户端类型（4位）
	- 69~76位 为临时授权secret_key（定时重新下发）（8位）
	- 77~92位 为客户端key（16位）
	- 93~100位 为uint32（second）timestamp （8位）

---

## 第一部分：HTTP-API 文档

### 1. 用户模块 (模块 Key: `users`)

_此模块负责用户凭证和基础信息维护。_
- **POST** `/users/auth/register`
    - **说明:** 用户注册。
    - **Req:** `{"username": "xx", "password": "xx"}`
- **POST** `/users/auth/login`
    - **说明:** 用户登录。根据客户端类型下发不同生命周期的 Token。
    - **Req:** `{"username": "xx", "password": "xx", "client_type": "web|mobile"}`
    - **Res:** `{"token": "xxx", "user_key": "xxx"}` _(Web端返回临时Token，Mobile端返回永久Token)_
- **GET** `/users/profile`
    - **说明:** 获取个人资料。
    - **Res:** `{"nickname": "xx", "avatar_fid": "xx", "bio": "xx", "sr_link": "xx", "add_friend_setting": "xx"}`
- **PUT** `/users/profile`
    - **说明:** 更新个人资料（头像、bio、sr主站link、添加好友限制等）。
    - **Req:** `{"avatar_fid": "xx", "bio": "xx", ...}`

### 2. 好友模块 (模块 Key: `friend`)

_此模块负责好友关系链的维护。_
- **POST** `/friend/apply`
    - **说明:** 申请加好友。
    - **Req:** `{"target_user_id": "xx", "apply_msg": "你好"}`
- **DELETE** `/friend/{user_id}`
    - **说明:** 解除好友关系。
- **POST** `/friend/block`
    - **说明:** 拉黑用户。
    - **Req:** `{"target_user_id": "xx"}`

### 3. 群组模块 (模块 Key: `group`)

_此模块负责群组生命周期和成员管理。_
- **POST** `/group`
    - **说明:** 建群。**(已实现)**
    - **Req:** `{"name": "xx"}`
    - **Res:** `{"id": "xxx", "name": "xx", "created_at": "..."}`  
- **GET** `/group/{group_id}`
    - **说明:** 获取群资料。**(已实现)**
- **DELETE** `/group/{group_id}`
    - **说明:** 解散群（仅限群主）。
- **PUT** `/group/{group_id}/profile`
    - **说明:** 修改群资料（群名、群头像、public/private、入群验证规则、群类别）。
- **GET** `/group/{group_id}/members`
    - **说明:** 拉取群成员列表。**(已实现)**
- **POST** `/group/{group_id}/members`
    - **说明:** 管理员加人入群。**(已实现)**
- **POST** `/group/{group_id}/members/apply`
    - **说明:** 申请入群。
- **DELETE** `/group/{group_id}/members/{user_id}`
    - **说明:** 减人/踢出群聊。
- **PUT** `/group/{group_id}/managers`
    - **说明:** 群管设置（分配/取消管理员权限）。
- **POST** `/group/{group_id}/mute`
    - **说明:** 禁言/取消禁言。
    - **Req:** `{"target_user_id": "xx", "mute_status": true, "duration_seconds": 3600}`

### 4. 会话模块 (模块 Key: `chats`) - HTTP部分

_发送动作通过 HTTP 保证到达率，接收动作通过 WS 推送。具体消息类型见其他相关文档。_
- **GET** `/chats`
    - **说明:** 拉取当前用户会话列表。**(已实现)**
- **GET** `/chats/{chat_id}/messages?before={message_id}&max={max_num_message}`
    - **说明:** 拉取会话消息（游标分页）。**(已实现)**
- **POST** `/chats/{chat_id}/messages`
    - **说明:** 发送消息（支持文本、动作表情、文件转发、@提醒等）。**(已实现)**
    - **Req:** `{"message": "...", "message_type": "text|image|file|emote|...", "client_generated_id": "idempotency_key", "reply_to_id": "xx", "reply_root_id": "xx"}`
- **POST** `/chats/message/recall`
    - **说明:** 撤回消息。
    - **Req:** `{"msg_id": "xx"}`

### 5. 文件模块 (模块 Key: `fserv`)

写入操作仅允许会话模块转发写入，需要会话模块在header设置内部key（不写入客户端）；支持客户端直接读文件，但依然需要鉴权。
- **写入文件 (Upload)**
    - **API:** `POST /fserv/upload`
    - **说明:** 会话模块以 File Stream (流式) 形式上传文件。
    - **Header:** `Content-Type: multipart/form-data` 或 `application/octet-stream`
    - **Res:** 返回唯一的文件ID：`{"fid": "file_xxx123"}`。该 `fid` 随后用于消息发送。
- **读取文件 (Download/Stream)**
    - **API:** `GET /f/fserv/download/{fid}`
    - **说明:** 客户端通过此接口获取文件流进行展示（如前端加载图片、下载附件）。

---


## 第二部分：文件流与 WebSocket 文档

### 1. WebSocket 消息推送 (会话模块附属)

_建立长连接以实现消息实时送达。_

- **连接地址:** `ws://<domain>/ws/chats?uid=<uid>`
- **心跳机制:** 客户端每 30s 发送 `ping`，服务端回复 `pong`。
- **服务端推送事件 (Downstream Events):**
    - `on_message`: 收到新消息（包含文本、动作表情、文件消息）。
    - `on_recall`: 收到某条消息被撤回的指令。
    - `on_notify`: 系统通知（如：收到好友申请、@提醒、被拉入群聊、被禁言提醒）。

---

## 第三部分：需求文档 (PRD / 架构逻辑解析)

本节主要描述业务需求以及**前后端职责划分、内部隐藏逻辑**，图中的诸多节点属于系统内部机制，而非对外 API。

### 1. 用户模块需求
- **多端登录策略 (内部逻辑):** 系统需区分 Web 和 Mobile 端。Web 端发放生命周期较短的“临时 token”，Mobile 端（如 Android）发放长期有效的“永久 token”。
- **个人中心:** 用户可以自定义头像、Bio 简介，并可关联 SR 主站 Link。
- **隐私控制:** 用户可设置他人加好友的限制规则（类似 QQ 的“需要验证信息”、“拒绝任何人添加”、“允许任何人”）。

### 2. 好友模块需求
- **关系链管理:** 支持双向好友关系，以及单向拉黑（屏蔽对方消息）。

### 3. 群组模块需求
- **群组全生命周期:** 包含建群、解散群。
- **精细化群管:**
    - **基础属性:** 群名、群头像、群类别（如大群、小群划分，影响性能分配）。
    - **权限管理:** 群主可设置群管（分权限等级）；支持对特定成员禁言/取消禁言；踢人/加人。
    - **群隐私:** 支持 Public（可搜索加入）和 Private（隐藏群）。入群需支持不同的验证方式。

### 4. 会话模块 (核心消息流)需求
- **丰富消息格式:** 支持纯文本、动作表情（仿tg支持对消息进行单表情评论等动作）、文件收发、@特定人提醒。
- **伪 Markdown 格式处理 (前端/内部逻辑):** 用户发送带有特定语法的文本，**由前端渲染**（或后端解析后下发 AST）成粗体、斜体、代码块等伪 MD 格式，不单独暴露 API。
- **消息转发与撤回:** 支持消息实体的转发（若转发的是文件，则携带对应 `fid`）；支持消息的限时撤回。
- **音视频通话 (非必要需求):** 作为系统的二期或扩展需求，预留信令通道。
- **【核心内部逻辑】消息鉴权机制:**
    - **用户状态机:** 这是一个**后端内部服务**。当发起发送或接收消息的请求时，会话模块必须调用“用户状态机”。
    - **鉴权内容:** 检查用户是否已登录；检查双方是否为好友关系；检查是否在对方黑名单内；检查是否在同一群组内；检查该用户是否被群禁言。鉴权通过后消息才允许流转。

### 5. 文件模块需求
- **流式处理:** 针对 Web、Android 等多端，文件上传下载必须采用 File Stream 流式传输，以节省内存并支持大文件。
- **文件标识:** 文件上传后统一产生 `fid`，会话记录中只保存 `fid`，不保存文件实体。
- **【核心内部逻辑】文件鉴权:** 与消息鉴权共用逻辑。当用户请求读取 `GET /f/fserv/download/{fid}` 时，系统需验证该用户是否有权限查看该文件（例如：该文件是否发送在当前用户所在的群里？发送者是否拉黑了当前用户？），防止通过猜解 `fid` 越权盗取文件。


## 第四部分：技术选型

| 层级        | 选择    | 理由 |
|-------------|-----------|------------|
| **数据库** | PostgreSQL | 处理用户、房间、成员关系、消息。对于目标规模完全足够。 |
| **后端**  | Axum (Rust) | 异步、高性能、维护良好。适合规模和生态系统。 |
| **API**      | REST over HTTP | 请求/响应（发送消息、列出消息、CRUD）。简单、工具友好、可缓存。 |
| **实时通信** | WebSockets | 服务器 → 客户端推送：新消息、正在输入、在线状态。 |
