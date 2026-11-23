# test-cpp-code（中文版）

<p align="center">
  <a href="README.md">English</a> &nbsp;|&nbsp; <b>中文</b>
</p>

写 C++ 小验证片段的试验台：**一个 `.cpp` = 一个能直接跑的程序。**
`make run` 编译并运行，`make watch` 保存就重跑，`make test` 全量跑一遍并给出
通过/失败汇总。

> 已在本机 WSL 上实测：Ubuntu、g++ 15.2.0、GNU Make 4.4.1。
> 下面所有命令都在 WSL 终端里执行。
> 除这份中文说明外，所有源码、脚本和命令输出都是纯 ASCII 英文。

本仓库的源代码由 **DSH（DeepSeek Harness）** 完成，详见文末
[许可与来源](#许可与来源)。

## 30 秒上手

```bash
cd ~/src/github/test-cpp-code

make                                     # 列出当前片段
make new NAME=string-view DESC="string_view vs string"
make watch S=string-view                 # 改代码、保存，自动重编重跑
```

按 `Ctrl+C` 退出 watch。文末有个 alias，省掉每次 `cd`。

## 日常三种场景

| 你想干的事 | 命令 |
| --- | --- |
| 边改边验证一个新语法/库特性 | `make new NAME=xxx`，然后 `make watch S=xxx` |
| 打开一个已有片段改一改 | `make run S=xxx` |
| 确认全部还能编过、跑对 | `make test` |

`make run` 不带 `S=` 时会跑**最近修改**的片段，所以刚改完直接敲 `make run`
就行。

## 命令表

```text
make                    列出所有片段（默认目标）
make run S=NAME         编译并运行某个片段
make run                编译并运行最近修改的片段
make watch              盯着 snippets/，保存即重编重跑
make watch S=NAME       只盯一个片段
make test               全量编译+运行，输出通过/失败汇总
make check              只编译不运行（快速查语法）
make new NAME=NAME      新建片段（DESC="一句话" 可选）
make data S=NAME        新建 data/NAME/（文件读写片段的工作目录）
make edit S=NAME        用 $EDITOR（默认 code）打开片段
make clean              删掉 bin/、.cache/ 和生成的 data/*/out/
make commit             交互式：message + Changelog、测试、提交、推送
make commit M="msg"     同上，只是 message 预先填好
make help               完整帮助
```

片段名不用写全：`make run S=string` 只要在现有片段里唯一，就会匹配到
`cpp20-string-view`；匹配到多个会把候选列出来，让你换全名。`S=` 也接受文件名或
路径（`S=cpp20-string-view.cpp`、`S=snippets/cpp20-string-view.cpp`），所以
Tab 补全和直接粘路径都行。

## 提交

`make commit`（或 `./tools/commit.sh`）是交互式的：先列出改动，依次询问
commit message、Changelog 分类和一行条目，然后跑 `make test`、暂存、提交，最后
询问是否 push：

```bash
make commit
```

可以预先填好一部分：

```bash
./tools/commit.sh -m "docs: update default flags" \
  --changelog-category Changed \
  --changelog-entry "Document the default flags and commit workflow."
```

条目会自动插到 `## [Unreleased]` 下。因为 CI 要求除 `README.zh-CN.md` 外的被
跟踪文件都是纯 ASCII，Changelog 条目也必须是英文 ASCII。

常用选项：`--no-test`、`--no-push`、`--no-changelog`、`--tracked-only`
（不带上未跟踪文件）、`-y`（用默认值并跳过确认；除非加 `--no-push`，否则会直接
push）。

`make commit M="..."` 等价于 `./tools/commit.sh -m "..."`。

## 片段文件头约定

这三个注释都可选，但 `@desc` 建议写（`make list` 会显示它）：

```cpp
// @desc: one-line description of what this probe verifies
// @std:  c++23        <- 覆盖默认标准
// @flags: -pthread    <- 额外的编译参数（线程、特殊库等）

#include <tc.hpp>

int main() {
    tc::section("string_view");
    TC_CHECK(std::string("hello").starts_with("he"));
    TC_CHECK_EQ(std::string("abc").size(), 3u);
    return tc::summary();   // 有失败返回 1，make test 就会标红
}
```

- **要判断对错**：用 `include/tc.hpp` 里的 `TC_CHECK` / `TC_CHECK_EQ`，最后
  `return tc::summary()`。这样 `make test` 能看出哪个片段挂了。
- **只是看看输出**：不用断言，直接 `std::cout`，退出码 0 就算通过。

标准优先级：**命令行 `STD=` > 片段头 `// @std:` > 默认 `c++17`**。

## 默认编译选项

每个片段都用这组选项编译：

```text
-std=c++17 -O0 -Wall -Werror -Wextra -Wconversion -Wno-unused-result -Wvla -Wpedantic
```

- `-Werror` 把警告当错误，所以 `make test` 是严格的。
- `-Wconversion` 会报隐式窄化转换；报了就加显式 `static_cast` 或改类型。
- `-Wno-unused-result` 让 `write(2)` 这类故意忽略返回值的调用不报警。
- `-Wvla` 拒绝变长数组（GNU 扩展，不是标准 C++）。
- 片段可以用 `// @std: c++23` 提高标准；临时覆盖整套选项用 `STD=c++23`、
  `WARN="-Wall -Wextra"`、`OPT=-O2` 或 `CXXFLAGS="..."`。

## 片段命名

`make list` 按文件名排序，`make run S=...` 先精确匹配再唯一子串匹配，所以文件名
就是你要敲的那个句柄。

- **全小写 kebab-case，只用 ASCII**：`cpp23-expected.cpp`，不要 `Test.CPP`。
- **整个文件夹只用一个前缀维度**：要么按标准（`cpp17-`、`cpp20-`、`cpp23-`），
  要么按领域（`stl-`、`tpl-`、`thread-`、`perf-`、`idiom-`）。`tc-` 留给演示
  工具本身的片段。
- **后面的部分是主题**：`cpp20-string-view.cpp`、`stl-map-insert-order.cpp`、
  `thread-jthread-stop-token.cpp`。
- **控制在 40 个字符以内**，这样 `make list` 一行放得下。
- **区分的词放前面**：`S=` 是子串匹配，`string-view` 和 `string-view-trim` 都会
  被 `S=string-view` 命中，而 `S=trim` 仍然唯一。
- `@desc` 负责写清“为什么”；文件名只负责让人以后能找到它。

别用 `test.cpp`、`tmp.cpp`、`1.cpp`：名字会撞、`make run` 会歧义，而且完全看不出
这个片段在干什么。临时试验跑通后要留下的，就改名：
`git mv snippets/scratch-x.cpp snippets/cpp23-x.cpp`。

## 需要读写文件的片段

会打开文件的片段，运行时的当前目录固定为 `data/<片段名>/`，不是仓库根目录：

```text
data/
`-- cpp17-fileIO-copy-text/
    |-- input.txt      # 输入 fixture：提交到 git，小、纯文本
    `-- out/           # 程序生成：gitignore，make clean 清掉
```

规则：

- **一个片段一个目录，名字和 `.cpp` 完全相同。** `make data S=NAME` 会建好
  `data/NAME/out/`；`make run` / `make test` 也会自动创建，只读的片段就是空目录。
- **输入文件放在目录顶层，并提交到 git。** 保持小且确定：CI 在干净 clone 上跑
  `make test`，输入缺失必须让片段失败，而不是悄悄跳过。
- **输出只写进 `out/`。** 目录会自动建好且被 git 忽略，所以片段写多少文件
  `git status` 都是干净的。
- **用相对路径。** 当前目录已经是数据目录，`std::ifstream("input.txt")`、
  `std::ofstream("out/copy.txt")` 就够了，不用 `../..` 也不用绝对路径。
- **不要写到 `out/` 之外。** `make clean` 删 `bin/`、`.cache/` 和
  `data/*/out/`，fixture 永远不动。
- **`make test` 给每个片段的 stdin 是空的。** 读输入的片段必须处理 EOF
  （`if (std::cin.eof()) break;`），否则 `make test` 永远结束不了；要手动输入
  就用 `make run`。
- **改名或删除片段时，数据目录一起改。**
  `git mv snippets/old.cpp snippets/new.cpp` 加 `git mv data/old data/new`；
  不要这个片段了，就同时 `git rm -r data/old`。
- **找不到文件时先看 workdir。** `make run` 会打印本次用的工作目录，这是排查
  路径问题的第一行。

`make list` 末尾会多一行 `data fixtures:`，标出哪些片段带 fixture。

要判断生成的文件对不对，读完再 `TC_CHECK`；fixture 保持确定，`make test` 才有
意义：

```cpp
std::ifstream back("out/copy.txt");
std::string line;
TC_CHECK(static_cast<bool>(std::getline(back, line)));
```

大二进制文件（图片、压缩包）不要进 git：CI 留一个小文本 fixture，或者把这个
片段搬去单独的 CMake 工程。

## 目录结构

```text
test-cpp-code/
|-- Makefile          # 入口和变量
|-- Changelog.md      # keep-a-changelog 变更记录，每次提交都更新
|-- snippets/         # 你的片段：一个 .cpp 一个程序（日常唯一的编辑区）
|-- data/             # 每个片段的工作目录：fixture 提交，out/ 忽略
|-- include/tc.hpp    # 可选的小断言头，零依赖
|-- tools/tc.sh       # 真正干活的引擎：list/run/watch/test/check/new/data
|-- tools/commit.sh   # 交互式 message + Changelog + 测试 + 提交 + 推送
|-- bin/              # 编译产物（自动生成，已 gitignore）
`-- .cache/           # 编译/运行日志、上次结果（自动生成，已 gitignore）
```

- **新增片段零配置**：往 `snippets/` 丢个 `.cpp`，`make run` / `make list`
  立刻可用。验证一个语言特性不该先花五分钟建工程。
- **产物和日志不碍事**：生成的都进 `bin/`、`.cache/` 和 `data/*/out/`，
  `make clean` 一次清掉。
- **整个文件夹自包含**：路径都是相对的，可以把整个目录拷到别处（比如放 WSL
  家目录让编译更快，见 FAQ）。

## 变量

```bash
make run S=foo STD=c++23        # 换标准
make run S=foo OPT=-O2          # 换优化等级
make run S=foo SAN=1            # ASan + UBSan
make run S=foo ARGS="a b"       # 给片段传命令行参数
make run S=foo CXX=clang++      # 换编译器
CXXFLAGS="-I/usr/include/x" make check   # 追加编译参数
```

## 为什么这样设计

1. **一个片段一个 `main`**：编译失败、崩溃、死循环都只影响它自己；退出码就是
   “是否符合预期”的天然信号，`make test` 汇总的就是它。
2. **没有工程文件要维护**：加片段时不需要同步 CMakeLists 或 .vcxproj。
3. **Makefile 只当入口**：真正的逻辑在 `tools/tc.sh`，因为 watch 循环和解析文件头
   写在 make 里又丑又难改。加功能只改一个文件。
4. **回归一条命令**：`make test` 把“所有片段还能编、还能跑对”变成可执行的事，
   而不是靠记忆。
5. **文件读写按片段隔离**：每个片段都在 `data/<名字>/` 里运行，写文件不会弄脏
   仓库根目录，也不会踩到别的片段的 fixture，`make test` 可以反复跑。

## 什么时候该换工具

- **多文件、多 target、第三方库**（比如 GoogleTest）→ 单独建一个 CMake 工程。
  这个文件夹继续负责单文件验证，两者不冲突。
- **刷算法题要读 stdin** → 片段里用 `std::cin`；`make run S=xxx` 时直接敲输入，
  或者 `echo 1 2 | ./bin/xxx`。

## FAQ

**为什么现在放在 `~/src/github` 而不是 `/mnt/c`？**
它一开始在 `/mnt/c`（Windows 盘）上，编译一个片段要 1.2 秒左右。现在放在 WSL
原生文件系统里，编译同一个片段快了好几倍，而且它是一个正常的 git 仓库，可以
clone 到任何地方。

**额外的编译参数、头文件路径放哪？**
用 `CXXFLAGS=`（追加）或片段头的 `@flags:`；公共头放 `include/`（已经通过
`-I` 加进去了）。

**WSL 里没有 make？**
`sudo apt install build-essential`。

**`make edit` 打不开？**
它调用 `$EDITOR`，没设就用 `code`。没有 VS Code 就先
`export EDITOR=vim`（或 nano），再 `make edit S=NAME`。

**想按主题分子文件夹？**
目前只扫 `snippets/` 顶层。建议用文件名前缀分类（`cpp23-`、`stl-`、`tpl-`），
`make list` 按名字排序，天然就分好组了。

## 可选：一个 shell alias

把下面这行加到 `~/.bashrc`，以后在任何目录敲 `tc` 就行：

```bash
alias tc='make --no-print-directory -C ~/src/github/test-cpp-code'
```

```bash
tc                      # 列出片段（make 的默认目标）
tc run S=string-view
tc watch
```

## 许可与来源

MIT 许可证，见 [LICENSE](LICENSE)。

本仓库的源代码由 DSH（DeepSeek Harness）完成，由
[Xiang196](https://github.com/Xiang196) 维护。
