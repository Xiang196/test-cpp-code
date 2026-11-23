# 如何使用 commit 脚本

<p align="center">
  <a href="https://github.com/Xiang196/test-cpp-code/wiki/How-to-use-the-commit-script">English</a>
  &nbsp;|&nbsp; <b>中文</b>
</p>

`make commit`（或 `./tools/commit.sh`）是交互式提交助手：收集 commit message
和 `Changelog.md` 条目，跑测试，暂存文件，提交，最后询问是否 push。

日常提交用它；需要拆分提交、改历史或做脚本不支持的事时，直接用 `git`。

## 1. 它做什么

一次运行会：

1. 列出改动，询问是否包含未跟踪文件；
2. 询问一行 commit message；
3. 询问 Changelog 分类和一行条目；
4. 显示预览并确认；
5. 运行 `make test`；
6. 把条目插到 `Changelog.md` 的 `## [Unreleased]` 下；
7. 暂存并提交；
8. 询问是否推送当前分支。

测试失败时不会提交，也不会改 `Changelog.md`。

## 2. 开始前

确认 git 身份：

```bash
git config user.name
git config user.email
```

如果为空：

```bash
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

要 push 的话，当前分支需要 `origin` 远端。脚本推送前会询问；`--no-push`
可以完全跳过。

`Changelog.md` 必须存在，并且包含 `## [Unreleased]`。仓库里已经有了。

## 3. 快速开始

```bash
make commit
```

或直接调用脚本：

```bash
./tools/commit.sh
```

预填 commit message：

```bash
make commit M="feat: add string trim"
# 等价于
./tools/commit.sh -m "feat: add string trim"
```

`make commit` 仍然会问 Changelog 条目和确认；`M=` 只跳过 message 输入。

## 4. 交互流程

### 4.1 改动

脚本先显示 `git status --short` 和统计：

```text
== Changes ==
 M README.md
?? snippets/cpp20-string-view.cpp

  staged: 0, modified: 1, untracked: 1
```

有未跟踪文件时会问：

```text
  Stage all changes, including untracked files? [Y/n]
```

- 回车或 `y`：`git add -A`，全部提交。
- 输入 `n`：只暂存 tracked 改动（`git add -u`），未跟踪文件保持原样。

加 `--tracked-only` 可以跳过这个问题，直接只提交 tracked 改动。加 `-y`
时默认包含所有改动。

如果选中的模式里没有任何 tracked 改动，脚本会直接报错，避免只提交一条新的
Changelog 条目。

### 4.2 Commit message

只输入一行：

```text
== Commit message ==
  Convention: type: short summary
  Types: feat, fix, docs, refactor, perf, test, chore
  > feat: add string trim
```

建议使用 Conventional Commits 风格。超过 72 个字符会给出提示。脚本提交的是
单行 message，不会额外添加正文。

### 4.3 Changelog 条目

先选分类：

```text
== Changelog ==
  Add one bullet under [Unreleased] in Changelog.md.
    1) Added  <- default
    2) Changed
    3) Fixed
    4) Removed
    5) Deprecated
    6) Security
  Category [1]:
```

默认分类根据 message 前缀推断：

| message 前缀 | 默认分类 |
| --- | --- |
| `feat:` / `feature:` | Added |
| `fix:` / `bugfix:` / `hotfix:` | Fixed |
| `remove:` / `revert:` | Removed |
| 其他 | Changed |

然后输入条目：

```text
  Entry [add string trim]:
```

默认值是去掉可识别前缀后的 message，直接回车即可。

条目会插到 `## [Unreleased]` 下对应 `###` 分类里。分类不存在时，脚本会在
Unreleased 末尾创建它。条目必须是一行可打印 ASCII，因为 CI 要求除
`README.zh-CN.md` 和 `wiki/*.zh-CN.md` 外的被跟踪文件都是纯 ASCII。

如果 `[Unreleased]` 下已经有完全相同的条目，脚本会跳过，不会重复添加。

### 4.4 预览和确认

脚本会汇总接下来要做的事：

```text
== Ready ==
  message:   feat: add string trim
  changelog: ### Added
             - add string trim
  stage:     all
  tests:     make test
  Continue? [Y/n]
```

输入 `n` 会中止，不暂存也不提交。

### 4.5 测试

脚本运行：

```bash
make test
```

测试时会 unset `STD` 和 `TC_FORCE_STD`，让每个片段使用自己的 `// @std:`
头，而不是被嵌套的 make 强制成 C++17。

测试失败时脚本以状态码 2 退出，不提交，也不改 `Changelog.md`。修好再跑一次。

只有确实需要时才用 `--no-test`；CI 仍然会跑测试。

### 4.6 写 Changelog、暂存、提交

测试通过后，脚本：

1. 把条目写进 `Changelog.md`；
2. 用 `git add -A`（全部）或 `git add -u`（仅 tracked）暂存；
3. 打印暂存 diffstat；
4. 执行 `git commit -m "<message>"`。

示例：

```text
== Stage ==
 Changelog.md    | 1 +
 README.md       | 3 ++-
 snippets/foo.cpp | 20 +++++++++
 3 files changed, 24 insertions(+), 1 deletion(-)

== Commit ==
[main 1a2b3c4] feat: add string trim
```

### 4.7 推送

除非传了 `--no-push`，否则会问：

```text
  Push to origin/main? [Y/n]
```

- 回车或 `y`：执行 `git push -u origin <branch>`。
- `n`：只保留本地提交。

加 `-y` 会跳过这个询问并直接推送。想完全非交互、又不想推送，就组合
`-y --no-push`。

如果当前是 detached HEAD，脚本会警告并跳过推送。推送失败（网络、凭据、分支
被拒绝）时，提交已经在本机，脚本以非 0 退出。

## 5. 选项

| 选项 | 含义 |
| --- | --- |
| `-m MSG`、`--message MSG` | 使用指定 commit message，不再询问。 |
| `--changelog-category CAT` | 分类：Added、Changed、Fixed、Removed、Deprecated、Security，大小写不敏感。 |
| `--changelog-entry TEXT` | 一行 Changelog 条目，跳过条目输入。 |
| `--no-changelog` | 不修改 `Changelog.md`。 |
| `--tracked-only` | 只暂存 tracked 改动，保留未跟踪文件。 |
| `--no-test` | 跳过 `make test`。 |
| `--no-push` | 只提交，不推送。 |
| `-y`、`--yes` | 接受确认和 Changelog 默认值；不加 `--no-push` 时会自动推送。 |
| `-h`、`--help` | 显示内置帮助。 |

脚本也接受直接传 message，兼容旧写法：

```bash
./tools/commit.sh "docs: update examples"
```

## 6. 非交互写法

完全自动、只本地提交、自定义 Changelog：

```bash
./tools/commit.sh \
  -m "fix: stop double free in parser" \
  --changelog-category Fixed \
  --changelog-entry "Stop a double free when the parser rejects input." \
  --tracked-only -y --no-push
```

完全自动并推送：

```bash
./tools/commit.sh -m "docs: update make guide" -y
```

提交所有改动但不更新 Changelog：

```bash
./tools/commit.sh -m "chore: refresh CI cache" --no-changelog -y --no-push
```

`--no-changelog` 是逃生口。项目约定是每次提交都更新 `Changelog.md`。

## 7. 暂存规则

- 默认：`git add -A`，包含未跟踪文件。
- `--tracked-only`：`git add -u`，只处理 tracked 的修改和删除。
- 你已经暂存的文件会保持暂存；脚本不会取消暂存。
- `make clean` 的产物（`bin/`、`.cache/`、`data/*/out/`）已被忽略，不会提交。
- 如果只有未跟踪文件，又选了 tracked-only，脚本会停下：没有 tracked 改动可提交。

## 8. 排查

**`nothing to commit (working tree clean)`**

没有改动，脚本直接以 0 退出。

**`no tracked changes to commit`**

选了 tracked-only，但所有改动都是未跟踪的。要么让脚本包含未跟踪文件，要么先
`git add` 想提交的文件。

**`Changelog.md has no '## [Unreleased]' section`**

恢复这个 section，或手动添加。脚本不会猜旧条目该放哪。

**`Changelog.md must stay ASCII`**

Changelog 条目用英文。commit message 本身可以是中文，但 Changelog 条目不行。

**`make test` 失败**

没有提交。根据输出找到失败片段，用 `make run S=名字` 单独跑，修好再试。
`--no-test` 只作为明确选择的逃生口。

**`Could not read from remote repository` / push 被拒**

提交已经在本机。修凭据或先 pull/rebase，再 `git push`。

**Changelog 条目太长**

条目会写成一行 bullet。保持简短，细节放 commit message、README 或 wiki。

## 另见

- [如何使用 make](https://github.com/Xiang196/test-cpp-code/wiki/How-to-use-make.zh-CN)
  （也包含用 `make wiki` 发布 wiki）
- [Changelog](https://github.com/Xiang196/test-cpp-code/blob/main/Changelog.md)
- [README（中文）](https://github.com/Xiang196/test-cpp-code/blob/main/README.zh-CN.md)
- [README（English）](https://github.com/Xiang196/test-cpp-code#readme)
