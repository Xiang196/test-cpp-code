# test-cpp-code（中文版）

> English version: [README.md](README.md)

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
make edit S=NAME        用 $EDITOR（默认 code）打开片段
make clean              删掉 bin/ 和 .cache/
make help               完整帮助
```

片段名不用写全：`make run S=string` 只要在现有片段里唯一，就会匹配到
`cpp20-string-view`；匹配到多个会把候选列出来，让你换全名。`S=` 也接受文件名或
路径（`S=cpp20-string-view.cpp`、`S=snippets/cpp20-string-view.cpp`），所以
Tab 补全和直接粘路径都行。

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

标准优先级：**命令行 `STD=` > 片段头 `// @std:` > 默认 `c++20`**。

## 目录结构

```text
test-cpp-code/
|-- Makefile          # 入口和变量
|-- snippets/         # 你的片段：一个 .cpp 一个程序（日常唯一的编辑区）
|-- include/tc.hpp    # 可选的小断言头，零依赖
|-- tools/tc.sh       # 真正干活的引擎：list/run/watch/test/check/new
|-- bin/              # 编译产物（自动生成，已 gitignore）
`-- .cache/           # 编译/运行日志、上次结果（自动生成，已 gitignore）
```

- **新增片段零配置**：往 `snippets/` 丢个 `.cpp`，`make run` / `make list`
  立刻可用。验证一个语言特性不该先花五分钟建工程。
- **产物和日志不碍事**：生成的都进 `bin/` 和 `.cache/`，`make clean` 一次清掉。
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
