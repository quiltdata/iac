# PR #88 Comments Checklist

**PR Title**: Comprehensive Documentation Improvements for ElasticSearch and All Variables
**PR URL**: https://github.com/quiltdata/iac/pull/88
**Created**: 2025-08-28
**Status**: Under Review

## Overview

This document tracks all comments and review feedback on PR #88 to ensure systematic resolution.

---

## Main Issue Comments

### Comment 1: sir-sigurd (MEMBER) - Main Documentation Concern
**Date**: 2025-08-29 12:37:27Z
**Comment ID**: IC_kwDOJnJ_Ds7A7zsw
**URL**: https://github.com/quiltdata/iac/pull/88#issuecomment-3236903728

**Content**:
> This PR addresses the customer concern about lacking documentation for ElasticSearch EBS volume
>
> IMO that could be addressed simply by stating that the table [here](https://github.com/quiltdata/iac?tab=readme-ov-file#quilt-module-arguments) doesn't list all variables so you need to check variables.tf
>
> also `search_volume_size` is already mentioned [here](https://github.com/quiltdata/iac?tab=readme-ov-file#rightsize-your-search-domain)

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Consider simpler approach: just reference variables.tf instead of duplicating docs
- [ ] Note that ElasticSearch configuration already exists in "Rightsize your search domain" section
- [ ] Address documentation duplication concern

---

## Review Comments

### Review 1: greptile-apps (Bot)
**Review ID**: PRR_kwDOJnJ_Ds68vKmS
**State**: COMMENTED
**Date**: 2025-08-28 20:56:11Z

#### Comment 1.1: Hardcoded Account ID in examples/main.tf
**Thread ID**: PRRT_kwDOJnJ_Ds6JmUnx (inferred)
**Comment ID**: PRRC_kwDOJnJ_Ds6JmUnx
**File**: examples/main.tf

**Content**:
> style: Replace hardcoded example account ID with placeholder format like `"YOUR-ACCOUNT-ID"`

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Replace hardcoded AWS account IDs with YOUR-ACCOUNT-ID placeholder
- [ ] Verify all examples use placeholders

#### Comment 1.2: Hardcoded Bucket/Region in examples/main.tf
**Thread ID**: PRRT_kwDOJnJ_Ds6JmUoA (inferred)
**Comment ID**: PRRC_kwDOJnJ_Ds6JmUoA
**File**: examples/main.tf

**Content**:
> style: Use placeholder values instead of hardcoded examples to prevent accidental deployment with wrong bucket/region

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Replace hardcoded S3 bucket names with placeholders
- [ ] Replace hardcoded regions with YOUR-AWS-REGION placeholder
- [ ] Add warning about replacing placeholders

#### General Review Summary
**Issues Raised**:
- PR description missing required "component changes" section
- Examples contain hardcoded values (AWS account IDs, S3 buckets)
- Authentication parameter names may not match CloudFormation template
- Security concerns about hardcoded values

**Confidence Score**: 3/5

---

### Review 2: kevinemoore (MEMBER)
**Review ID**: PRR_kwDOJnJ_Ds68xpnY
**State**: APPROVED
**Date**: 2025-08-29 02:22:44Z

**No comments** - Approved without comments

---

### Review 3: sir-sigurd (MEMBER) - Detailed Code Review
**Review ID**: PRR_kwDOJnJ_Ds680h5S
**State**: COMMENTED
**Date**: 2025-08-29 12:22:51Z

#### Comment 3.1: CHANGELOG.md - Duplicate Entries
**Thread ID**: PRRT_kwDOJnJ_Ds5Y8awo
**Comment ID**: PRRC_kwDOJnJ_Ds6JqPkS
**File**: CHANGELOG.md
**Line**: 31

**Content**:
> all these entries seem to be about the same thing

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Review CHANGELOG entries around line 31
- [ ] Consolidate duplicate or similar entries
- [ ] Make changelog more concise

#### Comment 3.2: CHANGELOG.md - Too Verbose
**Thread ID**: PRRT_kwDOJnJ_Ds5Y8b6N
**Comment ID**: PRRC_kwDOJnJ_Ds6JqRKo
**File**: CHANGELOG.md
**Line**: 13

**Content**:
> I'm not sure we need changelog entries for this kind of changes
> even if we decide we need them I think we need something concise that can be easily digested by end-user

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Evaluate if CHANGELOG entries are necessary for documentation changes
- [ ] If kept, make them more concise and user-friendly
- [ ] Focus on user-facing changes

#### Comment 3.3: EXAMPLES.md - Formatting Inconsistency
**Thread ID**: PRRT_kwDOJnJ_Ds5Y8cm4
**Comment ID**: PRRC_kwDOJnJ_Ds6JqSII
**File**: EXAMPLES.md
**Line**: 179

**Content**:
> this formatting (no blank line after heading) seems inconsistent
> (we should have markdownlint CI job for that, but of course that work is for another PR)

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Add blank line after heading at line 179
- [ ] Check for consistent markdown formatting throughout EXAMPLES.md
- [ ] Note: markdownlint CI is future work (not this PR)

#### Comment 3.4: EXAMPLES.md - Inconsistent Placeholder Prominence
**Thread ID**: PRRT_kwDOJnJ_Ds5Y8iLo
**Comment ID**: PRRC_kwDOJnJ_Ds6JqZrb
**File**: EXAMPLES.md
**Line**: 9

**Content**:
> I'm not sure why we use prominent PLACEHOLDERS for some places and not so prominent in others (e.g. state bucket, zone id, etc.)

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Review all placeholders in EXAMPLES.md
- [ ] Make placeholder style consistent (all should be prominent like YOUR-ACCOUNT-ID)
- [ ] Consider: state bucket names, zone IDs, domain names, etc.

#### Comment 3.5: EXAMPLES.md - Indentation for terraform fmt
**Thread ID**: PRRT_kwDOJnJ_Ds5Y8lh6
**Comment ID**: PRRC_kwDOJnJ_Ds6JqeSQ
**File**: EXAMPLES.md
**Line**: 333

**Content**:
> would be nice to have consistent indentation (here and in other places) so it pass `terraform fmt`

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Review indentation at line 333 and throughout EXAMPLES.md
- [ ] Ensure all terraform code blocks follow `terraform fmt` standards
- [ ] Run examples through terraform fmt for validation

#### Comment 3.6: EXAMPLES.md - Show Only Specific Parameters
**Thread ID**: PRRT_kwDOJnJ_Ds5Y8mj1
**Comment ID**: PRRC_kwDOJnJ_Ds6JqftN
**File**: EXAMPLES.md
**Line**: 362

**Content**:
> probably it makes more sense to show only specific parameters

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Review parameters shown at line 362
- [ ] Consider showing only relevant parameters for the example
- [ ] Remove unnecessary/common parameters to reduce noise

#### Comment 3.7: EXAMPLES.md - Unrealistic DB Configuration
**Thread ID**: PRRT_kwDOJnJ_Ds5Y8rHp
**Comment ID**: PRRC_kwDOJnJ_Ds6JqmB0
**File**: EXAMPLES.md
**Line**: 569

**Content**:
> DB currently has quite low load so I doubt anyone would need this unless they want to burn some money

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Review DB configuration at line 569
- [ ] Adjust to more realistic/cost-effective instance type
- [ ] Add note about actual DB load requirements

#### Comment 3.8: EXAMPLES.md - Default Configuration Question
**Thread ID**: PRRT_kwDOJnJ_Ds5Y8tWt
**Comment ID**: PRRC_kwDOJnJ_Ds6JqpBF
**File**: EXAMPLES.md
**Line**: 845

**Content**:
> do we have it enabled by default?

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Check what configuration is being discussed at line 845
- [ ] Verify if it's enabled by default
- [ ] Update example/comment to reflect actual default behavior

#### Comment 3.9: EXAMPLES.md - Unclear Content
**Thread ID**: PRRT_kwDOJnJ_Ds5Y8vDl
**Comment ID**: PRRC_kwDOJnJ_Ds6JqrTP
**File**: EXAMPLES.md
**Line**: 867

**Content**:
> 🤔

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Review content at line 867
- [ ] Clarify what seems confusing or questionable
- [ ] Request specific feedback from sir-sigurd on what the concern is

#### Comment 3.10: OPERATIONS.md - Log Group Names Source
**Thread ID**: PRRT_kwDOJnJ_Ds5Y9t1F
**Comment ID**: PRRC_kwDOJnJ_Ds6JsAgt
**File**: OPERATIONS.md
**Line**: 300

**Content**:
> Where did these log group names come from?

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Verify log group names at line 300 are accurate
- [ ] Check against actual CloudFormation template or deployed resources
- [ ] Update with correct names or add note about variability

#### Comment 3.11: OPERATIONS.md - Non-existent Resource
**Thread ID**: PRRT_kwDOJnJ_Ds5Y9uBY
**Comment ID**: PRRC_kwDOJnJ_Ds6JsAxS
**File**: OPERATIONS.md
**Line**: 308

**Content**:
> I don't think something like this exists

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Review content at line 308
- [ ] Verify if the resource/feature exists in actual deployments
- [ ] Remove or correct if inaccurate

#### Comment 3.12: OPERATIONS.md - Scope Creep
**Thread ID**: PRRT_kwDOJnJ_Ds5Y9vRp
**Comment ID**: PRRC_kwDOJnJ_Ds6JsCcm
**File**: OPERATIONS.md
**Line**: (no specific line - general comment)

**Content**:
> that looks out of PR scope stated in its name
> also that's looks like too much information to be easily used

**Resolution Status**: [ ] Not Resolved

**Action Items**:
- [ ] Review if OPERATIONS.md is within scope of "ElasticSearch and All Variables" PR title
- [ ] Consider splitting operational docs into separate PR
- [ ] Simplify/reduce OPERATIONS.md content if it remains in this PR

---

## Summary Statistics

**Total Comments**: 15 (1 main issue + 2 review bot + 12 detailed review)

**By Reviewer**:
- sir-sigurd: 13 comments (1 main + 12 review)
- greptile-apps: 2 comments (bot review)
- kevinemoore: 0 comments (approved)

**By File**:
- CHANGELOG.md: 2 comments
- EXAMPLES.md: 7 comments
- OPERATIONS.md: 3 comments
- examples/main.tf: 2 comments
- General PR structure: 1 comment

**Resolution Status**:
- [ ] Resolved: 0
- [ ] Not Resolved: 15
- [ ] Needs Discussion: 0

---

## Next Steps

1. [ ] Review all comments systematically
2. [ ] Determine which comments have already been addressed by existing commits
3. [ ] Address remaining valid concerns
4. [ ] Mark resolved threads using GitHub API
5. [ ] Respond to comments requiring discussion/clarification
