# 0004. Build once, promote by digest

- Status: accepted
- Date: 2026-11-18

## Context

If each environment rebuilds the image, prod runs bytes that were never tested. Tags can also
be moved, so "v0.2.0" in prod may not be what ran in dev.

## Decision

`image.yml` builds the image once per release tag, scans it, tests it and signs it with cosign
keyless (GitHub OIDC). From then on it is only referenced by digest and copied between
registries (GHCR -> Artifact Registry dev -> Artifact Registry prod) with `crane`, together
with its signature. Every copy checks that the digest did not change and every deploy verifies
the signature. Artifact Registry tags are immutable.

## Alternatives considered

- Rebuild per environment: simpler pipelines, but no guarantee prod runs what was tested.
- A single shared registry: one copy, but prod would depend on a registry dev can write to.

## Consequences

- What runs in prod is byte-for-byte what passed the dev canary.
- `crane copy` moves one manifest; signatures are separate artifacts and must be copied too
  (`tools/copy-signed.sh`).
- The prod deployer needs read access on the dev registry, granted explicitly.

## Interview notes

"The digest is the identity of a release. I build once, sign it, and every later step copies
and verifies that digest. A rebuild is a different artifact, even from the same commit."
