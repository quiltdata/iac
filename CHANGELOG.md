# Changelog

## Policy

**Comprehensiveness**: Include all notable changes (features, fixes, breaking changes, documentation).
**Conciseness**: Keep entries brief - one line per change when possible.
**Clarity**: Focus on impact and outcome, not implementation details.

For documentation PRs: List all major additions but avoid redundant detail. Group related changes.

<!-- template:
## [Unreleased] - YYYY-MM-DD

Optional release notice.

- [Verb] Change description ([#<PR-number>](https://github.com/quiltdata/iac/pull/<PR-number>))
-->

## [Unreleased] - YYYY-MM-DD

- [Added] Transit Gateway egress mode for new VPCs: set `enable_transit_gateway = true` (+ `transit_gateway_id`) to route private-subnet egress through a Transit Gateway instead of NAT gateways; IPv6 egress is opt-in via `transit_gateway_ipv6_egress`. See [Transit Gateway egress](README.md#transit-gateway-egress) ([#115](https://github.com/quiltdata/iac/pull/115))

## [1.7.2] - 2026-06-08

- [Fixed] Bump `modules/cnames` AWS provider constraint from `~> 5.0` to `~> 6.0` so it resolves alongside the `vpc` module's `aws >= 6.28` requirement — using `quilt` + `cnames` in one root previously failed `terraform init` ([#117](https://github.com/quiltdata/iac/pull/117))

## [1.7.1] - 2026-06-04

- [Fixed] Pin every registry module with `~>` so an upstream major can't silently break `terraform plan`/`apply` — resolves the `security-group` v6.0.0 break and constrains the rest (`security-group`/`rds` → `~> 5.0`, `vpc` → `~> 6.0`) ([#110](https://github.com/quiltdata/iac/pull/110), [#112](https://github.com/quiltdata/iac/pull/112))

## [1.7.0] - 2026-05-28

- [Added] `template_file` may now be set to `null` for `terraform destroy`; apply still requires a real path. ([#105](https://github.com/quiltdata/iac/pull/105))
- [Changed] Update Postgres to 15.18 ([#108](https://github.com/quiltdata/iac/pull/108))

## [1.6.0] - 2026-02-24

If you rely on the default `search_instance_type` / `search_dedicated_master_type`:
- Upgrading from a version prior to 1.5.0 will fail on `terraform apply`. Upgrade to 1.5.0 first.
- If you have reserved m5 instances, pin the instance types explicitly to keep using them.

- [Changed] Use Graviton2 (`m6g.xlarge` / `m6g.large`) as default ES instance types for better price/performance ([#101](https://github.com/quiltdata/iac/pull/101))

## [1.5.0] - 2026-01-13

Upgrading to this version is only possible from version 1.1.0 or later.

This version requires Quilt stack version 1.66 or later.
Ensure your Quilt stack is upgraded to version 1.66 or later *before* upgrading this module to avoid downtime.

- [Changed] Update Elasticsearch to 7.10 ([#89](https://github.com/quiltdata/iac/pull/89))

## [1.4.0] - 2025-12-18

- [Changed] Update Postgres to 15.15 ([#94](https://github.com/quiltdata/iac/pull/94))

### Documentation

- [Added] ElasticSearch configuration guide with sizing recommendations and EBS volume calculations
- [Added] Complete variable reference (VARIABLES.md) with validation rules and examples
- [Added] Comprehensive deployment examples (EXAMPLES.md) with tiered parameter grouping and real-world validation
- [Added] Installation and configuration documentation with enterprise prerequisites
- [Added] Network, security, and AWS permissions guidance
- [Enhanced] EXAMPLES.md with sizing rationale, best practices, and realistic instance types based on production deployments
- [Removed] OPERATIONS.md moved to separate PR to maintain focused scope
- [Added] Comprehensive operations guide (OPERATIONS.md) for cloud teams with installation, maintenance, scaling, disaster recovery, and monitoring procedures ([#92](https://github.com/quiltdata/iac/pull/92))

### Security

- [Changed] **BREAKING CHANGE**: Replaced hardcoded values with YOUR-* placeholders to prevent accidental deployment
- [Added] Security warnings and replacement checklists in all example configurations

### Examples

- [Enhanced] examples/main.tf with comprehensive configuration options
- [Added] ElasticSearch sizing configurations (Small, Medium, Large, X-Large)
- [Added] Authentication examples for Google OAuth, Okta, OneLogin, and Azure AD
- [Added] Network and CloudFormation parameter examples
- [Improved] Database instance recommendations aligned with real-world usage (db.t3 instead of db.r5)

## [1.3.0] - 2025-05-05

- [Changed] Update Postgres to 15.12 ([#85](https://github.com/quiltdata/iac/pull/85))

## [1.2.0] - 2025-02-21

- [Changed] Elasticsearch: require that all traffic to the domain arrive over HTTPS ([#82](https://github.com/quiltdata/iac/pull/82))
- [Changed] Elasticsearch: set TLS security policy to "Policy-Min-TLS-1-2-PFS-2023-10" (latest) ([#82](https://github.com/quiltdata/iac/pull/82))
- [Changed] Elasticsearch: enable node-to-node encryption ([#82](https://github.com/quiltdata/iac/pull/82))

## [1.1.0] - 2024-12-20

- [Changed] Increase default CloudFormation stack delete timeout from 1h to 1h30m ([#78](https://github.com/quiltdata/iac/pull/78))
- [Fixed] Really use `on_failure` variable, previously CloudFormation stack `on_failure` was hardcoded to `ROLLBACK` ([#77](https://github.com/quiltdata/iac/pull/77))
- [Fixed] Add CloudFormation stack `on_failure` to `lifecycle.ignore_changes`, so stacks created before [`0ca3e1319cc89557ea31b3553012562d0e9a0b81`](https://github.com/quiltdata/iac/commit/0ca3e1319cc89557ea31b3553012562d0e9a0b81) won't be re-created on update by default ([#77](https://github.com/quiltdata/iac/pull/77))
- [Changed] Update Elasticsearch to 6.8 ([#71](https://github.com/quiltdata/iac/pull/71))
- [Changed] Increase CloudFormation stack update timeout from 30m to 1h ([#73](https://github.com/quiltdata/iac/pull/73))

## [1.0.0] - 2024-12-09

- [Added] Add changelog ([#74](https://github.com/quiltdata/iac/pull/74))

[Unreleased]: https://github.com/quiltdata/iac/compare/1.7.2...HEAD
[1.7.2]: https://github.com/quiltdata/iac/releases/tag/1.7.2
[1.7.1]: https://github.com/quiltdata/iac/releases/tag/1.7.1
[1.7.0]: https://github.com/quiltdata/iac/releases/tag/1.7.0
[1.6.0]: https://github.com/quiltdata/iac/releases/tag/1.6.0
[1.5.0]: https://github.com/quiltdata/iac/releases/tag/1.5.0
[1.4.0]: https://github.com/quiltdata/iac/releases/tag/1.4.0
[1.3.0]: https://github.com/quiltdata/iac/releases/tag/1.3.0
[1.2.0]: https://github.com/quiltdata/iac/releases/tag/1.2.0
[1.1.0]: https://github.com/quiltdata/iac/releases/tag/1.1.0
[1.0.0]: https://github.com/quiltdata/iac/releases/tag/1.0.0
