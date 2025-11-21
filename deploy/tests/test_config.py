"""Tests for configuration management."""

import json
from pathlib import Path

import pytest

from lib.config import DeploymentConfig


def test_vpc_selection():
    """Test VPC selection logic."""
    vpcs = [
        {"vpc_id": "vpc-default", "name": "default", "is_default": True},
        {"vpc_id": "vpc-staging", "name": "quilt-staging", "is_default": False},
        {"vpc_id": "vpc-other", "name": "other", "is_default": False},
    ]

    vpc = DeploymentConfig._select_vpc(vpcs)
    assert vpc["vpc_id"] == "vpc-staging"


def test_vpc_selection_fallback():
    """Test VPC selection fallback to non-default."""
    vpcs = [
        {"vpc_id": "vpc-default", "name": "default", "is_default": True},
        {"vpc_id": "vpc-other", "name": "other", "is_default": False},
    ]

    vpc = DeploymentConfig._select_vpc(vpcs)
    assert vpc["vpc_id"] == "vpc-other"


def test_vpc_selection_no_suitable():
    """Test VPC selection with no suitable VPC."""
    vpcs = [
        {"vpc_id": "vpc-default", "name": "default", "is_default": True},
    ]

    with pytest.raises(ValueError, match="No suitable VPC found"):
        DeploymentConfig._select_vpc([vpcs[0]])


def test_subnet_selection():
    """Test subnet selection logic."""
    subnets = [
        {
            "subnet_id": "subnet-1",
            "vpc_id": "vpc-123",
            "classification": "public",
        },
        {
            "subnet_id": "subnet-2",
            "vpc_id": "vpc-123",
            "classification": "public",
        },
        {
            "subnet_id": "subnet-3",
            "vpc_id": "vpc-123",
            "classification": "private",
        },
    ]

    selected = DeploymentConfig._select_subnets(subnets, "vpc-123")
    assert len(selected) == 2
    assert all(s["classification"] == "public" for s in selected)


def test_subnet_selection_insufficient():
    """Test subnet selection with insufficient subnets."""
    subnets = [
        {
            "subnet_id": "subnet-1",
            "vpc_id": "vpc-123",
            "classification": "public",
        },
    ]

    with pytest.raises(ValueError, match="Need at least 2 public subnets"):
        DeploymentConfig._select_subnets(subnets, "vpc-123")


def test_certificate_selection():
    """Test certificate selection logic."""
    certificates = [
        {
            "arn": "arn:aws:acm:us-east-1:123:certificate/abc",
            "domain_name": "*.example.com",
            "status": "ISSUED",
        },
        {
            "arn": "arn:aws:acm:us-east-1:123:certificate/def",
            "domain_name": "*.other.com",
            "status": "ISSUED",
        },
    ]

    cert = DeploymentConfig._select_certificate(certificates, "example.com")
    assert cert["domain_name"] == "*.example.com"


def test_certificate_selection_no_match():
    """Test certificate selection with no match."""
    certificates = [
        {
            "arn": "arn:aws:acm:us-east-1:123:certificate/abc",
            "domain_name": "*.other.com",
            "status": "ISSUED",
        },
    ]

    with pytest.raises(ValueError, match="No valid certificate found"):
        DeploymentConfig._select_certificate(certificates, "example.com")


def test_route53_zone_selection():
    """Test Route53 zone selection logic."""
    zones = [
        {"zone_id": "Z123", "domain_name": "example.com.", "private": False},
        {"zone_id": "Z456", "domain_name": "other.com.", "private": False},
    ]

    zone = DeploymentConfig._select_route53_zone(zones, "example.com")
    assert zone["zone_id"] == "Z123"


def test_route53_zone_selection_no_match():
    """Test Route53 zone selection with no match."""
    zones = [
        {"zone_id": "Z123", "domain_name": "other.com.", "private": False},
    ]

    with pytest.raises(ValueError, match="No Route53 zone found"):
        DeploymentConfig._select_route53_zone(zones, "example.com")


def test_terraform_vars_external_iam():
    """Test Terraform variables for external IAM pattern."""
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="external-iam",
    )

    vars_dict = config.to_terraform_vars()

    assert vars_dict["name"] == "test-deployment"
    assert vars_dict["aws_region"] == "us-east-1"
    assert vars_dict["vpc_id"] == "vpc-123"
    assert "iam_template_url" in vars_dict
    assert "template_url" in vars_dict


def test_terraform_vars_inline_iam():
    """Test Terraform variables for inline IAM pattern."""
    config = DeploymentConfig(
        deployment_name="test-deployment",
        aws_region="us-east-1",
        aws_account_id="123456789012",
        environment="test",
        vpc_id="vpc-123",
        subnet_ids=["subnet-1", "subnet-2"],
        security_group_ids=["sg-1"],
        certificate_arn="arn:aws:acm:us-east-1:123:certificate/abc",
        route53_zone_id="Z123",
        domain_name="example.com",
        quilt_web_host="test.example.com",
        admin_email="admin@example.com",
        pattern="inline-iam",
    )

    vars_dict = config.to_terraform_vars()

    assert vars_dict["name"] == "test-deployment"
    assert "iam_template_url" not in vars_dict
    assert "template_url" in vars_dict
