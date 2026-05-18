# Security policy

## Supported versions

Pre-1.0, only the latest tagged release receives security fixes. After 1.0 lands this section will list the supported minors.

| Version | Supported |
| ------- | --------- |
| latest (`main`) | yes |
| anything older | no |

## Reporting a vulnerability

Do not file a public issue. Two private channels work:

1. **GitHub Security Advisories** — [open a draft advisory](https://github.com/mpiton/agentic-atdd/security/advisories/new). Preferred. Lets us coordinate a fix in the same place as the disclosure.
2. **Email** — `matpiton@protonmail.com`. Use this if you cannot open a GitHub account or want PGP. Reach out for a key.

Include the version (commit SHA or release tag), reproduction steps, blast radius, and a suggested fix if you have one.

## What happens next

- Acknowledgment within 48 hours.
- Initial assessment within a week.
- Fix timeline depends on severity. Critical issues get a same-week patch and a coordinated disclosure date.

Reporters are credited in the advisory unless they ask to stay anonymous.

## Scope

This plugin shells out to `gh`, `git`, and your local toolchain. The skills themselves are prompts plus a couple of bash helpers. The most likely vulnerability classes:

- Command injection through interpolated values (slugs, branch names, issue titles).
- Path traversal through `us-slug` or scenario slugs landing in `specs/`.
- Unauthorized merge of a sub-PR by bypassing the `baseRefName` guard in `pr-auto-merge`.

If you find anything in one of those families, treat it as security-sensitive even if you're not sure.
