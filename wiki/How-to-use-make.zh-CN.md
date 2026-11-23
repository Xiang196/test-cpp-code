# 如何使用 make

<p align="center">
  <a href="https://github.com/Xiang196/test-cpp-code/wiki/How-to-use-make">English</a>
  &nbsp;|&nbsp; <b>中文</b>
</p>

`make` 是这个仓库唯一的日常入口：编译片段、运行、保存后自动重跑、全量回归、
清理生成物。不需要 CMake、Visual Studio 或工程文件。

这一页是实践指南；命令速查可以看
[README](https://github.com/Xiang196/test-cpp-code/blob/main/README.zh-CN.md)。

下面的命令都在仓库根目录执行：

```bash
cd ~/src/github/test-cpp-code
```

## 1. 准备环境

你需要 Linux 或 WSL 环境，以及：

- 支持 C++17 的 `g++`（用到 C++20/23 的片段需要对应版本）
- GNU `make`
- `git`

Ubuntu/WSL 上安装：

```bash
sudo apt install build-essential git
```

确认工具链：

```bash
g++ --version
make --version
```

如果 `make` 不存在，先装 `build-essential`。

## 2. 一分钟上手

```bash
make                                                   # 列出片段
make new NAME=cpp17-hello-world DESC="first probe"    # 新建一个
make run S=hello                                       # 编译并运行
make watch S=hello                                     # 保存就重跑
```

`make run` 不带 `S=` 时会运行最近修改的片段，所以改完代码通常直接敲
`make run` 就行。

`make watch` 按 `Ctrl+C` 退出。

## 3. 命令表

| 命令 | 作用 |
| --- | --- |
| `make` 或 `make list` | 列出所有片段、上次结果、标准、时间和描述。 |
| `make run S=NAME` | 编译并运行一个片段。 |
| `make run` | 编译并运行最近修改的片段。 |
| `make watch` | 盯着 `snippets/`、`include/` 和 `data/`，保存就重编重跑。 |
| `make watch S=NAME` | 只盯一个片段。 |
| `make test` | 全量编译并运行，输出通过/失败汇总。 |
| `make check` | 全量只编译，不运行。 |
| `make check S=NAME` | 只编译一个片段。 |
| `make new NAME=NAME DESC="..."` | 从模板创建 `snippets/NAME.cpp`。 |
| `make data S=NAME` | 为文件读写片段创建 `data/NAME/`。 |
| `make edit S=NAME` | 用 `$EDITOR`（默认 `code`）打开片段。 |
| `make clean` | 删掉 `bin/`、`.cache/` 和生成的 `data/*/out/`。 |
| `make commit` | 交互式 Changelog + 测试 + 提交 + 推送，详见单独指南。 |
| `make help` | 显示完整内置帮助。 |

`S=` 不用写全，接受片段名、文件名、路径或唯一子串：

```bash
make run S=cpp20-string-view
make run S=cpp20-string-view.cpp
make run S=snippets/cpp20-string-view.cpp
make run S=string
```

如果子串命中多个片段，`make` 会列出候选，让你换更长的名字。

## 4. 日常流程

### 4.1 新建片段

```bash
make new NAME=cpp20-string-view DESC="string_view vs string"
```

它会创建 `snippets/cpp20-string-view.cpp`，里面带头部注释和能跑的 `main`。
改完运行：

```bash
make run S=string-view
```

只扫描 `snippets/` 顶层，所以片段文件保持平铺。

### 4.2 边改边看

```bash
make watch S=string-view
```

保存文件就会重新编译并运行。不带 `S=` 时，watch 跟着最近修改的片段走。
`make watch` 也会监听 `include/` 里的文件和 `data/` 下已提交的 fixture。

### 4.3 全量回归

```bash
make test
```

每个片段都会编译并运行；进程退出码为 0 就算通过。末尾汇总会列出失败的
片段，`make test` 自身也返回非 0，所以可以直接当 CI 门禁。

单独跑失败的片段：

```bash
make run S=the-failing-name
```

额外安全检查：

```bash
make test SAN=1          # AddressSanitizer + UndefinedBehaviorSanitizer
```

### 4.4 只查语法

```bash
make check               # 全部片段
make check S=string      # 单个片段
```

不运行程序，适合快速查编译错误。

### 4.5 清理生成物

```bash
make clean
```

删除 `bin/`、`.cache/` 和生成的 `data/*/out/`，不会动片段、头文件和 fixture。

## 5. 需要读写文件的片段

每个片段运行时的当前目录都是 `data/<片段名>/`。这个目录和 `out/` 子目录会在
需要时自动创建：

```text
data/
`-- cpp17-fileIO-copy-text/
    |-- input.txt      # fixture：提交到 git
    `-- out/           # 程序输出：gitignore
```

也可以显式创建：

```bash
make data S=cpp17-fileIO-copy-text
```

片段里直接用相对路径：

```cpp
std::ifstream in("input.txt");
std::ofstream out("out/copy.txt");
```

规则：

- 输入 fixture 放 `data/NAME/` 顶层，并提交到 git。
- 程序生成的文件只写 `out/`，它被 git 忽略。
- `make clean` 清 `out/`，永远不动 fixture。
- `make run` 会打印本次工作目录；找不到文件先看这一行。
- fixture 保持小而确定，`make test` 才可重复。

`make test` 给每个片段的 stdin 是空的。读输入的片段必须把 EOF 当作输入结束
并退出；要手动输入就用 `make run`。

## 6. 编译和运行变量

这些变量可以直接写在命令行：

| 变量 | 默认值 | 示例 |
| --- | --- | --- |
| `STD` | `c++17` | `make run S=foo STD=c++23` |
| `OPT` | `-O0` | `make run S=foo OPT=-O2` |
| `WARN` | `-Wall -Werror -Wextra -Wconversion -Wno-unused-result -Wvla -Wpedantic` | `make check WARN="-Wall -Wextra"` |
| `SAN` | `0` | `make run S=foo SAN=1` |
| `ARGS` | 空 | `make run S=foo ARGS="one two"` |
| `CXX` | `g++` | `make run S=foo CXX=clang++` |
| `CXXFLAGS` | 空 | `CXXFLAGS="-I/opt/include" make check` |

标准优先级：

1. 命令行 `STD=`
2. 片段头部的 `// @std:`
3. 默认 `c++17`

## 7. 片段头部

头部注释都是可选的，但 `@desc` 建议写，`make list` 会显示：

```cpp
// @desc: what this snippet verifies
// @std:  c++20
// @flags: -pthread

#include <tc.hpp>

int main() {
    tc::section("example");
    TC_CHECK(1 + 1 == 2);
    TC_CHECK_EQ(2 + 2, 4);
    return tc::summary();
}
```

- `@desc`：一句话描述。
- `@std`：只给这个片段提高标准。
- `@flags`：追加编译参数，例如 `-pthread`。

片段可以用 `TC_CHECK` / `TC_CHECK_EQ` 加 `return tc::summary()` 报告通过/失败；
也可以只打印输出并返回 0。

## 8. 片段命名

- 全小写 kebab-case ASCII：`cpp20-string-view.cpp`。
- 整个目录只用一种前缀维度：标准（`cpp17-`、`cpp20-`、`cpp23-`）或领域
  （`stl-`、`tpl-`、`thread-`、`perf-`）。`tc-` 留给演示工具本身的片段。
- 名字控制在 40 个字符以内。
- 区分词放前面，因为 `S=` 是子串匹配。
- 别用 `test.cpp`、`tmp.cpp`、`1.cpp`。
- 改名时，同步改 `data/<名字>/` 目录。

## 9. 排查

**`make: command not found`**

```bash
sudo apt install build-essential
```

**`make edit` 打不开**

它调用 `$EDITOR`，没设就用 `code`。用终端编辑器：

```bash
export EDITOR=vim
make edit S=hello
```

**`no snippet matches` 或 `ambiguous match`**

`S=` 不唯一。先 `make list`，再多写几个字符。

**`cannot open input.txt`**

片段需要 fixture。检查 `data/<名字>/input.txt`，并看 `make run` 打印的
`workdir:` 行。

**`make test` 卡住**

片段在读 stdin 且没有处理 EOF。把 EOF 当作输入结束，或者用 `make run` 手动输入。

**`std::jthread is not a member of std` 之类**

片段需要更新的标准。在头部加 `// @std: c++20`（或 `c++23`），并确认编译器支持。

**警告变成编译错误**

默认带 `-Werror`。修警告或加显式类型转换，不要为了一个片段删掉严格选项。

## 10. 可选 shell alias

把下面这行加到 `~/.bashrc`，之后在任何目录都能用 `tc`：

```bash
alias tc='make --no-print-directory -C ~/src/github/test-cpp-code'
```

```bash
tc
tc run S=string-view
tc test
```

## 另见

- [README（中文）](https://github.com/Xiang196/test-cpp-code/blob/main/README.zh-CN.md)
- [README（English）](https://github.com/Xiang196/test-cpp-code#readme)
- [如何使用 commit 脚本](https://github.com/Xiang196/test-cpp-code/wiki/How-to-use-the-commit-script.zh-CN)
- [Changelog](https://github.com/Xiang196/test-cpp-code/blob/main/Changelog.md)
