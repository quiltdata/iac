#!/usr/bin/env python3
# File: test/validate-names.py

import sys
import yaml
import re

def main():
    if len(sys.argv) != 3:
        print("Usage: validate-names.py <iam-template> <app-template>")
        sys.exit(1)

    iam_template_path = sys.argv[1]
    app_template_path = sys.argv[2]

    # Load templates
    with open(iam_template_path) as f:
        iam_template = yaml.safe_load(f)

    with open(app_template_path) as f:
        app_template = yaml.safe_load(f)

    # Extract IAM output names (remove 'Arn' suffix)
    iam_outputs = set()
    for output_name in iam_template.get('Outputs', {}).keys():
        if output_name.endswith('Arn'):
            iam_outputs.add(output_name[:-3])  # Remove 'Arn'
        else:
            iam_outputs.add(output_name)

    # Extract application parameter names
    app_parameters = set(app_template.get('Parameters', {}).keys())

    # Find mismatches
    missing_params = iam_outputs - app_parameters
    extra_params = app_parameters - iam_outputs

    if missing_params:
        print(f"ERROR: IAM outputs missing in app parameters: {missing_params}")
        sys.exit(1)

    if extra_params:
        # Filter out non-IAM parameters (infrastructure params)
        iam_related = {p for p in extra_params if 'Role' in p or 'Policy' in p}
        if iam_related:
            print(f"ERROR: Extra IAM parameters in app template: {iam_related}")
            sys.exit(1)

    print(f"✓ All {len(iam_outputs)} IAM outputs have matching parameters")
    sys.exit(0)

if __name__ == '__main__':
    main()
