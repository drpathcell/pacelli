#!/usr/bin/env python3
"""Did every commit on main actually get tested, or did cancellation eat it?

`cancel-in-progress: true` is the right setting for CI and it produces a
worrying artefact: a run history littered with `cancelled`. The argument that
this is safe is that a later run of the SAME workflow builds a tree that
already contains the cancelled commit — so the code was tested, just not under
that run's name.

That argument is sound but it is an argument, and it silently stops holding if
someone force-pushes, reorders history, or narrows a `paths:` filter. This
checks it against reality instead: for every cancelled run, is there a later
SUCCESSFUL run of the same workflow whose commit is a descendant?

    ./scripts/ci_coverage.py              # last 60 runs
    ./scripts/ci_coverage.py --limit 200
    ./scripts/ci_coverage.py --quiet      # only the uncovered ones

A run still in progress covers nothing yet — reported separately from a real
hole, because "cancelled ten minutes ago, successor still building" is the
normal state of an active branch and should not read as a failure.

Exit 0 = every cancelled run is accounted for. Exit 1 = a commit reached main
without its workflow ever passing on it or on a descendant.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys

FIELDS = "databaseId,workflowName,conclusion,status,headSha,createdAt,displayTitle"


def sh(*args: str) -> str:
    r = subprocess.run(args, capture_output=True, text=True)
    if r.returncode != 0:
        sys.exit(f"command failed: {' '.join(args)}\n{r.stderr.strip()}")
    return r.stdout


def is_ancestor(a: str, b: str) -> bool:
    """True if a is an ancestor of b — i.e. b's tree contains a's changes.

    Returns False for a sha git no longer has (rebased away, or never
    fetched), which is the conservative answer: unknown counts as uncovered.
    """
    return subprocess.run(
        ["git", "merge-base", "--is-ancestor", a, b],
        capture_output=True,
    ).returncode == 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--limit", type=int, default=60)
    ap.add_argument("--quiet", action="store_true", help="print only problems")
    a = ap.parse_args()

    runs = json.loads(sh("gh", "run", "list", "--limit", str(a.limit),
                         "--json", FIELDS))
    cancelled = [r for r in runs if r["conclusion"] == "cancelled"]

    holes, pending, covered = [], [], []
    for c in cancelled:
        later = [r for r in runs
                 if r["workflowName"] == c["workflowName"]
                 and r["createdAt"] > c["createdAt"]
                 and is_ancestor(c["headSha"], r["headSha"])]
        if any(r["conclusion"] == "success" for r in later):
            covered.append((c, next(r for r in later if r["conclusion"] == "success")))
        elif any(r["status"] in ("in_progress", "queued") for r in later):
            pending.append(c)
        else:
            holes.append(c)

    def line(r) -> str:
        return f"{r['workflowName']:<12} {r['headSha'][:8]}  {r['displayTitle'][:56]}"

    print(f"{len(cancelled)} cancelled run(s) in the last {a.limit}\n")

    if covered and not a.quiet:
        print(f"\033[32m{len(covered)} covered\033[0m by a later passing run:")
        for c, by in covered:
            print(f"  {line(c)}")
            print(f"    \033[2m^ covered by {by['headSha'][:8]}\033[0m")
        print()

    if pending:
        print(f"\033[33m{len(pending)} pending\033[0m — successor still running, not a hole:")
        for c in pending:
            print(f"  {line(c)}")
        print()

    if holes:
        print(f"\033[31m{len(holes)} UNCOVERED\033[0m — reached main without that "
              f"workflow ever passing on it or a descendant:")
        for c in holes:
            print(f"  {line(c)}")
        print("\nInvestigate before trusting the green ticks on main.")
        return 1

    print("\033[32mEvery cancelled run is accounted for.\033[0m")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
