# cached_ctest

Incremental test runner for CMake/CTest that only runs tests whose executables have been rebuilt.

## 概述

在开发过程中，频繁运行完整的测试套件会浪费大量时间。`cached_ctest` 通过比较测试可执行文件与锚点文件的时间戳，只运行那些源代码被修改、重新编译过的测试，大幅提升开发效率。

### 核心思路

1. **构建时更新锚点** - 每次运行 `ninja` 或 `make` 时，锚点文件的时间戳会自动更新
2. **智能检测修改** - 测试可执行文件只有在源代码修改时才会被重新编译
3. **增量运行** - `cached_ctest` 只运行那些比锚点新的测试，其他测试被缓存跳过

## 功能特性

- ✅ 基于时间戳的增量测试
- ✅ 与标准 CTest 完全兼容
- ✅ 支持正则表达式过滤（`-R` 和 `-E`）
- ✅ 纯 Shell 脚本实现，无额外运行时依赖
- ✅ 跨平台支持（Linux 和 macOS）
- ✅ 详细输出和 Dry-run 模式
- ✅ 自动锚点管理，无需手动干预

## 依赖要求

- **CMake** >= 3.15
- **jq** - JSON 处理工具
- **ctest** - 通常随 CMake 一起安装
- **构建工具** - Ninja 或 Make

### 安装 jq

```bash
# Ubuntu/Debian
sudo apt-get install jq

# macOS
brew install jq

# Fedora/RHEL
sudo dnf install jq
```

## 快速开始

### 1. 运行示例项目

```bash
cd example
mkdir build && cd build

# 配置项目
cmake ..

# 构建项目（会自动生成锚点文件）
cmake --build .

# 首次运行 - 所有测试都会执行
../cached_ctest
```

### 2. 体验增量测试

```bash
# 再次运行 - 所有测试被缓存，不执行
../cached_ctest
# 输出: Tests to run: 0, Tests cached: 5

# 修改源代码
touch ../src/math_utils.cpp

# 重新构建
cmake --build .

# 增量运行 - 只运行依赖 math_utils 的测试
../cached_ctest
# 输出: Tests to run: 2, Tests cached: 3
```

## 使用方法

### 集成到你的项目

#### 步骤 1: 复制文件

```bash
# 复制 CMake 模块
cp -r cmake/ your_project/

# 复制 cached_ctest 脚本
cp cached_ctest your_project/
chmod +x your_project/cached_ctest
```

#### 步骤 2: 修改 CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.15)
project(YourProject CXX)

enable_testing()

# 包含 CachedCTest 模块
list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
include(CachedCTest)

# 初始化
cached_ctest_init()

# 添加你的库和测试
add_executable(my_test tests/my_test.cpp)

# 使用 cached_ctest_add_test 替代 add_test
cached_ctest_add_test(
    NAME my_test
    COMMAND my_test
)

# 完成（必须在所有测试注册后调用）
cached_ctest_finalize()
```

#### 步骤 3: 使用

```bash
cd build

# 构建
cmake --build .

# 运行测试
../cached_ctest
```

### 命令行选项

```bash
cached_ctest [options]

Options:
  -R <regex>       Run tests matching regex (include filter)
  -E <regex>       Exclude tests matching regex (exclude filter)
  -V, --verbose    Verbose output (show each test's status)
  --dry-run        Show which tests would run without executing
  -h, --help       Show help message
  --version        Show version information

Examples:
  cached_ctest                    # Run all modified tests
  cached_ctest -R "unit_.*"       # Run modified unit tests
  cached_ctest -E "slow"          # Exclude slow tests
  cached_ctest --verbose          # Show detailed status
  cached_ctest --dry-run          # Preview without running
```

## TDD 演示场景

以下是使用示例项目演示的测试驱动开发场景：

### 场景 1: 初始构建

```bash
cd example/build
cmake ..
ninja
../cached_ctest
```

**预期结果**：
- ✅ 所有 5 个测试运行（首次构建）
- ✅ 锚点文件创建
- ✅ 所有测试通过

### 场景 2: 无修改的重复运行

```bash
../cached_ctest
```

**预期结果**：
```
Cached CTest v1.0.0
Checking 5 registered tests...

Summary:
  Tests to run: 0
  Tests cached: 5

No tests need to run (all cached).
```

### 场景 3: 修改单个源文件

```bash
# 修改 math 相关源代码
touch ../src/math_utils.cpp
ninja
../cached_ctest
```

**预期结果**：
- ✅ 运行 `test_math_add` 和 `test_math_multiply`（依赖 math_utils）
- ✅ 运行 `test_integration`（也依赖 math_utils）
- ✅ 缓存 `test_string_reverse` 和 `test_string_concat`

### 场景 4: 使用包含过滤器

```bash
touch ../src/*.cpp
ninja
../cached_ctest -R "math_.*"
```

**预期结果**：
- ✅ 只运行 `test_math_add` 和 `test_math_multiply`
- ✅ 忽略 string 相关测试（即使它们被修改）

### 场景 5: 使用排除过滤器

```bash
../cached_ctest -E "integration"
```

**预期结果**：
- ✅ 运行除 `test_integration` 外的所有修改测试
- ✅ 单元测试和集成测试分离运行

### 场景 6: Dry-run 模式

```bash
../cached_ctest --dry-run
```

**预期结果**：
```
Dry run mode - would run these tests:
  - test_math_add
  - test_math_multiply
  - test_integration
```

### 场景 7: Verbose 模式

```bash
../cached_ctest --verbose
```

**预期结果**：
```
Cached CTest v1.0.0
Checking 5 registered tests...

Modified: test_math_add
Modified: test_math_multiply
Cached:   test_string_reverse
Cached:   test_string_concat
Modified: test_integration

Summary:
  Tests to run: 3
  Tests cached: 2
...
```

## API 文档

### CMake 函数

#### `cached_ctest_init()`

初始化 cached_ctest 系统。必须在任何 `cached_ctest_add_test()` 调用之前执行。

**作用**：
- 创建 `.cached_ctest/` 元数据目录
- 初始化锚点文件
- 设置锚点自动更新机制

**用法**：
```cmake
cached_ctest_init()
```

#### `cached_ctest_add_test()`

注册一个测试并记录元数据。包装标准的 `add_test()`，保持完全兼容。

**参数**：
- `NAME` - 测试名称（必需）
- `COMMAND` - 可执行文件和参数（必需）
- `WORKING_DIRECTORY` - 工作目录（可选，默认为 `CMAKE_BINARY_DIR`）

**用法**：
```cmake
cached_ctest_add_test(
    NAME my_test
    COMMAND my_test --arg1 --arg2
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}/tests
)
```

#### `cached_ctest_finalize()`

完成 cached_ctest 设置。必须在所有测试注册后调用。

**作用**：
- 合并所有测试元数据到单一 JSON 文件
- 设置依赖关系确保锚点在所有测试构建后更新

**用法**：
```cmake
cached_ctest_finalize()
```

## 工作原理

### 时间戳比较机制

1. **构建阶段**：
   - CMake 配置时生成每个测试的元数据（JSON 文件）
   - 每次构建时，锚点文件通过 `touch` 命令更新时间戳
   - 锚点更新依赖于所有测试可执行文件，确保构建完成后才更新

2. **测试阶段**：
   - `cached_ctest` 读取元数据文件
   - 对每个测试，比较可执行文件的 `mtime` 与锚点的 `mtime`
   - 如果 `可执行文件 mtime > 锚点 mtime`，标记为"需要运行"
   - 应用过滤器（`-R` 和 `-E`）
   - 构建 ctest 过滤正则并运行

3. **成功后**：
   - 如果所有测试通过，更新锚点时间戳
   - 下次运行时，未修改的测试会被缓存

### 元数据格式

生成在 `build/.cached_ctest/tests_metadata.json`：

```json
{
  "tests": [
    {
      "name": "test_math_add",
      "executable": "/path/to/build/test_math_add",
      "working_directory": "/path/to/build"
    }
  ],
  "metadata_version": "1.0",
  "generated_at": "2026-02-20T12:00:00"
}
```

## 已知限制

1. **需要 jq** - 必须安装 `jq` 工具用于 JSON 解析
2. **时间戳精度** - 使用秒级时间戳，对大多数场景足够
3. **不支持交叉编译** - 假设测试在本地运行
4. **文件系统依赖** - 依赖于准确的文件修改时间戳

## 故障排除

### 问题：元数据文件未找到

```
Error: Metadata file not found: .cached_ctest/tests_metadata.json
```

**解决方案**：
1. 检查是否调用了 `cached_ctest_init()` 和 `cached_ctest_finalize()`
2. 确保运行了 `cmake` 配置和 `cmake --build .` 构建

### 问题：所有测试总是运行

**可能原因**：
1. 锚点文件不存在或无法访问
2. 时间戳被手动修改
3. 每次构建都清理了构建目录

**解决方案**：
- 不要使用 `ninja clean` 后直接运行测试，应重新构建
- 检查 `.cached_ctest/anchor_timestamp` 文件权限

### 问题：jq 未安装

```
Error: jq is required but not installed.
```

**解决方案**：安装 jq（见"依赖要求"章节）

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License

## 致谢

本项目受到以下启发：
- CMake/CTest 的测试框架
- Ninja 的增量构建机制
- Make 的时间戳比较原理
