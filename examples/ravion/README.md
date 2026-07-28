# Deploying `modules/quilt` via Ravion

[Ravion](https://www.ravion.com) is an Internal Developer Platform (IDP) that
runs Terraform/OpenTofu on temporary runners inside a connected AWS account,
and exposes infrastructure as typed, form-fillable modules.

This directory demonstrates deploying Quilt through Ravion **without forking
any Terraform**: [`module.yaml`](module.yaml) is a Ravion module definition
that wraps [`main.tf`](main.tf), which in turn calls `modules/quilt` and
`modules/cnames` from this repo unmodified, using the same
`provider` / `module "quilt"` / `parameters` root-config pattern documented
in [`examples/main.tf`](../main.tf).

## How the pieces fit together

- **`module.yaml`** declares the handful of typed inputs a deploy actually
  needs (name, catalog domain, sizing, network mode, admin email) instead of
  raw HCL, plus two `$ref` inputs — `certificate_ref` and `dns_ref` — that
  Ravion resolves against other Ravion-managed modules rather than requiring
  a hand-copied certificate ARN or hosted-zone ID.
- **`main.tf`** receives those resolved values as plain Terraform variables
  (`certificate_arn`, `zone_id`, …) and calls `modules/quilt` /
  `modules/cnames` exactly as a manual deploy would.
- **The CloudFormation template is never committed here.** `module.yaml`'s
  `template_url` input points at the template for the desired Quilt release
  (e.g. one of this project's existing published per-release S3 artifacts);
  Ravion fetches it at plan/apply time and hands the resulting local path to
  `template_file`. Nothing generated or internal is checked into this repo.

## Hostname / certificate coverage

Quilt's public hostname contract is the catalog host plus two derived
siblings:

- `<catalog_domain>` — the catalog itself
- `<sub>-registry.<rest>` — the registry API
- `<sub>-s3-proxy.<rest>` — the S3 proxy

`main.tf` derives all three into `local.hostnames` (and exposes them as the
`hostnames` output). Ravion should validate that the certificate resolved
via `certificate_ref` covers all three SANs before allowing `apply` — a
certificate that only covers the catalog host will deploy a stack whose
registry or s3-proxy endpoint has no valid TLS.

## Cross-account composition (certificate + stack + DNS)

The common case for larger customers is that the AWS account deploying the
stack does **not** own the domain. In that setup:

- The **certificate** module (ACM, DNS-validated) runs in the account that
  owns the Route53 zone.
- The **DNS** module (`modules/cnames`) also runs in that same
  domain-owning account, since it writes into the hosted zone.
- The **Quilt stack** (`module.yaml` / `main.tf` in this directory) runs in
  the deploying account, and references the certificate and DNS modules via
  `certificate_ref` / `dns_ref`.

Ravion's typed `$ref` module-composition mechanism resolves outputs across
these Ravion-connected accounts, so the certificate ARN and CNAME records
are wired in automatically rather than hand-copied between teams. This is a
supported Ravion pattern, not a workaround — call it out explicitly when
onboarding a customer whose deploying and domain-owning accounts differ.

## Provisioning script

[`scripts/provision-quilt.sh`](scripts/provision-quilt.sh) wraps the three
`ravion module create` calls needed to stand up a deployment — the
`rvn-route53` reference, the `rvn-acm-certificate` covering all three derived
hostnames, and the `quilt-catalog` instance that `$ref`s both — into one
command, threading the `minst_…` instance ids between them so nobody has to
hand-copy them. Run it with `--dry-run` first to see the exact commands it
would issue; `--dns-instance-id` / `--cert-instance-id` let you reuse
already-applied instances instead of creating new ones.

## In-place updates

Changing a typed input in Ravion (e.g. `sizing`, `catalog_domain`) re-plans
and re-applies the same `module "quilt"` / `module "cnames"` resources in
place, the same as re-running `terraform apply` with an edited
`examples/main.tf` — no destroy/recreate.

## Relationship to `examples/main.tf`

This is a Ravion-specific wrapper, not a replacement for the manual example
in [`examples/main.tf`](../main.tf). Use `examples/main.tf` for a standalone
`terraform apply`; use this directory as the module definition when
onboarding this repo into a Ravion catalog.
