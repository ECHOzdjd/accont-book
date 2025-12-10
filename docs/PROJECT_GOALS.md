# 项目目标 - accont-book 微服务化改造 🧩

## 概述

本项目目标是将现有单体应用拆分为一套轻量级微服务，并提供清晰的职责划分、可靠的远程调用/熔断、以及异步解耦的统计系统。拆分后的服务组合将通过网关统一对外暴露接口，并使用中间件（MySQL、Nacos、RabbitMQ、Sentinel Dashboard）提供注册发现、配置、消息中间件和熔断控制台等关键能力。

---

## 服务列表与职责

### 1. 网关服务（gateway-service） — 系统统一入口 ✅

- 角色：系统对外统一大门（门面），集中拦截并路由请求。
- 核心功能：
  - 统一拦截前端请求（将默认前端 8080 端口改为网关端口，例如 9000）。
  - 路由转发：例如把 `/api/assets` 转发给 `asset-service`，`/api/trans` 转给 `transaction-service`。
  - 身份校验（可选）：在网关可以统一解析 Token 并注入用户信息到请求上下文（例如请求头或请求参数）。
  - 统一鉴权或基于网关配置的白名单、限流等策略。

---

### 2. 用户服务（user-service） — 基础数据服务 👤

- 角色：账户与用户基础数据的独立微服务。
- 来源：拆分自原单体的 `sys_user` 表和 `User` 实体。
- 核心功能：
  - 用户注册、登录认证（JWT 或其他 token 方案）。
  - 个人信息管理、资料修改、密码修改等。
  - 提供基础用户数据查询接口供其它服务调用（例如查找用户信息）。

---

### 3. 资产服务（asset-service） — 被保护的核心服务 💰

- 角色：资金相关的核心服务（类似资金池）。
- 来源：拆分自原单体的 `tb_asset` 表和 `AssetController`。
- 核心功能：
  - 账户的增删改查（开户、销户、获取余额等）。
  - 余额变更接口：专门为交易服务提供余额增减接口（例如，扣款、入账、冻结/解冻）。
- 技术亮点：
  - 乐观锁：保留 `version` 字段，避免并发扣款导致的数据竞争或超扣。
  - 数据校验与业务限制，接口应幂等与幂等 key 支持（可选）。
  - 健康检查与监控指标（保证被其它服务安全调用）。

---

### 4. 交易流水服务（transaction-service） — 记账与流量核心 💳⚡

- 角色：聚合服务，负责记账主流程与事务协调。
- 来源：拆分自原单体的 `tb_transaction` 表和 `TransactionController`。
- 核心功能：
  - 记一笔账、删除流水、查询流水列表与分页查询。
  - 通过远程调用（Feign）调用 `asset-service` 的余额变更接口，完成资金变更与记账闭环。
- 技术亮点（架构加分项）：
  - 使用 OpenFeign 作为远程调用客户端，简化对 `asset-service` 的调用。
  - Sentinel 熔断：为 Feign 接口添加熔断与降级（fallback）逻辑，当 `asset-service` 不可用或响应过慢时，返回友好提示（如“记账排队中”）或触发补偿机制，防止系统雪崩。
  - RabbitMQ 生产者：记账成功后发送 `transaction.success` 消息到队列，异步通知统计服务/分析服务。

---

### 5. 统计分析服务（statistics-service） — 异步消费者 & 报表服务 📊

- 角色：数据分析与统计服务（支持 CQRS 和读写分离思想雏形）。
- 来源：全新开发（将复杂的 SQL 统计逻辑从单体拆离）。
- 核心功能：
  - RabbitMQ 消费者：监听 `transaction.success` 消息，异步计算当月总支出/总收入等指标。
  - 提供报表查询接口：用于 Dashboard 的趋势图、饼图、明细统计等。
- 技术亮点：
  - 异步解耦：将重统计与聚合放到后台处理，不阻塞记账主流程。
  - 消息削峰填谷：使用消息队列缓冲，保持主流程响应速度。

---

## 中间件 & 基础设施

在 `docker-compose.yml` 中，运行的容器应包含：

- 业务容器（Java）：

  - `gateway-service`
  - `user-service`
  - `asset-service`
  - `transaction-service`
  - `statistics-service`

- 中间件容器：
  - `mysql`（数据存储）
  - `nacos`（服务注册与配置中心）
  - `rabbitmq`（消息队列）
  - `sentinel-dashboard`（可选：熔断与流量控制面板）

> Tip: 每个服务在启动时都应注册到 `nacos`，并从 `nacos` 获取运行时配置。

---

## 路由与端口建议

- 前端（开发环境）默认端口：8080（可不变）。
- 网关端口：建议 9000（将外部请求通过 9000 统一代理到后端服务）。
- 转发例子：
  - `/api/assets/**` -> `asset-service`
  - `/api/trans/**` -> `transaction-service`
  - `/api/users/**` -> `user-service`

---

## 通信与错误处理策略

- 远程调用：使用 OpenFeign + Ribbon（或 Spring Cloud LoadBalancer）
- 熔断与降级：Sentinel（或 Resilience4j）配合降级策略，设置合理的阈值与 fallback。交易服务在熔断时应返回 "记账排队中" 或持久化到 DB 做延后处理/告警。
- 消息队列：使用 RabbitMQ 作为异步处理通道，Producer（交易服务）-> Consumer（统计服务），保证 at-least-once 或者在可行范围内的 exactly-once 约定（幂等处理）。

---

## 数据模型拆分（迁移建议）

- `user-service`：从 `sys_user` 表抽成独立库或独立 schema，提供用户注册/登录等接口。
- `asset-service`：保留 `tb_asset` 表，进行单点变更，使用乐观锁（version 字段）保持一致性。
- `transaction-service`：保留 `tb_transaction` 表，仅负责账务流水的写入与查询。

---

## 监控、日志与追踪（推荐）

- 建议引入链路追踪（Zipkin/Jaeger）以便全链路排查。
- 统一日志格式（JSON），方便 ELK/EFK 搜索与报警。
- 每个服务应提供健康检查与 metrics（Prometheus + Grafana）。

---

## 测试与容错演练

- 编写集成测试：包含服务注册发现、远程调用熔断、消息队列消费者链路。
- Chaos 测试：模拟 `asset-service` 挂掉或延迟场景，验证 `transaction-service` 的熔断与 fallback 行为。

---

## 实施迁移的建议步骤（粗略）

1. 设计通用接口与 DTO（例如 `TransactionDTO`、`AssetDTO`、`UserDTO`）。
2. 先实现 `gateway-service` 与 `user-service`（用户相关功能），保证认证/鉴权策略到位。
3. 将 `asset-service` 与 `transaction-service` 从单体拆出，并实现 `transaction-service` 的远程调用 + 熔断逻辑。
4. 实现 `statistics-service` 的消费链路（RabbitMQ）与报表接口。
5. 逐步切流量，进行 Canary/灰度发布与回滚验证。

---

## 备用方案与可扩展点

- 如果短期内无法拆分数据库，先使用独立 schema 或行级隔离进行逻辑拆分。
- 引入网关级别的统一日志与跨域策略，保证前端与后端的安全性与可观察性。

---

如果你需要，我可以将 `docker-compose.yml` 的示例配置（包含上面提到的服务与中间件）也写出来，或把整个微服务实现的模板（Spring Boot + OpenFeign + Sentinel + RabbitMQ）放到 `accont-book` 的 `microservices` 目录中。💡

---

文档生成时间：2025-12-10
