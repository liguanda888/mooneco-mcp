#!/usr/bin/env python3
"""按 git 历史逐提交统计「有效 MoonBit 源码量」，用于申诉举证。

每个提交通过 `git archive` 还原到临时目录后再统计，不改动当前工作树。
统计口径与 scripts/count_effective_loc.py 一致。

用法：
    python scripts/loc_history.py [仓库根目录] [起始提交..结束提交]
"""

import pathlib
import subprocess
import sys
import tarfile
import tempfile

SKIP_DIRS = {"_build", ".git", ".mooncakes", "target", "node_modules"}


def is_test(rel: str) -> bool:
    return rel.endswith("_test.mbt") or rel.endswith("_wbtest.mbt")


def count(root: pathlib.Path) -> tuple[int, int, int, int]:
    """返回 (实现非空行, 实现去注释行, 测试非空行, 测试用例数)。"""
    impl_nonblank = impl_code = test_nonblank = tests = 0
    for path in sorted(root.rglob("*.mbt")):
        if any(part in SKIP_DIRS for part in path.parts):
            continue
        rel = path.relative_to(root).as_posix()
        lines = path.read_text(encoding="utf-8").splitlines()
        nonblank = sum(1 for l in lines if l.strip())
        code = sum(1 for l in lines if l.strip() and not l.strip().startswith("//"))
        if is_test(rel):
            test_nonblank += nonblank
            tests += sum(1 for l in lines if l.strip().startswith("test "))
        else:
            impl_nonblank += nonblank
            impl_code += code
    return impl_nonblank, impl_code, test_nonblank, tests


def main() -> None:
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    revspec = sys.argv[2] if len(sys.argv) > 2 else "HEAD"

    log = subprocess.run(
        ["git", "-C", str(root), "log", "--reverse", "--format=%H%x09%s", revspec],
        capture_output=True, text=True, check=True, encoding="utf-8",
    ).stdout.splitlines()

    print(f"{'commit':<9}{'impl':>7}{'code':>7}{'test':>7}{'cases':>7}  subject")
    for line in log:
        if not line.strip():
            continue
        sha, _, subject = line.partition("\t")
        with tempfile.TemporaryDirectory() as tmp:
            tar_path = pathlib.Path(tmp) / "c.tar"
            subprocess.run(
                ["git", "-C", str(root), "archive", "--format=tar",
                 "-o", str(tar_path), sha],
                check=True, capture_output=True,
            )
            dest = pathlib.Path(tmp) / "w"
            dest.mkdir()
            with tarfile.open(tar_path) as tf:
                tf.extractall(dest, filter="data")
            impl, code, test, cases = count(dest)
        print(f"{sha[:8]:<9}{impl:>7}{code:>7}{test:>7}{cases:>7}  {subject[:60]}")


if __name__ == "__main__":
    main()
