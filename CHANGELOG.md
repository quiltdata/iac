# Changelog

<!-- template:
## [Unreleased] - YYYY-MM-DD

Optional release notice.

- [Verb] Change description ([#<PR-number>](https://github.com/quiltdata/iac/pull/<PR-number>))
-->

## [Unreleased]

- Chanded documentation to include elasticsearch instance sizing in the `Quilt` tf module. ([#79](https://github.com/quiltdata/iac/pull/79))

## [1.1.0] - 2024-12-20

- [Changed] Increase default CloudFormation stack delete timeout from 1h to 1h30m ([#78](https://github.com/quiltdata/iac/pull/78))
- [Fixed] Really use `on_failure` variable, previously CloudFormation stack `on_failure` was hardcoded to `ROLLBACK` ([#77](https://github.com/quiltdata/iac/pull/77))
- [Fixed] Add CloudFormation stack `on_failure` to `lifecycle.ignore_changes`, so stacks created before [`0ca3e1319cc89557ea31b3553012562d0e9a0b81`](https://github.com/quiltdata/iac/commit/0ca3e1319cc89557ea31b3553012562d0e9a0b81) won't be re-created on update by default ([#77](https://github.com/quiltdata/iac/pull/77))
- [Changed] Update Elasticsearch to 6.8 ([#71](https://github.com/quiltdata/iac/pull/71))
- [Changed] Increase CloudFormation stack update timeout from 30m to 1h ([#73](https://github.com/quiltdata/iac/pull/73))

## [1.0.0] - 2024-12-09

- [Added] Add changelog ([#74](https://github.com/quiltdata/iac/pull/74))

[Unreleased]: https://github.com/quiltdata/iac/compare/1.1.0...HEAD
[1.1.0]: https://github.com/quiltdata/iac/releases/tag/1.1.0
[1.0.0]: https://github.com/quiltdata/iac/releases/tag/1.0.0
