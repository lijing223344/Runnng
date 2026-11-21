# 项目核心规范

## 工作模式：单 Agent 直接实现 + 可选多 Agent 协作

### 默认模式（当前生效）

当前 Agent（ZCode）直接负责全流程：需求分析、架构设计、任务拆分、编码实现、测试验证、代码审查与 Git 提交管理。

- `.swift` 及其他代码文件**可以直接 Edit/Write**，无需委派
- 背景：多 Agent 委派工具链（`ask` CLI / CCB）在本机缺失，原"设计者绝不写代码"的强制分工会导致编码完全停滞，已于 2026-11-21 经用户确认废除

### 可选多 Agent 协作（仅工具链可用时）

**委派前必须先验证**：`which ask` 找到 CLI 才允许委派；找不到则直接自己实现，不等待、不暂停编码。

```bash
CCB_CALLER=Zcode /Users/lgh/Documents/Running/scripts/ccb_delegate.sh <provider> <<'EOF'
<message>
EOF
```

- provider 仅允许：`codex|gemini|opencode|droid|claude`
- 委派是**加速手段而非质量门槛**：适合大型、可并行的独立任务
- 任何委派产出的代码仍由当前 Agent 审查后合并，对外部产出不免责

### 质量把关（替代外部评审）

- 改动前明确方案；改动后逐文件复查 `git diff`
- 编译验证必须通过（xcodebuild，模拟器 SDK）
- 相关单元/UI 测试保持全绿
- 涉及 UI 行为的修复，默认在模拟器验证，勿用真机

---

## Linus 三问（决策前必问）

1. **这是现实问题还是想象问题？** → 拒绝过度设计
2. **有没有更简单的做法？** → 始终寻找最简方案
3. **会破坏什么？** → 向后兼容是铁律

---

## Git 规范

- 功能开发在 feature/<task-name> 分支
- 提交前必须通过代码审查（工具链可用时外部评审，否则当前 Agent 自审）
- 提交信息：<类型>: <描述>（中文）
- 类型：feat / fix / docs / refactor / chore
- **禁止**：force push、修改已 push 历史

<!-- CCB_CONFIG_START -->
## AI Collaboration
> 2026-11-21 起工具链缺失（`ask` not found）。以下命令仅在 `which ask` 恢复后可用；不可用时由当前 Agent 直接实现。

Use `/ask <provider>` to consult other AI assistants (codex/gemini/opencode/droid).
Use `/cping <provider>` to check connectivity.
Use `/pend <provider>` to view latest replies.

Providers: `codex`, `gemini`, `opencode`, `droid`, `claude`

## Async Guardrail (MANDATORY when ask is used)

When you run `ask` (via `/ask` skill OR direct `Bash(ask ...)`) and the output contains `[CCB_ASYNC_SUBMITTED`:
1. Reply with exactly one line: `<Provider> processing...` (use actual provider name, e.g. `Codex processing...`)
2. **END YOUR TURN IMMEDIATELY** — do not call any more tools
3. Do NOT poll, sleep, call `pend`, check logs, or add follow-up text
4. Wait for the user or completion hook to deliver results in a later turn

This rule applies only when `ask` actually ran and submitted. Violating it causes duplicate requests and wasted resources.

<!-- CCB_ROLES_START -->
## Role Assignment (advisory, optional)

Roles below are **optional acceleration targets**, used only when the ask toolchain is available
(verify with `which ask` first). The current Agent fulfills every role by default, including
direct Edit/Write on `.swift` files — the former "designer must not code" mandate is revoked.

| Role | Provider | Description |
|------|----------|-------------|
| `inspiration` | `gemini` | Creative brainstorming — reference only (unreliable, never blindly follow) |
| `executor-backend` | `codex` | Optional parallel implementer — Swift models, managers, utilities, audio |
| `executor-frontend` | `gemini` | Optional parallel implementer — SwiftUI views, UI components, styles |
<!-- CCB_ROLES_END -->

<!-- CODEX_REVIEW_START -->
## Peer Review (optional)

Default: current Agent self-reviews (diff pass + build + tests) before reporting done.

When the ask toolchain is available, an external scored review may additionally be requested
via `/ask codex` with `[CODE REVIEW REQUEST]` and the `git diff` between
`--- CHANGES START/END ---` delimiters. Pass criteria: overall >= 7.0 AND no dimension <= 3.
<!-- CODEX_REVIEW_END -->

<!-- GEMINI_INSPIRATION_START -->
## Inspiration Consultation (optional)

For creative tasks, consulting `inspiration` (via `/ask gemini`) is optional and only when the
toolchain is available. Its output is often unreliable — never blindly follow; exercise
independent judgment and present suggestions to the user for decision.
<!-- GEMINI_INSPIRATION_END -->

<!-- CCB_CONFIG_END -->
