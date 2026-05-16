# PushNow SDK ↔ Backend API — Deprecated

This file was the first-draft spec the iOS SDK team wrote for the
backend team. **The shipped backend surface supersedes it.**

Read the authoritative doc in the `pushnow-backend` repo instead:

> `docs/SDK_BACKEND_INTEGRATION.md`

Three things changed between this draft and the shipped API:

1. **No publishable key.** All four endpoints are public. Authorization
   is by `bundleId` + per-device `auth` secret.
2. **No `applicationId` in the register body.** The backend resolves
   the `Application` by looking up `bundleId` in a unique index.
3. **`auth` rotates on every `register` call.** The SDK must overwrite
   the cached `auth` with whatever `register` returns, including on
   idempotent re-registers of the same APNs token.

This SDK is implemented against the shipped surface. See
`Sources/PushNow/` for the client-side of the contract.
