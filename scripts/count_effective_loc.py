#!/usr/bin/env python3
"""按赛事口径统计「有效 MoonBit 源码量」。

口径来自赛事驳回通知：
    有效 MoonBit 源码量 = 除去空行和测试

本脚本给出两个数字：
  1. 非空行，扣除测试文件                —— 通知的直接口径
  2. 再扣除注释行（以 // 或 /// 开头）    —— 更保守的口径

之所以同时给出两个，是因为"注释算不算"存在解释空间；
两个口径都能核实，比只报一个更诚实。

用法：
    python scripts/count_effective_loc.py [仓库根目录]
"""

import pathlib
import sys

SKIP_DIRS = {"_build", ".git", ".mooncakes", "target", "node_modules"}


def is_test(rel: str) -> bool:
    return rel.endswith("_test.mbt") or rel.endswith("_wbtest.mbt")


def main() -> None:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".")

    impl_rows = []
    test_rows = []
    tot_nonblank = tot_code = tot_test = 0

    for path in sorted(root.rglob("*.mbt")):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        rel = path.relative_to(root).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines()
        nonblank = sum(1 for l in lines if l.strip())
        code = sum(
            1 for l in lines if l.strip() and not l.strip().startswith("//")
        )
        if is_test(rel):
            test_rows.append((rel, nonblank))
            tot_test += nonblank
        else:
            impl_rows.append((rel, len(lines), nonblank, code))
            tot_nonblank += nonblank
            tot_code += code

    print("=== 实现文件（计入有效源码量）===")
    print(f"{'file':<34}{'total':>7}{'non-blank':>11}{'no-comment':>12}")
    for rel, total, nonblank, code in impl_rows:
        print(f"{rel:<34}{total:>7}{nonblank:>11}{code:>12}")
    print(f"{'TOTAL':<34}{'':>7}{tot_nonblank:>11}{tot_code:>12}")
    print()

    print("=== 测试文件（按口径排除）===")
    for rel, nonblank in test_rows:
        print(f"{rel:<34}{nonblank:>11}")
    print(f"{'TOTAL':<34}{tot_test:>11}")
    print()

    print("=== 结论 ===")
    print(f"  有效源码量（非空行，扣除测试）  = {tot_nonblank}")
    print(f"  更保守口径（再扣除注释行）      = {tot_code}")
    print("  赛事要求                        >= 500")
    print()
    for label, value in (("口径一", tot_nonblank), ("口径二", tot_code)):
        verdict = "PASS" if value >= 500 else f"FAIL (short by {500 - value})"
        print(f"  {label}: {verdict}")


if __name__ == "__main__":
    main()
