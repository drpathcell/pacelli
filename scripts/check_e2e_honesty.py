#!/usr/bin/env python3
"""Static honesty check over the E2E harnesses.

Four separate harnesses in this repo have reported COMPLETED while proving
nothing, and each one nearly produced a bug report against correct code or hid
a real bug for weeks:

  2026-08-13  Maestro cannot flip a SwiftUI Toggle by accessibility id — it
              taps the label. `flow_lock_01` tapped, asserted nothing, passed.
  2026-08-13  `simctl spawn defaults` reads a different store that survives
              uninstall, so the assertion read state the app had never written.
  2026-08-14  `flow_qty_01` asserted on "Peppercorns" and "347" while both were
              still sitting in its own input fields. A flow that types a value
              and then asserts it is visible is asserting that typing works.
  2026-08-23  `PhotoIndexer` trapped seconds after every attach. `flow_photo_01`
              ended at the thumbnail while indexing was still running, and
              `flow_photo_02` opens with `stopApp`, so the dead process left no
              trace. The crash shipped as build 46.

The common shape is not a bug in any one flow. It is that a green run was never
required to demonstrate it could have been red. This file encodes the four
structural properties that would have caught all four, so the next one is
caught by CI instead of by a screenshot session.

  H1  assert-what-you-typed     an assertion on a literal this flow just typed,
                                with nothing in between that could have moved
                                it out of the input field
  H2  no assertion after the    the flow's last interaction is never checked;
      last interaction          it taps and walks away
  H3  invisible death window    a flow that does not poke the app one more time
                                after its work, whose successor opens with
                                `stopApp` — the gap where build 46's crash lived
  H4  swallowed failure         a shell harness that cannot fail: no `set -e`,
                                or an assertion routed through `|| true`
  H5  no negative control       a harness that never states how it would fail.
                                `check_quantity_at_rest.py` is the standard:
                                it refuses to report "no plaintext found"
                                unless it first proves it could have seen some.

NEGATIVE-CONTROL: break any single flow (delete the trailing assertion from
flow_lock_01_enable.yaml, or add `assertVisible` on a literal straight after an
`inputText`) and this must exit non-zero naming that flow. `--self-test` does
exactly that against synthetic fixtures and fails if any check stays quiet.

  ./scripts/check_e2e_honesty.py [--self-test]
"""

from __future__ import annotations

import re
import sys
import tempfile
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FLOWS = ROOT / "PacelliApp" / "e2e"
SCRIPTS = ROOT / "scripts"

# Commands that change what the app is showing. An assertion is only worth
# something if one of these happened before it.
INTERACTIONS = (
    "tapOn", "doubleTapOn", "longPressOn", "inputText", "eraseText",
    "pressKey", "scroll", "scrollUntilVisible", "swipe", "back",
    "launchApp", "stopApp", "clearState", "openLink",
)
# Commands that assert something about the app's state.
ASSERTIONS = ("assertVisible", "assertNotVisible", "assertTrue", "extendedWaitUntil")
# Commands that do BOTH: they drive the app and fail if the app does not
# respond. `scrollUntilVisible` scrolls (an interaction) and fails on timeout if
# the element never appears (an assertion) — counting it as only one of the two
# made this tool flag flow_push_optin and flow_reminders_02, which are correct
# as written. A checker that reports things that are fine is on its way to
# being ignored, which is the disease it was built to treat.
BOTH = ("scrollUntilVisible",)
# Neither: they neither drive the app nor check it.
INERT = ("takeScreenshot", "waitForAnimationToEnd", "hideKeyboard", "wait")

WAIVER = re.compile(r"#\s*E2E-HONESTY-WAIVER\[(H\d)\]:\s*(\S.*)")
NEGATIVE_CONTROL = re.compile(r"NEGATIVE-CONTROL:", re.I)


def rel_to_root(path: Path) -> str:
    """Repo-relative when it can be; absolute otherwise (self-test fixtures)."""
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


@dataclass
class Finding:
    check: str
    path: str
    line: int
    message: str

    def __str__(self) -> str:
        return f"{self.check}  {self.path}:{self.line}\n      {self.message}"


@dataclass
class Step:
    line: int
    kind: str          # "interact" | "assert" | "both" | "inert" | "other"
    command: str
    literal: str | None  # the quoted string argument, when there is one

    @property
    def interacts(self) -> bool:
        return self.kind in ("interact", "both")

    @property
    def asserts(self) -> bool:
        return self.kind in ("assert", "both")


@dataclass
class Flow:
    path: Path
    steps: list[Step] = field(default_factory=list)
    waivers: dict[str, str] = field(default_factory=dict)
    text: str = ""

    @property
    def name(self) -> str:
        return self.path.name

    @property
    def rel(self) -> str:
        return rel_to_root(self.path)


def classify(command: str) -> str:
    if command in BOTH:
        return "both"
    if command in ASSERTIONS:
        return "assert"
    if command in INTERACTIONS:
        return "interact"
    if command in INERT:
        return "inert"
    return "other"


def parse_flow(path: Path) -> Flow:
    """Enough of Maestro's YAML to see the shape. Not a YAML parser.

    Maestro flows are a flat list of single-key mappings, sometimes nested one
    level inside `runFlow.commands`. Both forms are read, because a `tapOn`
    inside a conditional `runFlow` still taps.
    """
    flow = Flow(path=path, text=path.read_text())
    for i, raw in enumerate(flow.text.splitlines(), start=1):
        m = WAIVER.search(raw)
        if m:
            flow.waivers[m.group(1)] = m.group(2).strip()

        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue

        # `- command: "arg"` / `- command:` / `      - command: "arg"`
        m = re.match(r"^\s*-\s+([A-Za-z][A-Za-z0-9_]*)\s*:?\s*(.*)$", line)
        if not m:
            continue
        command, rest = m.group(1), m.group(2).strip()
        lit = None
        q = re.match(r'^"([^"]*)"\s*$', rest)
        if q:
            lit = q.group(1)
        flow.steps.append(Step(i, classify(command), command, lit))

        # An `extendedWaitUntil:` / `assertVisible:` block puts its literal on a
        # following `visible: "X"` line, so pick those up too.
    # second pass: attach block-form literals to the assertion above them
    pending: Step | None = None
    for i, raw in enumerate(flow.text.splitlines(), start=1):
        line = raw.split("#", 1)[0]
        m = re.match(r"^\s*-\s+([A-Za-z][A-Za-z0-9_]*)\s*:?\s*(.*)$", line)
        if m:
            pending = next((s for s in flow.steps if s.line == i), None)
            continue
        if pending is None or pending.literal is not None:
            continue
        v = re.match(r'^\s+(?:visible|text|notVisible)\s*:\s*"([^"]*)"\s*$', line)
        if v:
            pending.literal = v.group(1)
    return flow


def family_of(name: str) -> tuple[str, str] | None:
    """`flow_photo_02_gallery.yaml` -> ("photo", "02"). None if unnumbered."""
    m = re.match(r"^flow_([a-z_]+?)_(\d{2})(?:_|\.)", name)
    return (m.group(1), m.group(2)) if m else None


# ── H1 ──────────────────────────────────────────────────────────────────────
def check_h1(flow: Flow) -> list[Finding]:
    """An assertion on a literal this flow just typed, with nothing between.

    The discriminator is not "did it type this string" — plenty of flows type a
    value, commit it, and then legitimately assert it appears in a list. It is
    whether anything happened in between that could have moved the text out of
    the field it was typed into. `hideKeyboard` and `takeScreenshot` cannot;
    a tap, a key press or a relaunch can.
    """
    out: list[Finding] = []
    for idx, step in enumerate(flow.steps):
        if step.command != "inputText" or not step.literal:
            continue
        for later in flow.steps[idx + 1:]:
            if later.interacts:
                break  # something could have committed it — not our business
            if later.asserts and later.literal == step.literal:
                out.append(Finding(
                    "H1", flow.rel, later.line,
                    f'asserts "{step.literal}" (typed at line {step.line}) with no '
                    f"interaction in between — this passes against the text still "
                    f"sitting in its own input field, which asserts that typing works"))
                break
    return out


# ── H2 ──────────────────────────────────────────────────────────────────────
def check_h2(flow: Flow) -> list[Finding]:
    """The flow's last interaction is never checked."""
    last_interaction = None
    for step in flow.steps:
        if step.interacts:
            last_interaction = step
    if last_interaction is None:
        return []
    if last_interaction.asserts:
        return []  # it checked itself — scrollUntilVisible fails on timeout
    if any(s.asserts and s.line > last_interaction.line for s in flow.steps):
        return []
    return [Finding(
        "H2", flow.rel, last_interaction.line,
        f"`{last_interaction.command}` is the last thing this flow does to the app "
        f"and nothing checks the result — a tap that silently does nothing "
        f"(Maestro cannot flip a SwiftUI Toggle by id) is reported as COMPLETED")]


# ── H3 ──────────────────────────────────────────────────────────────────────
def check_h3(flow: Flow, successor: Flow | None) -> list[Finding]:
    """The window a crash can die in, unseen.

    A flow that finishes its work and stops, followed by a flow that opens with
    `stopApp`, cannot tell a healthy process from a dead one: the successor
    kills the app it never looked at. The fix is a poke — one more interaction
    after the work, and an assertion on it, so the flow ends by proving the
    process is still answering.

    Only fires when there IS such a successor, so it names real blind windows
    rather than lecturing every flow in the directory.
    """
    if successor is None:
        return []
    first = next((s for s in successor.steps if s.kind != "inert"), None)
    if first is None or first.command != "stopApp":
        return []

    asserts = [s for s in flow.steps if s.asserts]
    if len(asserts) < 2:
        poked = False
    else:
        # An honest tail is: assert (the work) … interact (the poke) … assert.
        poked = any(
            s.interacts and asserts[-2].line < s.line < asserts[-1].line
            for s in flow.steps)
    if poked:
        return []
    return [Finding(
        "H3", flow.rel, flow.steps[-1].line if flow.steps else 1,
        f"ends without asking the app to do one more thing, and {successor.name} "
        f"opens with `stopApp` — a process that dies in between leaves no trace "
        f"at all. This is exactly where build 46's photo crash lived. End with "
        f"an interaction and an assertion on it.")]


# ── H4 ──────────────────────────────────────────────────────────────────────
def check_h4(path: Path) -> list[Finding]:
    out: list[Finding] = []
    text = path.read_text()
    rel = rel_to_root(path)
    waivers = {m.group(1): m.group(2) for m in WAIVER.finditer(text)}

    if path.suffix == ".sh" and "H4" not in waivers:
        if not re.search(r"^set -[a-z]*e", text, re.M):
            out.append(Finding(
                "H4", rel, 1,
                "no `set -e` — a failing command in the middle scrolls past and the "
                "script exits 0 on the last line"))

    # `|| true` on a line that PROVES something.
    #
    # The first cut of this rule flagged every `|| true` outside cleanup and
    # produced 27 findings, all of them wrong: `xcrun simctl shutdown`,
    # `uninstall`, `terminate` and `boot` are lifecycle calls whose failure is
    # expected and harmless, and check_push_e2e.sh even carries a comment
    # explaining that its `|| true` is load-bearing against pipefail. A rule
    # that cries wolf 27 times gets muted, which would have left the one real
    # case invisible — the same failure mode this whole file exists to catch.
    #
    # So it fires only where `|| true` sits on a line that is doing the
    # proving: a grep, a read of stored state, a comparison, a sub-check.
    if path.suffix != ".sh":
        return out

    proving = re.compile(
        r"\b(grep|plutil|diff|cmp|jq|python3?|node|test|firebase|assert\w*"
        r"|check_\w+|\[\[)\b")
    benign = re.compile(
        r"^\s*(xcrun\s+simctl\s+"
        r"(shutdown|boot|bootstatus|uninstall|terminate|erase|addmedia|privacy)"
        r"|rm|mkdir|kill|pkill|osascript\s+-e\s+.quit|open|defaults\s+delete)\b")

    in_cleanup = False
    for i, line in enumerate(text.splitlines(), start=1):
        if re.match(r"^\s*(cleanup|teardown)\s*\(\)", line):
            in_cleanup = True
        elif in_cleanup and re.match(r"^\}", line):
            in_cleanup = False
        code = line.split("#", 1)[0]
        if in_cleanup or "trap " in code or not code.strip():
            continue
        # A waiver applies to the line it is on and the two after it, so it can
        # sit above the line it explains instead of trailing off the end of it.
        window = "\n".join(text.splitlines()[max(0, i - 4):i])
        if any(m.group(1) == "H4" for m in WAIVER.finditer(window)):
            continue
        if not re.search(r"\|\|\s*true\b", code):
            continue
        if benign.match(code) or not proving.search(code):
            continue
        # `VAR="$(thing || true)"` is a CAPTURE, not a proof. Every retry loop
        # in this repo is shaped that way: the substitution must survive "not
        # there yet" without pipefail killing the run, and the assertion is the
        # `[[ -n "$VAR" ]] || fail` on the line below. Six of the seven findings
        # from the previous cut were this idiom, correctly written.
        if re.search(r"\$\([^()]*\|\|\s*true\s*\)", code):
            continue
        out.append(Finding(
            "H4", rel, i,
            "`|| true` on a line that is doing the proving: whatever this "
            "establishes, it establishes whether or not it worked"))
    return out


# ── H5 ──────────────────────────────────────────────────────────────────────
def check_h5(path: Path) -> list[Finding]:
    """Every harness has to say how it would fail."""
    if NEGATIVE_CONTROL.search(path.read_text()):
        return []
    return [Finding(
        "H5", rel_to_root(path), 1,
        "no `NEGATIVE-CONTROL:` line. State, in one sentence, what you would break "
        "to make this harness go red — a check nobody has ever seen fail is a "
        "check nobody has any reason to believe")]


# ── driver ──────────────────────────────────────────────────────────────────
def run(flow_dir: Path, script_dir: Path | None) -> list[Finding]:
    findings: list[Finding] = []

    flows = {p.name: parse_flow(p) for p in sorted(flow_dir.glob("flow_*.yaml"))}

    # successor within a numbered family
    by_family: dict[str, list[tuple[str, Flow]]] = {}
    for name, flow in flows.items():
        fam = family_of(name)
        if fam:
            by_family.setdefault(fam[0], []).append((fam[1], flow))
    successors: dict[str, Flow] = {}
    for fam, members in by_family.items():
        members.sort(key=lambda t: t[0])
        for (_, a), (_, b) in zip(members, members[1:]):
            successors[a.name] = b

    for name, flow in flows.items():
        for check, result in (
            ("H1", lambda: check_h1(flow)),
            ("H2", lambda: check_h2(flow)),
            ("H3", lambda: check_h3(flow, successors.get(name))),
        ):
            if check in flow.waivers:
                continue
            findings.extend(result())

    if script_dir is not None:
        harnesses = sorted(
            p for p in script_dir.glob("check_*")
            if p.suffix in (".sh", ".py") and p.is_file())
        for p in harnesses:
            findings.extend(check_h4(p))
            findings.extend(check_h5(p))

    return findings


def self_test() -> int:
    """Every check must fire against a file built to trip it.

    This is the tool applying its own rule to itself. A linter that has never
    been shown to reject anything is in exactly the position of a green E2E
    that has never been shown to fail.
    """
    fixtures = {
        "H1": ("flow_probe_01_a.yaml",
               'appId: x\n---\n- launchApp\n- inputText: "Peppercorns"\n'
               '- hideKeyboard\n- assertVisible: "Peppercorns"\n'),
        "H2": ("flow_probe_02_a.yaml",
               'appId: x\n---\n- launchApp\n- assertVisible: "Home"\n- tapOn: "Toggle"\n'
               '- takeScreenshot: /tmp/x\n'),
        "H3": ("flow_probe_03_01_work.yaml",
               'appId: x\n---\n- launchApp\n- tapOn: "Add"\n- assertVisible: "Done"\n'),
    }
    failures: list[str] = []
    with tempfile.TemporaryDirectory() as tmp:
        d = Path(tmp)
        for _, (fname, body) in fixtures.items():
            (d / fname).write_text(body)
        # H3 needs a successor that opens with stopApp
        (d / "flow_probe_03_02_next.yaml").write_text(
            'appId: x\n---\n- stopApp\n- launchApp\n- assertVisible: "Home"\n')

        found = {f.check for f in run(d, None)}
        for check in ("H1", "H2", "H3"):
            if check not in found:
                failures.append(f"{check} did not fire against its own fixture")

        # H4 / H5 against a synthetic harness
        s = d / "scripts"
        s.mkdir()
        (s / "check_probe.sh").write_text(
            "#!/usr/bin/env bash\ngrep -q thing file || true\n")  # proving line, no set -e
        found = {f.check for f in run(d, s)}
        for check in ("H4", "H5"):
            if check not in found:
                failures.append(f"{check} did not fire against its own fixture")

        # And the inverse: a clean tree must produce nothing.
        clean = Path(tmp) / "clean"
        (clean / "scripts").mkdir(parents=True)
        (clean / "flow_ok_01_a.yaml").write_text(
            'appId: x\n---\n- launchApp\n- tapOn: "Add"\n- assertVisible: "Done"\n'
            '- tapOn: "Back"\n- assertVisible: "Home"\n')
        (clean / "scripts" / "check_ok.sh").write_text(
            "#!/usr/bin/env bash\n# NEGATIVE-CONTROL: delete the grep\nset -euo pipefail\n"
            "grep -q thing file\n")
        residue = run(clean, clean / "scripts")
        if residue:
            failures.append(
                "clean fixtures produced findings: "
                + "; ".join(f.check + "@" + f.path for f in residue))

    if failures:
        print("SELF-TEST FAILED")
        for f in failures:
            print("  " + f)
        return 1
    print("SELF-TEST OK — all five checks fire, and a clean tree stays quiet")
    return 0


def main() -> int:
    if "--self-test" in sys.argv:
        return self_test()

    findings = run(FLOWS, SCRIPTS)
    if not findings:
        print("E2E honesty: clean")
        return 0

    by_check: dict[str, list[Finding]] = {}
    for f in findings:
        by_check.setdefault(f.check, []).append(f)

    print(f"E2E honesty: {len(findings)} finding(s)\n")
    for check in sorted(by_check):
        print(f"── {check} ─────────────────────────────────────────")
        for f in sorted(by_check[check], key=lambda x: (x.path, x.line)):
            print(f)
        print()
    print("Waive one with a comment in the file it belongs to:")
    print("  # E2E-HONESTY-WAIVER[H3]: why this flow cannot be blind")
    return 1


if __name__ == "__main__":
    sys.exit(main())
