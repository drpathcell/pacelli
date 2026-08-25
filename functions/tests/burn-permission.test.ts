/**
 * The burn permission table.
 *
 * `mayBurn` is the whole of the access decision for destroying a household's
 * shared data, and it is pure so that it can be checked here as a table rather
 * than inferred from an emulator run. Every row is a sentence someone could
 * say out loud about the app.
 *
 * NEGATIVE-CONTROL: RUN on 2026-08-25, not assumed. Making `mayBurn`'s
 * `owner` case return true reddens rows 3, 4, 13 and 14; making the `nobody`
 * case return true reddens 11 and 12. The first list is not the one written
 * here before running it — 7 and 9 were guessed and are wrong, because they
 * are `selected` rows and the owner branch never sees them. Which is the
 * point of running a control instead of describing one.
 */
import { mayBurn, readBurnPermission } from "../src/functions/burn";

const OWNER = "uid-owner";
const MEMBER = "uid-member";
const ASSISTANT = "uid-assistant";

const household = (extra: Record<string, unknown> = {}) => ({
  id: "h1",
  created_by: OWNER,
  ...extra,
});

describe("readBurnPermission", () => {
  it("defaults an absent setting to owner-only", () => {
    expect(readBurnPermission(household()).permission).toBe("owner");
  });

  it("fails closed on a value it does not recognise", () => {
    // Nothing should be able to write this, but a field that decides who may
    // destroy the household's data does not get to be trusting.
    expect(readBurnPermission(household({ burn_permission: "anyone" })).permission).toBe("owner");
    expect(readBurnPermission(household({ burn_permission: 42 })).permission).toBe("owner");
  });

  it("defaults an absent household to owner-only rather than throwing", () => {
    expect(readBurnPermission(undefined).permission).toBe("owner");
    expect(readBurnPermission(undefined).allowed).toEqual([]);
  });

  it("keeps only string uids from the allow list", () => {
    const { allowed } = readBurnPermission(
      household({ burn_permission: "selected", burn_allowed_uids: [MEMBER, 7, null, ASSISTANT] })
    );
    expect(allowed).toEqual([MEMBER, ASSISTANT]);
  });
});

describe("mayBurn", () => {
  it("1. owner may burn under the default", () => {
    expect(mayBurn(household(), OWNER)).toBe(true);
  });

  it("2. owner may burn when the setting says owner", () => {
    expect(mayBurn(household({ burn_permission: "owner" }), OWNER)).toBe(true);
  });

  it("3. a member may not burn under the default", () => {
    expect(mayBurn(household(), MEMBER)).toBe(false);
  });

  it("4. a paired assistant may not burn under the default", () => {
    // The reason this feature exists: since 1.7.0 an assistant is a member
    // like any other, and 'any member may wipe everything' now includes it.
    expect(mayBurn(household(), ASSISTANT)).toBe(false);
  });

  it("5. everyone means everyone", () => {
    const h = household({ burn_permission: "everyone" });
    expect(mayBurn(h, OWNER)).toBe(true);
    expect(mayBurn(h, MEMBER)).toBe(true);
    expect(mayBurn(h, ASSISTANT)).toBe(true);
  });

  it("6. a selected member may burn", () => {
    const h = household({ burn_permission: "selected", burn_allowed_uids: [MEMBER] });
    expect(mayBurn(h, MEMBER)).toBe(true);
  });

  it("7. an unselected member may not", () => {
    const h = household({ burn_permission: "selected", burn_allowed_uids: [MEMBER] });
    expect(mayBurn(h, ASSISTANT)).toBe(false);
  });

  it("8. selected with an empty list permits nobody", () => {
    const h = household({ burn_permission: "selected", burn_allowed_uids: [] });
    expect(mayBurn(h, OWNER)).toBe(false);
    expect(mayBurn(h, MEMBER)).toBe(false);
  });

  it("9. the owner is NOT implicitly on the selected list", () => {
    // Deliberate. 'Selected' means the named people; if the owner wants to
    // keep the ability they add themselves, and the screen makes that obvious.
    const h = household({ burn_permission: "selected", burn_allowed_uids: [MEMBER] });
    expect(mayBurn(h, OWNER)).toBe(false);
  });

  it("10. an owner who lists themselves may burn", () => {
    const h = household({ burn_permission: "selected", burn_allowed_uids: [OWNER, MEMBER] });
    expect(mayBurn(h, OWNER)).toBe(true);
  });

  it("11. nobody means nobody", () => {
    const h = household({ burn_permission: "nobody" });
    expect(mayBurn(h, MEMBER)).toBe(false);
  });

  it("12. nobody includes the owner", () => {
    // Not a lock, and never described as one — the owner can change the
    // setting and then burn. It makes the destructive path cost a deliberate
    // trip to Settings, which is what 'or no one' was asking for.
    const h = household({ burn_permission: "nobody" });
    expect(mayBurn(h, OWNER)).toBe(false);
  });

  it("13. an allow list is ignored unless the setting is 'selected'", () => {
    const h = household({ burn_permission: "owner", burn_allowed_uids: [MEMBER] });
    expect(mayBurn(h, MEMBER)).toBe(false);
  });

  it("14. a household with no created_by permits nobody by default", () => {
    // created_by is frozen on update and pinned on create, so this should be
    // impossible; if it ever happens, the safe reading is 'no owner, no burn'.
    const h = { id: "h1" };
    expect(mayBurn(h, OWNER)).toBe(false);
  });
});
