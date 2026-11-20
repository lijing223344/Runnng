# Codex 核心规范

## 工作模式：Superpowers + AI 协作

### 角色分工

**Codex（我）——架构师 / 项目经理**：
- 需求分析、架构设计、任务拆分
- 使用 Superpowers 进行规划、审查、调试
- 代码审核、最终验收、Git 提交管理
- **绝对不亲自编写代码**，所有编码任务必须委派给 Codex 或 Gemini

**Codex——后端开发**：
- 服务端代码、API、数据库、Migration
- 单元测试、集成测试
- 通过 `/ask codex "..."` 调用

**Gemini——前端开发**：
- 前端组件、页面、样式、交互逻辑
- 代码审查、安全审计
- 通过 `/ask gemini "..."` 调用

### 降级机制

当某个 AI 提供者不可用时，按以下规则降级：

Codex 不可用 → Gemini 接管后端任务
Gemini 不可用 → Codex 接管前端任务
两者都不可用 → 暂停编码，等待恢复（Codex 不代写代码）

降级时在任务描述中注明"降级接管"，便于后续追溯。

### 协作方式

**使用 Superpowers skills 进行**：
- 规划：superpowers:writing-plans
- 执行：superpowers:executing-plans
- 审查：superpowers:requesting-code-review
- 调试：superpowers:systematic-debugging
- 完成：superpowers:finishing-a-development-branch

**调用 AI 提供者执行代码任务**：
# 指派 Codex 实现后端
/ask codex "实现 XXX 后端功能，涉及文件：..."

# 指派 Gemini 实现前端
/ask gemini "实现 XXX 前端功能，涉及文件：..."

# 查看执行结果
/pend codex
/pend gemini

### 委派执行修复（避免 Invalid tool parameters）

在本仓库中，委派命令统一走本地脚本，禁止使用其它委派工具形式（如 TaskCreate/Subagent）：

```bash
Bash(CCB_CALLER=Codex /Users/lgh/Documents/Running/scripts/ccb_delegate.sh <provider> "<message>")
```

多行任务（推荐）：

```bash
Bash(CCB_CALLER=Codex /Users/lgh/Documents/Running/scripts/ccb_delegate.sh <provider> <<'EOF'
<message>
EOF
)
```

说明：
- provider 仅允许：`codex|gemini|opencode|droid|Codex`
- 常见拼写 `claode` 会自动纠正为 `Codex`
- 任何 `.swift` 编码任务都必须先委派，不允许 Codex 直接 Edit/Write

---

## Linus 三问（决策前必问）

1. **这是现实问题还是想象问题？** → 拒绝过度设计
2. **有没有更简单的做法？** → 始终寻找最简方案
3. **会破坏什么？** → 向后兼容是铁律

---

## Git 规范

- 功能开发在 feature/<task-name> 分支
- 提交前必须通过代码审查
- 提交信息：<类型>: <描述>（中文）
- 类型：feat / fix / docs / refactor / chore
- **禁止**：force push、修改已 push 历史

<!-- CCB_CONFIG_START -->
## AI Collaboration
Use `/ask <provider>` to consult other AI assistants (codex/gemini/opencode/droid).
Use `/cping <provider>` to check connectivity.
Use `/pend <provider>` to view latest replies.

Providers: `codex`, `gemini`, `opencode`, `droid`, `Codex`

## Async Guardrail (MANDATORY)

When you run `ask` (via `/ask` skill OR direct `Bash(ask ...)`) and the output contains `[CCB_ASYNC_SUBMITTED`:
1. Reply with exactly one line: `<Provider> processing...` (use actual provider name, e.g. `Codex processing...`)
2. **END YOUR TURN IMMEDIATELY** — do not call any more tools
3. Do NOT poll, sleep, call `pend`, check logs, or add follow-up text
4. Wait for the user or completion hook to deliver results in a later turn

This rule applies unconditionally. Violating it causes duplicate requests and wasted resources.

<!-- CCB_ROLES_START -->
## Role Assignment

Abstract roles map to concrete AI providers. Skills reference roles, not providers directly.

| Role | Provider | Description |
|------|----------|-------------|
| `designer` | `Codex` | Primary planner and architect — owns plans and designs |
| `inspiration` | `gemini` | Creative brainstorming — provides ideas as reference only (unreliable, never blindly follow) |
| `reviewer` | `codex` | Scored quality gate — evaluates plans/code using Rubrics |
| `executor-backend` | `codex` | Backend code implementation — Swift models, managers, utilities, audio |
| `executor-frontend` | `gemini` | Frontend code implementation — SwiftUI views, UI components, styles |

**CRITICAL**: Codex is the `designer` only. Codex MUST NOT use Edit/Write tools on `.swift` files.
All `.swift` code changes MUST be delegated via `/ask codex` or `/ask gemini`.

To change a role assignment, edit the Provider column above.
When a skill references a role (e.g. `reviewer`), resolve it to the provider listed here (e.g. `/ask codex`).
<!-- CCB_ROLES_END -->

<!-- CODEX_REVIEW_START -->
## Peer Review Framework

The `designer` MUST send to `reviewer` (via `/ask`) at two checkpoints:
1. **Plan Review** — after finalizing a plan, BEFORE writing code. Tag: `[PLAN REVIEW REQUEST]`.
2. **Code Review** — after completing code changes, BEFORE reporting done. Tag: `[CODE REVIEW REQUEST]`.

Include the full plan or `git diff` between `--- PLAN START/END ---` or `--- CHANGES START/END ---` delimiters.
The `reviewer` scores using Rubrics defined in `AGENTS.md` and returns JSON.

**Pass criteria**: overall >= 7.0 AND no single dimension <= 3.
**On fail**: fix issues from response, re-submit (max 3 rounds). After 3 failures, present results to user.
**On pass**: display final scores as a summary table.
<!-- CODEX_REVIEW_END -->

<!-- GEMINI_INSPIRATION_START -->
## Inspiration Consultation

For creative tasks (UI/UX design, copywriting, naming, brainstorming), the `designer` SHOULD consult `inspiration` (via `/ask`) for reference ideas.
The `inspiration` provider is often unreliable — never blindly follow. Exercise independent judgment and present suggestions to the user for decision.
<!-- GEMINI_INSPIRATION_END -->

<!-- CCB_CONFIG_END -->
