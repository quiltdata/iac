#!/usr/bin/env bash
#
# Provisions a Quilt deployment through Ravion end to end: the Route 53 DNS
# reference, the multi-SAN ACM certificate, and the quilt-catalog instance
# that $refs both. See ../../../09-blog-deploying-quilt-via-ravion.md (Step 4
# and Step 5) in the 260723-ravion evaluation project for the manual version
# of these three `ravion module create` calls this replaces.
#
# Quilt's public hostname contract is the catalog host plus two derived
# siblings (<sub>-registry.<rest> / <sub>-s3-proxy.<rest>>) — see main.tf's
# `local.hostnames`. This script computes all three the same way and passes
# them to rvn-acm-certificate's `domains` input, so the cert can't
# accidentally cover only the catalog host.
#
# Requires: the `ravion` CLI (authenticated) and `jq`.

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: provision-quilt.sh [options]

Required:
  --catalog-domain DOMAIN        Public catalog hostname, e.g. quilt.customer.com
  --name NAME                    Stack name (<=20 chars, lowercase alphanumeric + hyphens)
  --template-url URL             Published Quilt CloudFormation template URL
  --admin-email EMAIL            Initial admin account email

  --dns-environment-id ID         env_… for the domain-owning environment
  --dns-account-id ID             awsact_… that owns the Route53 zone
  --zone-id ID                    Existing Route53 hosted zone ID (e.g. Z1234567890ABC)

  --cert-account-id ID            awsact_… for the ALB/deploying account (ACM cert must
                                   live in the same account/region as the load balancer)

  --quilt-environment-id ID       env_… for the deploying environment
  --quilt-account-id ID           awsact_… the Quilt stack deploys into

Optional:
  --given-id-prefix PREFIX        Prefix for module given-ids (default: quilt)
  --dns-region REGION             Default: us-east-1
  --cert-environment-id ID        Default: same as --dns-environment-id
  --cert-region REGION            Default: same as --dns-region
  --quilt-region REGION           Default: us-east-1
  --sizing SIZE                   small|medium|large|xlarge (default: medium)
  --dns-instance-id ID            Reuse an existing rvn-route53 instance instead of
                                   creating one (skips --dns-* / --zone-id)
  --cert-instance-id ID           Reuse an existing rvn-acm-certificate instance instead
                                   of creating one (skips --cert-* / --zone-id)
  --dry-run                       Print the ravion commands instead of running them
  -h, --help                      Show this help

All three underlying `ravion module create` calls use --initial-stack-run
APPLY, i.e. this creates and applies real infrastructure.
EOF
}

given_id_prefix=quilt
dns_region=us-east-1
cert_region=
quilt_region=us-east-1
sizing=medium
dns_instance_id=
cert_instance_id=
dry_run=0

catalog_domain=
name=
template_url=
admin_email=
dns_environment_id=
dns_account_id=
zone_id=
cert_environment_id=
cert_account_id=
quilt_environment_id=
quilt_account_id=

while [[ $# -gt 0 ]]; do
  case "$1" in
    --catalog-domain) catalog_domain="$2"; shift 2 ;;
    --name) name="$2"; shift 2 ;;
    --template-url) template_url="$2"; shift 2 ;;
    --admin-email) admin_email="$2"; shift 2 ;;
    --sizing) sizing="$2"; shift 2 ;;
    --given-id-prefix) given_id_prefix="$2"; shift 2 ;;
    --dns-environment-id) dns_environment_id="$2"; shift 2 ;;
    --dns-account-id) dns_account_id="$2"; shift 2 ;;
    --dns-region) dns_region="$2"; shift 2 ;;
    --zone-id) zone_id="$2"; shift 2 ;;
    --cert-environment-id) cert_environment_id="$2"; shift 2 ;;
    --cert-account-id) cert_account_id="$2"; shift 2 ;;
    --cert-region) cert_region="$2"; shift 2 ;;
    --quilt-environment-id) quilt_environment_id="$2"; shift 2 ;;
    --quilt-account-id) quilt_account_id="$2"; shift 2 ;;
    --quilt-region) quilt_region="$2"; shift 2 ;;
    --dns-instance-id) dns_instance_id="$2"; shift 2 ;;
    --cert-instance-id) cert_instance_id="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 1 ;;
  esac
done

cert_environment_id="${cert_environment_id:-$dns_environment_id}"
cert_region="${cert_region:-$dns_region}"

for bin in ravion jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "Missing required tool: $bin" >&2; exit 1; }
done

missing=()
[[ -n "$catalog_domain" ]] || missing+=(--catalog-domain)
[[ -n "$name" ]] || missing+=(--name)
[[ -n "$template_url" ]] || missing+=(--template-url)
[[ -n "$admin_email" ]] || missing+=(--admin-email)
[[ -n "$quilt_environment_id" ]] || missing+=(--quilt-environment-id)
[[ -n "$quilt_account_id" ]] || missing+=(--quilt-account-id)
if [[ -z "$dns_instance_id" ]]; then
  [[ -n "$dns_environment_id" ]] || missing+=(--dns-environment-id)
  [[ -n "$dns_account_id" ]] || missing+=(--dns-account-id)
  [[ -n "$zone_id" ]] || missing+=(--zone-id)
fi
if [[ -z "$cert_instance_id" ]]; then
  [[ -n "$cert_account_id" ]] || missing+=(--cert-account-id)
  [[ -n "$zone_id" ]] || missing+=(--zone-id)
fi
if [[ ${#missing[@]} -gt 0 ]]; then
  printf 'Missing required argument(s): %s\n\n' "${missing[*]}" >&2
  usage >&2
  exit 1
fi

# Same derivation as main.tf's local.hostnames: split on the first dot.
if [[ ! "$catalog_domain" =~ ^([^.]+)(\..*)$ ]]; then
  echo "--catalog-domain must be a hostname with at least one dot: $catalog_domain" >&2
  exit 1
fi
subdomain="${BASH_REMATCH[1]}"
remainder="${BASH_REMATCH[2]}"
registry_host="${subdomain}-registry${remainder}"
proxy_host="${subdomain}-s3-proxy${remainder}"

echo "Derived hostnames: $catalog_domain, $registry_host, $proxy_host" >&2

run_ravion_create() {
  # $1=given-id $2=display name $3=type $4=environment-id $5=input JSON
  if [[ $dry_run -eq 1 ]]; then
    echo "--- dry run: ravion module create ---" >&2
    printf 'ravion module create --environment-id %q --given-id %q --name %q --type %q --input %q --initial-stack-run APPLY --json\n' \
      "$4" "$1" "$2" "$3" "$5" >&2
    echo '{"id":"minst_dryrun"}'
    return
  fi
  ravion module create \
    --environment-id "$4" \
    --given-id "$1" \
    --name "$2" \
    --type "$3" \
    --input "$5" \
    --initial-stack-run APPLY \
    --json
}

if [[ -n "$dns_instance_id" ]]; then
  echo "Reusing existing rvn-route53 instance: $dns_instance_id" >&2
else
  dns_input=$(jq -n \
    --arg aws_account_id "$dns_account_id" \
    --arg aws_region "$dns_region" \
    --arg zone_id "$zone_id" \
    '{aws_account_id: $aws_account_id, aws_region: $aws_region, zone_creation_enabled: false, zone_id: $zone_id}')

  echo "Creating rvn-route53 instance..." >&2
  dns_instance_id=$(run_ravion_create "${given_id_prefix}-dns" "Quilt DNS zone" rvn-route53 "$dns_environment_id" "$dns_input" | jq -r '.id')
  echo "  -> $dns_instance_id" >&2
fi

if [[ -n "$cert_instance_id" ]]; then
  echo "Reusing existing rvn-acm-certificate instance: $cert_instance_id" >&2
else
  cert_input=$(jq -n \
    --arg aws_account_id "$cert_account_id" \
    --arg aws_region "$cert_region" \
    --arg catalog_domain "$catalog_domain" \
    --arg registry_host "$registry_host" \
    --arg proxy_host "$proxy_host" \
    --arg route53_zone_id "$zone_id" \
    '{aws_account_id: $aws_account_id, aws_region: $aws_region,
      domains: [$catalog_domain, $registry_host, $proxy_host],
      route53_validation_records_creation_enabled: true,
      route53_zone_id: $route53_zone_id,
      certificate_validation_wait_enabled: true}')

  echo "Creating rvn-acm-certificate instance (blocks until DNS-validated)..." >&2
  cert_instance_id=$(run_ravion_create "${given_id_prefix}-cert" "Quilt ACM certificate" rvn-acm-certificate "$cert_environment_id" "$cert_input" | jq -r '.id')
  echo "  -> $cert_instance_id" >&2
fi

quilt_input=$(jq -n \
  --arg name "$name" \
  --arg template_url "$template_url" \
  --arg catalog_domain "$catalog_domain" \
  --arg admin_email "$admin_email" \
  --arg sizing "$sizing" \
  --arg aws_account_id "$quilt_account_id" \
  --arg aws_region "$quilt_region" \
  --arg certificate "$cert_instance_id" \
  --arg dns "$dns_instance_id" \
  '{name: $name, template_url: $template_url, catalog_domain: $catalog_domain,
    admin_email: $admin_email, sizing: $sizing, aws_account_id: $aws_account_id,
    aws_region: $aws_region, certificate: $certificate, dns: $dns}')

echo "Creating quilt-catalog instance..." >&2
quilt_instance_id=$(run_ravion_create "$given_id_prefix" "Customer Quilt deployment" quilt-catalog "$quilt_environment_id" "$quilt_input" | jq -r '.id')
echo "  -> $quilt_instance_id" >&2

cat <<EOF

Done.
  dns instance:   $dns_instance_id
  cert instance:  $cert_instance_id
  quilt instance: $quilt_instance_id
  quilt_url:      https://$catalog_domain
EOF
