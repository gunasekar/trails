# 22. An unnamed trail is named by its ID

- Status: accepted
- Date: 2026-10
- Amends [ADR 20](0020-a-trail-has-an-id-of-its-own.md): the trail ID is four hex
  digits, and an unnamed trail's session and window carry it

## Context

ADR 20 gave every trail an ID of its own, `t` and eight hex digits, and kept it out of
sight: the record was named by it, and the session stayed `<workspace>/<codebase>`,
then `-2`, `-3` for the next unnamed trails in that codebase. The number was the first
one free, so a trail that ended gave its number to the next one started: `checkout-2`
in the morning and `checkout-2` in the afternoon were two trails under one name, the
very reuse ADR 20 took away from records. Which trail got the bare name, and which a
number, depended only on what else ran at the moment it started.

Eight hex digits were also more than the ID needs. It has to be unique among the
trails there are, running or lost, a few dozen at most, and `new_tid` already makes
another when a record has the one it drew.

## Decision

- **The trail ID is `t` and four hex digits**, `t3f9a`. `new_tid` draws again while a
  record or a running window has it, and `launch` asks again under its lock, since two
  launches can draw the same one before either writes its record.
- **An unnamed trail's session is `<workspace>/<codebase>-<ID>`**, the ID without
  its `t`: `acme/checkout-3f9a`. Its window is `checkout-3f9a`, its badge `#3f9a`.
  Every unnamed trail has one, the first in a codebase included; there is no bare
  `<workspace>/<codebase>` any more.
- **A named trail is unchanged**: `acme/payments`, window `checkout·payments`.
- **A restore keeps the ID, and so the name.** It lands on another only when its
  session is held by a session of your own, or the config moved its codebase to
  another workspace, and takes a `-N` after the ID only if that one is held too.
- **A name that reads as an unnamed trail's is refused**: `<codebase>-` followed by
  hex digits and dashes only, or four hex digits alone, which would read as a badge.

## Consequences

- `next_session`'s search for a free number is gone from a new trail's launch; a
  restore that finds its name held still uses it.
- Names are never reused while a trail lives, and seldom after: 65,536 IDs, of which a
  stale reference (a picker row, a wrapper's `--forget`) would have to meet the one
  drawn again within seconds.
- The window names in the status line are longer by five characters, and no unnamed
  trail is told apart by being "the first". Naming a trail (`trails new NAME`, ctrl-n)
  is the way to a short one.
- A name made only of four hex digits, `beef` or `cafe`, is refused.
- Trails from 1.8 and 1.9 keep what they have until they end: their eight-digit IDs are
  still read, and their `augur`, `augur-2` sessions still badge as `-` and `#2`.
