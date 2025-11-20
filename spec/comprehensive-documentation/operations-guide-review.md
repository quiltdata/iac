# OPERATIONS.md Review Checklist

**Branch**: `add-operations-guide`
**Document**: OPERATIONS.md
**Date**: 2025-11-20
**Status**: Separated from PR #88 (ElasticSearch/Variables) - now tracked independently

## Overview

OPERATIONS.md (1,082 lines) was initially included in PR #88 but represents a separate scope: comprehensive cloud team operations guide. This document tracks review items specific to OPERATIONS.md for the `add-operations-guide` branch.

---

## Review Items

### High Priority - Accuracy Verification

#### 1. Log Group Names Verification (Line 300)

**Thread**: PRRT_kwDOJnJ_Ds5Y9t1F
**Status**: ✅ VERIFIED - Issues Found
**Priority**: HIGH (accuracy - incorrect info could break operations)

**Task**: Verify that log group names at line 300 match actual CloudFormation template or deployed stack

**Action Items**:

- [x] Check line 300 of OPERATIONS.md for log group names
- [x] Compare against CloudFormation template in repository
- [ ] Verify against actual deployed stack (if available)
- [ ] Update documentation if discrepancies found
- [x] Document the source of truth for log group names

**Verification Results** (2025-11-20):

##### Issue 1: ECS Log Group Name - INCORRECT

- **OPERATIONS.md (Lines 293, 297)**: References `/aws/ecs/quilt-prod`
- **Template Reality**: [~/GitHub/deployment/t4/template/log.py:13](file:///Users/ernest/GitHub/deployment/t4/template/log.py#L13) creates LogGroup with `LogGroupName=Ref("AWS::StackName")`
- **Actual Log Group**: The log group name is just the stack name (e.g., `quilt-prod`), NOT `/aws/ecs/quilt-prod`
- **Correction Needed**: Change `/aws/ecs/quilt-prod` to just `quilt-prod` (or `${STACK_NAME}`)

##### Issue 2: CloudTrail Log Group - DOES NOT EXIST

- **OPERATIONS.md (Line 306)**: References `CloudTrail/QuiltAuditLogs`
- **Template Reality**: [~/GitHub/deployment/t4/template/analytics.py:76-91](file:///Users/ernest/GitHub/deployment/t4/template/analytics.py#L76-L91) shows CloudTrail only logs to S3 bucket
- **Actual Configuration**: CloudTrail writes to S3 bucket (CloudTrailBucket), NOT CloudWatch Logs
- **Correction Needed**: Either:
  1. Remove CloudWatch Logs CloudTrail example entirely, OR
  2. Document querying CloudTrail via Athena/S3, OR
  3. Note that CloudTrail CloudWatch Logs integration must be manually configured if desired

##### Source of Truth

- ECS/Container Logs: [~/GitHub/deployment/t4/template/log.py](file:///Users/ernest/GitHub/deployment/t4/template/log.py) (main LogGroup)
- Lambda Logs: [~/GitHub/deployment/t4/template/helpers.py:263](file:///Users/ernest/GitHub/deployment/t4/template/helpers.py#L263) (pattern: `/quilt/${AWS::StackName}/<lambda-name>`)
- Search Logs: [~/GitHub/deployment/t4/template/search.py:58](file:///Users/ernest/GitHub/deployment/t4/template/search.py#L58) (pattern: `/quilt/${AWS::StackName}/search/<suffix>`)
- CloudTrail: S3 bucket only, no CloudWatch Logs group by default

**Why Critical**: Operators using incorrect log group names will fail to retrieve logs during incident response.

---

#### 2. Non-existent Resource (Line 308)

**Thread**: PRRT_kwDOJnJ_Ds5Y9uBY
**Status**: ⏳ Needs Verification
**Priority**: HIGH (accuracy - documenting non-existent resources is problematic)

**Task**: Identify what resource at line 308 is questioned and verify its existence

**Action Items**:

- [ ] Review line 308 of OPERATIONS.md
- [ ] Check if resource exists in CloudFormation template
- [ ] Verify resource exists in actual deployments
- [ ] Remove or correct if resource is indeed non-existent
- [ ] Add clarification if resource is conditional/optional

**Why Critical**: Documenting non-existent resources causes confusion and erodes trust in the operations guide.

---

## Scope Discussion

### OPERATIONS.md Scope Decision

**Thread**: PRRT_kwDOJnJ_Ds5Y9vRp
**Status**: ✅ RESOLVED - Moved to separate branch
**Priority**: Medium (scope management)

**Original Question**: Is OPERATIONS.md out of scope for "ElasticSearch and All Variables" PR?

**Resolution**:

- ✅ OPERATIONS.md moved to separate `add-operations-guide` branch
- ✅ Will be submitted as separate PR after PR #88
- ✅ Allows PR #88 to focus on ElasticSearch and variable documentation
- ✅ Allows OPERATIONS.md to be reviewed independently

**Benefits**:

- Cleaner PR scope and review process
- Independent iteration on operations guide
- Parallel development possible
- Easier to track operations-specific feedback

---

## Next Steps

### Immediate Actions

1. ✅ Verify log group names at line 300 - COMPLETED (see findings above)
2. ⏳ Check resource at line 308 - PENDING (related to CloudTrail, likely same issue)
3. ✅ Document source of truth for operational data - COMPLETED

### After Verification

1. Update OPERATIONS.md with corrections
2. Add source attribution for verifiable claims
3. Consider adding validation checklist for operational data
4. Prepare for independent PR submission

### Future Considerations

- Add automated verification where possible
- Link to actual CloudFormation template sections
- Consider generating parts of OPERATIONS.md from IaC code

---

## Branch Information

**Branch**: `add-operations-guide`
**Base**: `main`
**Related PRs**:

- PR #88 (ElasticSearch/Variables) - separate scope
- Future PR #XX (Operations Guide) - this document's target

**Key Difference**: This branch focuses exclusively on the operations guide, while PR #88 focuses on ElasticSearch configuration and variable documentation.

---

## Verification Checklist

Before submitting operations guide PR:

- [x] B7: Log group names verified - Issues identified (needs correction in OPERATIONS.md)
- [ ] B8: Non-existent resource issue resolved - In progress (likely CloudTrail related)
- [ ] All operational commands tested against actual deployment
- [ ] All resource names match CloudFormation template
- [ ] All log groups confirmed to exist
- [ ] All monitoring dashboards/queries verified
- [ ] Disaster recovery procedures validated
- [ ] Health check procedures tested

---

## Notes

- OPERATIONS.md is a critical operational document
- Accuracy is paramount - incorrect information could cause production incidents
- Verification against actual infrastructure is essential
- Consider peer review by someone with production access
