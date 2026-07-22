# Test Report — `rewrite-history`

| | |
|---|---|
| **Branch** | `rewrite-history` |
| **Date** | 2026-07-23 04:52:02 |
| **Commits** | 25 |

## Summary

| Status | Count |
|--------|-------|
| PASS | 24 |
| FAIL | 1 |
| ERROR | 0 |
| **Total** | **25** |

> **1** failures, **0** errors detected.

---

## Per-Commit Details

## 1. `2ae282f` 2ae282f feat: implement User model with Devise and JWT authentication

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 0 runs / 0 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | N/A% |

## 2. `489816c` 489816c feat: add JWT authentication controllers and middleware

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 0 runs / 0 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | N/A% |

## 3. `d831f16` d831f16 feat: add custom error handling middleware

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 0 runs / 0 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | N/A% |

## 4. `a2fd6b6` a2fd6b6 test: add model fixtures and basic unit tests

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 8 runs / 8 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | N/A% |

## 5. `60b10bc` 60b10bc chore: add gem version pins for Ruby 4.0 compatibility

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 8 runs / 8 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | N/A% |

## 6. `ca70c92` ca70c92 chore: add development helper scripts and scratch files

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 8 runs / 8 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | N/A% |

## 7. `af337ba` af337ba chore: configure production deployment settings

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 18 runs / 30 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | N/A% |

## 8. `6e375d9` 6e375d9 docs: replace boilerplate README with API usage guide

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 18 runs / 30 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | N/A% |

## 9. `cd49b68` cd49b68 refactor: extract UserAccessControl concern

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 20 runs / 34 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | N/A% |

## 10. `87f7069` 87f7069 docs: rewrite README with setup instructions

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 33 runs / 95 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | N/A% |

## 11. `586aad5` 586aad5 feat: add boot-time environment validation

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 39 runs / 155 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | N/A% |

## 12. `11012d5` 11012d5 test: add SimpleCov code coverage reporting

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 51 runs / 175 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 75.60% |

## 13. `69245ed` 69245ed refactor: remove unused Devise controllers

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 86 runs / 266 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 95.93% |

## 14. `93b078c` 93b078c feat: upgrade Rails to 8.1.3

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 86 runs / 266 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 95.93% |

## 15. `d38476e` d38476e feat: add performance indexes

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 86 runs / 266 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 95.93% |

## 16. `d04499d` d04499d feat: add Pagy-based pagination for users index

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 89 runs / 278 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 90.26% |

## 17. `44f3a66` 44f3a66 chore(deps): bump devise-jwt from 0.12.1 to 0.13.0

| Metric | Value |
|--------|-------|
| Status | **FAIL** |
| Tests | 89 runs / 276 assertions |
| Failures | 1 |
| Errors | 0 |
| Coverage | 90.26% |

<details>
<summary>Failure/Error details</summary>

```

Failure:
RateLimitTest#test_sign_in_allows_up_to_5_requests_per_IP_per_60s_then_throttles [test/integration/rate_limit_test.rb:48]:
Expected response to be a <429: Too Many Requests>, but was a <401: Unauthorized>
Response body: {"error":"Invalid email or password."}.
```
</details>

## 18. `920ea1b` 920ea1b chore(deps): bump devise from 4.9 to 5.0

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 89 runs / 278 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 90.26% |

## 19. `6705559` 6705559 chore: add Ruby 4 compatibility pins and fix lint

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 89 runs / 278 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 90.26% |

## 20. `a541558` a541558 ci: add CircleCI and GitHub Actions configuration

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 89 runs / 278 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 90.26% |

## 21. `4714d2b` 4714d2b docs: add GitHub issue and PR templates

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 89 runs / 278 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 90.26% |

## 22. `940e97d` 940e97d docs: add community health files

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 89 runs / 278 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 90.26% |

## 23. `f06c744` f06c744 docs: add bilingual guides for security topics

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 89 runs / 278 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 90.26% |

## 24. `4433dee` 4433dee docs: add Vietnamese README and feature documentation

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 89 runs / 278 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 90.26% |

## 25. `202c219` 202c219 docs: add CI badge and final README updates

| Metric | Value |
|--------|-------|
| Status | **PASS** |
| Tests | 89 runs / 278 assertions |
| Failures | 0 |
| Errors | 0 |
| Coverage | 90.26% |

