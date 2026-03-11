# ==============================================================================
# TERRAGRUNT GLOBAL VARIABLES - ENTERPRISE AZURE NAMING AND CONFIGURATION
# ==============================================================================
# Global variable definitions for enterprise Azure infrastructure deployments
# using Terragrunt orchestration, providing standardized naming conventions,
# environment configuration, and enterprise governance patterns for consistent
# infrastructure management across development, staging, and production environments.
#
# ENTERPRISE NAMING CONVENTION FRAMEWORK AND GOVERNANCE:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ STANDARDIZED NAMING PATTERNS AND ENTERPRISE ORGANIZATION:                   │
# │ • Consistent resource naming across all Azure services and environments     │
# │ • Enterprise governance with standardized naming taxonomy and conventions   │
# │ • Multi-environment support with environment-specific naming patterns       │
# │ • Regional deployment support with location-aware naming strategies         │
# │                                                                             │
# │ AZURE ENTERPRISE INTEGRATION AND COMPLIANCE:                                │
# │ • Azure AD tenant integration with centralized identity management          │
# │ • Subscription-based resource organization for enterprise billing control   │
# │ • Compliance framework support with audit-ready naming and tagging          │ 
# │ • Multi-tenant deployment support with tenant-specific configuration        │
# │                                                                             │
# │ OPERATIONAL EXCELLENCE AND AUTOMATION:                                      │
# │ • Automated resource naming with consistent pattern application             │
# │ • Infrastructure-as-Code standardization with repeatable deployments        │
# │ • Team collaboration enhancement with predictable resource identification   │
# │ • Troubleshooting efficiency with systematic naming and organization        │
# │                                                                             │
# │ ENTERPRISE NAMING TAXONOMY AND STRUCTURE:                                   │
# │ • Customer/Organization: Business unit or organizational identifier         │
# │ • Cloud Provider: Azure platform identifier for multi-cloud environments    │
# │ • Environment: Deployment stage (development, staging, production)          │
# │ • Region: Azure region for geographic deployment and compliance             │
# │ • Service: Azure service type for resource categorization and management    │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# NAMING CONVENTION PATTERN AND ENTERPRISE STANDARDS:
# Format: "{customer}-{provider}-{region}-{environment}-{service}-{resource}"
# Example: "sre-azr-eus-dev-vnet-001" (SRE, Azure, East US, Development, Virtual Network, Instance 001)
#
# GLOBAL VARIABLE INHERITANCE AND COMPOSITION:
# These variables are inherited by all Terragrunt modules through the root.hcl
# configuration, ensuring consistent naming and configuration across the entire
# infrastructure deployment with enterprise governance and standardization.
#
# ENTERPRISE GOVERNANCE BENEFITS:
# • Cost Management: Subscription and environment-based cost allocation and tracking
# • Security Compliance: Tenant-based access control and identity management integration
# • Operational Excellence: Standardized naming for monitoring, alerting, and automation
# • Multi-Environment Support: Consistent patterns across development, staging, production

locals {
  # ==============================================================================
  # CUSTOMER IDENTIFIER - ORGANIZATIONAL AND BUSINESS UNIT DESIGNATION
  # ==============================================================================
  # Organizational identifier representing the customer, business unit, or
  # organizational entity responsible for the Azure infrastructure deployment,
  # enabling enterprise resource organization and cost allocation management.
  #
  # CUSTOMER IDENTIFIER CHARACTERISTICS:
  # • Format: Lowercase alphanumeric abbreviation (3-5 characters recommended)
  # • Purpose: Business unit identification and resource ownership attribution
  # • Usage: Prepended to all resource names for organizational clarity
  # • Examples: "sre" (Site Reliability Engineering), "dev" (Development), "ops" (Operations)
  #
  # ENTERPRISE ORGANIZATIONAL BENEFITS:
  # • Resource ownership attribution for accountability and management
  # • Cost allocation and chargeback based on organizational structure
  # • Access control and governance based on business unit responsibilities
  # • Audit trail and compliance documentation with organizational mapping
  #
  # NAMING CONVENTION IMPACT:
  # • Resource Names: "sre-azr-eus-dev-vnet-001" (customer prefix identification)
  # • Resource Groups: "rg-sre-azr-eus-dev-networking" (organizational ownership)
  # • Tags: {"Customer": "sre", "BusinessUnit": "Site Reliability Engineering"}
  # • Billing: Customer-based cost allocation and financial management
  customer = "sre"

  # ==============================================================================
  # CLOUD PROVIDER IDENTIFIER - AZURE PLATFORM DESIGNATION AND MULTI-CLOUD SUPPORT
  # ==============================================================================
  # Cloud provider identifier designating Azure as the target infrastructure
  # platform, enabling multi-cloud naming consistency and platform-specific
  # resource organization for enterprise hybrid and multi-cloud deployments.
  #
  # PROVIDER IDENTIFIER CHARACTERISTICS:
  # • Format: Lowercase three-letter abbreviation for Azure platform
  # • Purpose: Cloud platform identification in multi-cloud enterprise environments
  # • Usage: Embedded in resource names for platform clarity and organization
  # • Standard: "azr" (Azure), consistent with enterprise multi-cloud naming conventions
  #
  # MULTI-CLOUD ENTERPRISE BENEFITS:
  # • Platform identification in hybrid and multi-cloud deployments
  # • Consistent naming patterns across AWS, Azure, GCP enterprise environments
  # • Infrastructure automation with platform-aware deployment strategies
  # • Cost management and platform-specific billing allocation and tracking
  #
  # NAMING CONVENTION IMPACT:
  # • Resource Names: "sre-azr-eus-dev-vnet-001" (Azure platform identification)
  # • Cross-Platform Consistency: "sre-aws-use1-dev-vpc-001" (AWS equivalent)
  # • Tags: {"CloudProvider": "Azure", "Platform": "azr"}
  # • Monitoring: Platform-specific observability and performance tracking
  provider = "azr"

  # ==============================================================================
  # ENVIRONMENT DESIGNATION - DEPLOYMENT STAGE AND LIFECYCLE MANAGEMENT
  # ==============================================================================
  # Environment identifier designating the deployment stage and lifecycle
  # phase for Azure infrastructure resources, enabling environment-specific
  # configuration, access control, and enterprise governance patterns.
  #
  # ENVIRONMENT IDENTIFIER CHARACTERISTICS:
  # • Format: Lowercase abbreviation representing deployment stage
  # • Purpose: Environment isolation and lifecycle management
  # • Usage: Critical component of resource naming for environment identification
  # • Standards: "dev" (Development), "stg" (Staging), "prd" (Production)
  #
  # ENTERPRISE ENVIRONMENT BENEFITS:
  # • Environment isolation with clear resource separation and organization
  # • Access control and security policies based on environment classification
  # • Deployment automation with environment-specific configuration management
  # • Cost management with environment-based budget allocation and tracking
  #
  # ENVIRONMENT-SPECIFIC CONFIGURATION PATTERNS:
  # • Development: Flexible resource configuration for rapid iteration and testing
  # • Staging: Production-like configuration for integration testing and validation
  # • Production: Enterprise-grade configuration with high availability and security
  # • Disaster Recovery: Specialized configuration for business continuity planning
  #
  # NAMING CONVENTION IMPACT:
  # • Resource Names: "sre-azr-eus-dev-vnet-001" (development environment identification)
  # • Access Control: Environment-based RBAC and permission management
  # • Tags: {"Environment": "Development", "Stage": "dev"}
  # • Policies: Environment-specific Azure Policy and governance enforcement
  environment = "dev"

  # ==============================================================================
  # AZURE SUBSCRIPTION IDENTIFIER - ENTERPRISE SUBSCRIPTION MANAGEMENT
  # ==============================================================================
  # Azure subscription identifier for enterprise resource organization,
  # billing management, and access control within the Azure enterprise
  # deployment framework, enabling multi-subscription governance patterns.
  #
  # SUBSCRIPTION IDENTIFIER CHARACTERISTICS:
  # • Format: Standard Azure subscription GUID (UUID format)
  # • Purpose: Azure resource organization and billing boundary definition
  # • Usage: Provider configuration and resource deployment targeting
  # • Scope: All resources deployed within this subscription boundary
  #
  # ENTERPRISE SUBSCRIPTION BENEFITS:
  # • Billing isolation and cost management with subscription-based allocation
  # • Access control and security boundaries with subscription-level RBAC
  # • Resource organization with logical subscription-based grouping
  # • Compliance and governance with subscription-level policy enforcement
  #
  # SUBSCRIPTION MANAGEMENT PATTERNS:
  # • Environment-Based: Separate subscriptions for development, staging, production
  # • Business Unit-Based: Subscriptions aligned with organizational structure
  # • Project-Based: Dedicated subscriptions for specific projects or initiatives
  # • Shared Services: Centralized subscriptions for enterprise shared resources
  #
  # ENTERPRISE GOVERNANCE INTEGRATION:
  # • Azure Policy: Subscription-level policy enforcement and compliance
  # • Cost Management: Subscription-based budgets, alerts, and spending analysis
  # • Security Center: Subscription-level security monitoring and compliance
  # • Monitor: Subscription-based observability and performance tracking
  subscription_id = "0d3a8060-e8d5-4500-aaff-eb67d9f11de9"

  # ==============================================================================
  # AZURE TENANT IDENTIFIER - ENTERPRISE IDENTITY AND ACCESS MANAGEMENT
  # ==============================================================================
  # Azure Active Directory tenant identifier for enterprise identity management,
  # authentication, and authorization within the Azure enterprise deployment
  # framework, enabling centralized identity and access control patterns.
  #
  # TENANT IDENTIFIER CHARACTERISTICS:
  # • Format: Standard Azure AD tenant GUID (UUID format)
  # • Purpose: Enterprise identity boundary and authentication domain definition
  # • Usage: Authentication provider configuration and identity integration
  # • Scope: All Azure AD users, groups, and applications within the tenant
  #
  # ENTERPRISE TENANT BENEFITS:
  # • Centralized identity management with Azure AD integration
  # • Single sign-on (SSO) and multi-factor authentication (MFA) enforcement
  # • Role-based access control (RBAC) with enterprise security policies
  # • Compliance and audit with centralized identity and access logging
  #
  # TENANT MANAGEMENT PATTERNS:
  # • Single Tenant: Centralized identity management for the entire organization
  # • Multi-Tenant: Separate tenants for different business units or subsidiaries
  # • Hybrid Identity: Integration with on-premises Active Directory environments
  # • Guest Access: External partner and contractor access with controlled permissions
  #
  # ENTERPRISE IDENTITY INTEGRATION:
  # • Azure AD: User and group management with enterprise directory integration
  # • Conditional Access: Policy-based access control with risk assessment
  # • Privileged Identity Management: Elevated access control and governance
  # • Identity Protection: Threat detection and risk-based authentication
  tenant_id = "8ef7e80b-b6ba-4504-ae0d-29aee51519a3"
}
