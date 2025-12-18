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

[Unreleased]: https://github.com/quiltdata/iac/compare/1.4.0...HEAD
[1.4.0]: https://github.com/quiltdata/iac/releases/tag/1.4.0
[1.3.0]: https://github.com/quiltdata/iac/releases/tag/1.3.0
[1.2.0]: https://github.com/quiltdata/iac/releases/tag/1.2.0
[1.1.0]: https://github.com/quiltdata/iac/releases/tag/1.1.0
[1.0.0]: https://github.com/quiltdata/iac/releases/tag/1.0.0
