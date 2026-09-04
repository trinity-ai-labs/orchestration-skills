# sub-issue link

GitHub models a parent/child issue relationship natively, separately from any markdown that mentions it.
The **native link** is one REST call:

```
gh api -X POST repos/{owner}/{repo}/issues/<umbrella>/sub_issues -F sub_issue_id=<child's DATABASE id>
```

**`sub_issue_id` is the child's database id (`.id`, e.g. `5261102081`), not its issue number.** They are
different fields on the same object and both are plain integers, so nothing about a value's shape tells
them apart. `gh api repos/{owner}/{repo}/issues/<n> --jq .id` returns the right one.

**Both ways of getting it wrong fail in a direction that reads as "this endpoint is unavailable".** An
issue number returns a bare `404 Not Found`, which reads as *the endpoint does not exist* rather than
*wrong id*. And the flag does **type** work here rather than `@file` expansion: `-f` is `--raw-field` and
sends the id as a **string**, which the endpoint rejects with `422 Invalid property /sub_issue_id: not of
type integer`; only `-F` types a bare number as a JSON integer. Two flags, two different errors, neither
saying *use the other one*.

**A markdown backlink is a different artifact from the native link, not a rendering of it.** `Part of
#<umbrella>` in the child's body, and a `- [ ] #<sub>` checklist row in the parent's, are text; the call
above is a relationship the API can be queried for. A repository can have either without the other.
