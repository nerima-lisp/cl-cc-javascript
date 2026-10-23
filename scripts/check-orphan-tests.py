import argparse
import subprocess
import sys
from pathlib import Path


def parse_args():
    root = Path(__file__).resolve().parent.parent
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=root)
    parser.add_argument("--sbcl", default="sbcl")
    parser.add_argument("--asd-file", default="cl-cc-javascript.asd")
    parser.add_argument("--test-root", default="t")
    parser.add_argument("--allowlist", default="t/orphan-test-allowlist.tsv")
    return parser.parse_args()


def asdf_test_components(root, sbcl, asd_file, test_root):
    lisp_asd_file = asd_file.replace("\\", "\\\\").replace('"', '\\"')
    expression = f'''(progn
(asdf:load-asd (truename "{lisp_asd_file}"))
(let ((system (asdf:find-system "cl-cc-javascript/test")))
  (labels ((emit-files (component)
             (if (typep component 'asdf:parent-component)
                 (mapc #'emit-files (asdf:component-children component))
                 (format t "ASDF-COMPONENT ~A~%"
                         (namestring (asdf:component-pathname component))))))
    (emit-files system))))
'''
    result = subprocess.run(
        [
            sbcl,
            "--noinform",
            "--non-interactive",
            "--eval",
            "(require :asdf)",
            "--eval",
            expression,
        ],
        cwd=root,
        text=True,
        capture_output=True,
        check=False,
    )
    if result.returncode:
        sys.stderr.write(result.stdout)
        sys.stderr.write(result.stderr)
        raise RuntimeError(f"SBCL/ASDF component inspection failed: {result.returncode}")

    prefix = "ASDF-COMPONENT "
    paths = []
    for line in result.stdout.splitlines():
        if line.startswith(prefix):
            paths.append(Path(line[len(prefix):]).resolve())
    if not paths:
        raise RuntimeError("ASDF component inspection returned no test files")

    root = root.resolve()
    test_root = test_root.resolve()
    relative_paths = []
    for path in paths:
        try:
            relative = path.relative_to(root).as_posix()
        except ValueError as error:
            raise RuntimeError(f"ASDF component is outside the repository: {path}") from error
        if path.suffix != ".lisp" or not path.is_relative_to(test_root.resolve()):
            raise RuntimeError(f"Unexpected test component path: {relative}")
        relative_paths.append(relative)
    return relative_paths


def read_allowlist(path):
    entries = []
    errors = []
    for line_number, raw_line in enumerate(path.read_text().splitlines(), start=1):
        if not raw_line.strip() or raw_line.lstrip().startswith("#"):
            continue
        fields = raw_line.split("\t")
        if len(fields) != 2:
            errors.append(f"{path}:{line_number}: expected path<TAB>reason")
            continue
        relative, reason = fields
        candidate = Path(relative)
        if candidate.is_absolute() or ".." in candidate.parts or candidate.as_posix() != relative:
            errors.append(f"{path}:{line_number}: invalid repository-relative path {relative!r}")
            continue
        if not reason.strip():
            errors.append(f"{path}:{line_number}: missing reason for {relative}")
            continue
        entries.append((relative, reason))
    return entries, errors


def main():
    args = parse_args()
    root = args.root.resolve()
    test_root = (root / args.test_root).resolve()
    allowlist_path = root / args.allowlist
    asd_path = root / args.asd_file
    if not test_root.is_dir():
        raise RuntimeError(f"test directory does not exist: {test_root}")
    if not asd_path.is_file():
        raise RuntimeError(f"ASDF definition does not exist: {asd_path}")
    if not allowlist_path.is_file():
        raise RuntimeError(f"orphan allowlist does not exist: {allowlist_path}")

    discovered = {
        path.relative_to(root).as_posix()
        for path in test_root.rglob("*.lisp")
        if path.is_file()
    }
    components = asdf_test_components(root, args.sbcl, args.asd_file, test_root)
    registered = set(components)
    entries, errors = read_allowlist(allowlist_path)
    allowlisted = {path for path, _reason in entries}

    duplicates = sorted(path for path in allowlisted if sum(item == path for item, _ in entries) > 1)
    if duplicates:
        errors.append("duplicate allowlist entries: " + ", ".join(duplicates))

    missing_components = sorted(registered - discovered)
    if missing_components:
        errors.append("ASDF components missing from test tree: " + ", ".join(missing_components))

    missing_allowlist = sorted(allowlisted - discovered)
    if missing_allowlist:
        errors.append("allowlist paths missing from test tree: " + ", ".join(missing_allowlist))

    registered_allowlist = sorted(allowlisted & registered)
    if registered_allowlist:
        errors.append("allowlisted tests are already registered: " + ", ".join(registered_allowlist))

    orphan = sorted(discovered - registered - allowlisted)
    stale_allowlist = sorted(allowlisted - discovered)
    print(
        f"found={len(discovered)} registered={len(registered)} "
        f"allowlisted={len(allowlisted)} orphan={len(orphan)}"
    )
    if orphan:
        errors.append("unregistered test files: " + ", ".join(orphan))
    if stale_allowlist:
        errors.append("stale allowlist entries: " + ", ".join(stale_allowlist))
    if errors:
        for error in errors:
            print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError) as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
