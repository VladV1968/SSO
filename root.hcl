# ==============================================================================
# TERRAGRUNT ROOT CONFIGURATION - ENTERPRISE AZURE INFRASTRUCTURE FOUNDATION
# ==============================================================================
# This Terragrunt root configuration file serves as the central orchestration
# point for Azure Infrastructure as Code deployments, providing standardized
# remote state management, provider configuration, and global variable handling
# essential for enterprise-scale multi-environment infrastructure automation.
#
# TERRAGRUNT ROOT CONFIGURATION CAPABILITIES AND ENTERPRISE PATTERNS:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ CONFIGURATION ORCHESTRATION AND STANDARDIZATION:                           │
# │ • Centralized configuration management for consistent infrastructure deployment│
# │ • Global variable inheritance and region-specific configuration composition │
# │ • Remote state backend standardization for team collaboration and governance│
# │ • Provider version management and feature configuration for Azure resources │
# │                                                                             │
# │ ENTERPRISE INFRASTRUCTURE AUTOMATION:                                      │
# │ • Multi-environment deployment patterns with standardized configuration    │
# │ • Cross-region infrastructure orchestration with consistent naming conventions│
# │ • Infrastructure as Code composition with reusable module integration      │
# │ • Configuration drift prevention and state management for production workloads│
# │                                                                             │
# │ OPERATIONAL EXCELLENCE AND GOVERNANCE:                                     │
# │ • Centralized state management for audit trail and compliance documentation│
# │ • Version control integration with infrastructure configuration tracking   │
# │ • Change management automation with consistent deployment patterns         │
# │ • Team collaboration enablement with shared state and configuration standards│
# │                                                                             │
# │ SECURITY AND COMPLIANCE INTEGRATION:                                       │
# │ • Secure state storage with Azure Storage encryption and access control    │
# │ • Azure subscription isolation and multi-tenant deployment support         │
# │ • Configuration validation and compliance enforcement with enterprise policies│
# │ • Audit logging and monitoring integration for infrastructure change tracking│
# └─────────────────────────────────────────────────────────────────────────────┘
#
# TERRAGRUNT CONFIGURATION MANAGEMENT PATTERNS:
# • Root Configuration: Central orchestration point for all Terragrunt deployments
# • Global Variables: Shared configuration values across all infrastructure modules
# • Region Variables: Environment and region-specific configuration inheritance
# • Remote State: Centralized state storage with Azure backend for team collaboration
# • Provider Generation: Automated Azure provider configuration with version management
#
# ENTERPRISE USAGE SCENARIOS:
# • Multi-Environment Deployments: Development, staging, production infrastructure
# • Cross-Region Architecture: Hub-and-spoke, disaster recovery, and global deployments
# • Team Collaboration: Shared infrastructure state and configuration management
# • Compliance and Governance: Audit trail, change tracking, and policy enforcement

# ==============================================================================
# LOCAL VARIABLES - GLOBAL CONFIGURATION AND VARIABLE COMPOSITION
# ==============================================================================
# Local variables provide centralized configuration management and variable
# composition for enterprise Azure infrastructure deployments, enabling
# consistent naming conventions, environment-specific configuration, and
# cross-region deployment orchestration with Terragrunt.
#
# LOCAL VARIABLE CONFIGURATION PATTERNS AND ENTERPRISE INTEGRATION:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ CONFIGURATION COMPOSITION AND INHERITANCE:                                 │
# │ • Global variables inheritance from parent variables.hcl configuration     │
# │ • Region-specific variables composition from region.hcl files              │
# │ • Subscription-level configuration management for multi-tenant deployments│
# │ • Environment-specific configuration inheritance and override capabilities │
# │                                                                             │
# │ NAMING CONVENTION STANDARDIZATION:                                         │
# │ • Consistent Azure resource naming across all infrastructure modules       │
# │ • Enterprise naming pattern enforcement with location and environment context│
# │ • Multi-region deployment naming consistency with regional identification  │
# │ • Resource tagging and categorization support with standardized conventions│
# │                                                                             │
# │ DEPLOYMENT ORCHESTRATION SUPPORT:                                          │
# │ • Cross-module variable sharing for infrastructure dependency management   │
# │ • Multi-environment deployment with standardized configuration patterns    │
# │ • Infrastructure composition with reusable configuration building blocks   │
# │ • Configuration validation and compliance enforcement with enterprise policies│
# │                                                                             │
# │ OPERATIONAL EXCELLENCE AND AUTOMATION:                                     │
# │ • Configuration management automation with Terragrunt file discovery       │
# │ • Change management integration with configuration inheritance and composition│
# │ • Infrastructure documentation generation with configuration metadata      │
# │ • Team collaboration enablement with shared configuration standards        │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# VARIABLE COMPOSITION DETAILS:
# • location: Static location identifier for shared/global resources
# • global_vars: Global configuration loaded from parent variables.hcl file
# • subscription_id: Azure subscription identifier for resource deployment scope
# • region_vars: Region-specific configuration loaded from region.hcl files
locals {
  # ==============================================================================
  # SHARED LOCATION IDENTIFIER - GLOBAL RESOURCE DEPLOYMENT CONTEXT
  # ==============================================================================
  # Static location identifier for resources that are not region-specific,
  # such as global configuration, shared services, or cross-region resources
  # that require a consistent location reference for enterprise deployments.
  #
  # SHARED LOCATION USAGE PATTERNS:
  # • Global configuration and shared service resource identification
  # • Cross-region resource naming and categorization for enterprise management
  # • Multi-environment deployment with location-agnostic resource references
  # • Enterprise asset management and inventory with consistent location tagging
  location = "shared"

  # ==============================================================================
  # GLOBAL VARIABLES INHERITANCE - ENTERPRISE CONFIGURATION COMPOSITION
  # ==============================================================================
  # Global variables loaded from the parent variables.hcl file using Terragrunt's
  # file discovery mechanism, providing centralized configuration management
  # and consistent variable inheritance across all infrastructure modules.
  #
  # GLOBAL VARIABLES CONFIGURATION BENEFITS:
  # • Centralized configuration management with single source of truth
  # • Consistent variable inheritance across all Terragrunt configurations
  # • Enterprise naming convention enforcement and organizational standards
  # • Multi-environment deployment with standardized configuration patterns
  #
  # CONFIGURATION FILE DISCOVERY:
  # The variables.hcl file is located in the azure-iac root directory
  # providing global configuration values for all infrastructure deployments.
  global_vars = read_terragrunt_config("${get_parent_terragrunt_dir()}/variables.hcl")

  # ==============================================================================
  # AZURE SUBSCRIPTION IDENTIFIER - DEPLOYMENT SCOPE AND TENANT ISOLATION
  # ==============================================================================
  # Azure subscription ID extracted from global variables, defining the
  # deployment scope and tenant isolation boundary for all infrastructure
  # resources deployed through this Terragrunt configuration.
  #
  # SUBSCRIPTION ID USAGE PATTERNS:
  # • Azure resource deployment scope definition and tenant isolation
  # • Multi-subscription enterprise deployments with consistent configuration
  # • Subscription-level resource governance and access control enforcement
  # • Cost management and billing allocation with subscription-based reporting
  #
  # ENTERPRISE MULTI-SUBSCRIPTION SCENARIOS:
  # • Production and non-production subscription isolation
  # • Business unit-specific subscription management and governance
  # • Geographic region-specific subscription allocation
  # • Compliance and regulatory requirement-based subscription segmentation
  subscription_id = local.global_vars.locals.subscription_id

  # ==============================================================================
  # AZURE TENANT IDENTIFIER - ADD MISSING TENANT ID REFERENCE
  # ==============================================================================
  # Azure tenant ID extracted from global variables, defining the
  # Azure AD tenant boundary for authentication and authorization.
  tenant_id = local.global_vars.locals.tenant_id

  # ==============================================================================
  # GLOBAL ENTERPRISE CONFIGURATION - SHARED ORGANIZATIONAL VARIABLES
  # ==============================================================================
  # Core organizational variables extracted from global configuration,
  # providing consistent enterprise naming and organizational context
  # across all infrastructure deployments and environments.

  # Customer/Organization identifier for resource naming and organization
  customer = local.global_vars.locals.customer

  # Cloud provider identifier for standardized naming conventions
  provider = local.global_vars.locals.provider

  # Environment identifier (dev, staging, prod) for resource categorization
  environment = local.global_vars.locals.environment

  # ==============================================================================
  # REGION VARIABLES INHERITANCE - LOCATION-SPECIFIC CONFIGURATION COMPOSITION
  # ==============================================================================
  # Region-specific variables loaded from region.hcl files using Terragrunt's
  # file discovery mechanism, enabling location-aware configuration and
  # region-specific customization for multi-region Azure deployments.
  #
  # REGION VARIABLES CONFIGURATION BENEFITS:
  # • Location-specific configuration customization and regional compliance
  # • Multi-region deployment orchestration with region-aware configuration
  # • Geographic distribution and disaster recovery configuration support
  # • Regional naming convention enforcement and location-specific tagging
  #
  # REGION-SPECIFIC CONFIGURATION EXAMPLES:
  # • Network address space allocation and regional IP planning
  # • Availability zone configuration and high availability planning
  # • Regional compliance requirements and data residency configuration
  # • Performance optimization with region-specific service configuration
}

# ==============================================================================
# REMOTE STATE CONFIGURATION - ENTERPRISE STATE MANAGEMENT AND COLLABORATION
# ==============================================================================
# Azure Remote Marker (azurerm) backend configuration for centralized Terraform
# state management, enabling team collaboration, state locking, and enterprise
# governance for infrastructure deployments with secure state storage and access control.
#
# REMOTE STATE CONFIGURATION CAPABILITIES AND ENTERPRISE BENEFITS:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ CENTRALIZED STATE MANAGEMENT:                                               │
# │ • Secure state storage in Azure Blob Storage with encryption at rest        │
# │ • State locking mechanisms preventing concurrent modification conflicts     │
# │ • Team collaboration with shared state access and version control integration│
# │ • State backup and disaster recovery with Azure Storage redundancy options  │
# │                                                                             │
# │ ENTERPRISE GOVERNANCE AND COMPLIANCE:                                       │
# │ • Audit trail and compliance documentation for infrastructure changes       │
# │ • Access control integration with Azure RBAC for fine-grained permissions   │
# │ • State encryption and security compliance with enterprise security policies│
# │ • Change tracking and version control for infrastructure configuration history│
# │                                                                             │
# │ OPERATIONAL EXCELLENCE AND AUTOMATION:                                      │
# │ • Automated state key generation based on directory structure for organization│
# │ • Multi-environment state isolation with path-based state key management    │
# │ • Infrastructure deployment automation with consistent state management     │
# │ • Performance optimization with regional storage account placement          │
# │                                                                             │
# │ MULTI-ENVIRONMENT DEPLOYMENT SUPPORT:                                       │
# │ • Environment-specific state isolation with organized state key structure   │
# │ • Cross-environment dependency management with shared state references      │
# │ • Infrastructure composition with modular state management and organization │
# │ • Enterprise deployment patterns with standardized state storage conventions│
# └─────────────────────────────────────────────────────────────────────────────┘
#
# AZURE BACKEND CONFIGURATION COMPONENTS:
# • resource_group_name: Azure Resource Group containing the storage account
# • storage_account_name: Azure Storage Account for state storage and management
# • container_name: Blob container for organized state file storage and access
# • key: State file path generated from directory structure for organization
#
# ENTERPRISE STATE MANAGEMENT PATTERNS:
# • Environment Isolation: Separate state files for development, staging, production
# • Module Organization: Directory-based state key generation for module isolation
# • Access Control: Azure RBAC integration for state access and modification control
# • Backup Strategy: Azure Storage redundancy and cross-region backup capabilities
remote_state {
  backend = "azurerm"
  config = {
    # ==============================================================================
    # TERRAFORM STATE RESOURCE GROUP - STATE INFRASTRUCTURE ORGANIZATION
    # ==============================================================================
    # Azure Resource Group containing the Terraform state storage infrastructure,
    # providing logical organization and access control for state management
    # resources essential for enterprise infrastructure automation and governance.
    #
    # STATE RESOURCE GROUP NAMING PATTERN:
    # Format: "rg-{organization}-{region}-{environment}-str-tf"
    # Example: "rg-sre-azr-eus-dev-str-tf" (SRE, Azure, East US, Development, Storage, Terraform)
    #
    # RESOURCE GROUP BENEFITS:
    # • Logical organization of state management infrastructure components
    # • Centralized access control and RBAC for state storage resources
    # • Cost allocation and management for infrastructure automation overhead
    # • Backup and disaster recovery coordination for state management resources
    resource_group_name = "rg-sre-azr-eus-dev-str-tf"

    # ==============================================================================
    # TERRAFORM STATE STORAGE ACCOUNT - SECURE STATE PERSISTENCE AND MANAGEMENT
    # ==============================================================================
    # Azure Storage Account providing secure, durable, and scalable storage for
    # Terraform state files with encryption at rest, access control, and
    # enterprise-grade reliability for infrastructure automation workflows.
    #
    # STORAGE ACCOUNT NAMING PATTERN:
    # Format: "{organization}{region}{environment}tfstr"
    # Example: "sreazreusdevtfstr" (lowercase, alphanumeric only due to Azure naming requirements)
    #
    # STORAGE ACCOUNT FEATURES AND CAPABILITIES:
    # • Encryption at rest with Azure Storage Service Encryption (SSE)
    # • Access control integration with Azure RBAC and storage access keys
    # • Geo-redundant storage options for disaster recovery and business continuity
    # • Integration with Azure Monitor for storage performance and availability monitoring
    #
    # ENTERPRISE SECURITY CONSIDERATIONS:
    # • Private endpoint integration for network isolation and enhanced security
    # • Azure Firewall integration for controlled access and traffic inspection
    # • Audit logging and monitoring for state access and modification tracking
    # • Backup and versioning capabilities for state recovery and compliance
    storage_account_name = "sreazreusdevtfstr"

    # ==============================================================================
    # TERRAFORM STATE CONTAINER - ORGANIZED STATE FILE STORAGE AND ACCESS
    # ==============================================================================
    # Azure Blob Storage container providing organized storage for Terraform
    # state files with hierarchical organization, access control, and
    # enterprise-grade management for infrastructure automation workflows.
    #
    # CONTAINER NAMING PATTERN:
    # Format: "{organization}{region}{environment}strtfcontainer"
    # Example: "sreazreusdevstrtfcontainer" (descriptive container name for state organization)
    #
    # CONTAINER ORGANIZATION BENEFITS:
    # • Hierarchical state file organization with directory-based structure
    # • Container-level access control and permission management
    # • State file lifecycle management with automated retention policies
    # • Integration with Azure Monitor for container usage and performance metrics
    #
    # STATE FILE ORGANIZATION PATTERNS:
    # • Environment-based organization: /dev/, /staging/, /production/
    # • Module-based organization: /networking/, /compute/, /security/
    # • Region-based organization: /region-a/, /region-b/, /global/
    # • Service-based organization: /infrastructure/, /applications/, /monitoring/
    container_name = "sreazreusdevstrtfcontainer"

    # ==============================================================================
    # TERRAFORM STATE KEY - DYNAMIC STATE FILE PATH GENERATION AND ORGANIZATION
    # ==============================================================================
    # Dynamic state file key generation based on the current directory path
    # relative to the Terragrunt root configuration, enabling automatic state
    # file organization and isolation for enterprise infrastructure deployments.
    #
    # STATE KEY GENERATION LOGIC:
    # The path_relative_to_include() function generates a unique state file path
    # based on the current module's location relative to the root configuration,
    # ensuring automatic state isolation and organization without manual management.
    #
    # STATE KEY EXAMPLES AND PATTERNS:
    # • Module Path: "live/region-a/vnet" → State Key: "live/region-a/vnet/terraform.tfstate"
    # • Module Path: "live/region-b/firewall" → State Key: "live/region-b/firewall/terraform.tfstate"
    # • Module Path: "modules/aks" → State Key: "modules/aks/terraform.tfstate"
    #
    # ENTERPRISE STATE ORGANIZATION BENEFITS:
    # • Automatic state isolation preventing cross-module state conflicts
    # • Hierarchical state organization matching repository directory structure
    # • Simplified state management with predictable state file locations
    # • Enhanced troubleshooting with clear state file path correlation to modules
    #
    # STATE KEY SECURITY AND ACCESS CONTROL:
    # • Path-based access control with Azure RBAC for fine-grained permissions
    # • State isolation preventing accidental cross-environment or cross-module conflicts
    # • Audit trail with clear state file path mapping to infrastructure modules
    # • Change tracking and version control with state file location correlation
    key = "${path_relative_to_include()}/terraform.tfstate"
  }
}

# Generate the provider configuration file for Azure
# This file is used by Terraform to authenticate and manage resources in Azure
# It includes the subscription ID and features configuration
# # The `if_exists` option is set to "overwrite" to ensure that the file is always updated
# # with the latest subscription ID and features configuration
# The `path` option specifies the file name for the provider configuration
# The `contents` block contains the actual provider configuration in HCL format
# The `features` block is used to configure specific features of the Azure provider,
# such as preventing deletion of resource groups that contain resources
# The `subscription_id` is set to the value defined in the `locals` block,
# which is read from the global variables defined in the `variables.hcl` file

# ==============================================================================
# TERRAFORM PROVIDER GENERATION - ENTERPRISE AZURE PROVIDER CONFIGURATION
# ==============================================================================
# Azure Provider generation configuration for standardized Terraform provider
# setup across all modules, ensuring consistent Azure authentication, feature
# enablement, and enterprise-grade configuration for infrastructure deployments.
#
# PROVIDER GENERATION CAPABILITIES AND ENTERPRISE BENEFITS:
# ┌─────────────────────────────────────────────────────────────────────────────┐
# │ STANDARDIZED PROVIDER CONFIGURATION:                                        │
# │ • Consistent Azure provider setup across all infrastructure modules         │
# │ • Centralized provider version management and feature enablement            │
# │ • Enterprise authentication patterns with service principal integration     │
# │ • Automated provider configuration generation for deployment consistency    │
# │                                                                             │
# │ AZURE PROVIDER FEATURES AND ENTERPRISE INTEGRATION:                         │
# │ • Enhanced feature enablement for enterprise Azure services and capabilities│
# │ • Integration with Azure AD for authentication and authorization            │
# │ • Support for Azure Government and sovereign cloud deployments              │
# │ • Performance optimization with provider configuration best practices       │
# │                                                                             │
# │ ENTERPRISE AUTHENTICATION AND SECURITY:                                     │
# │ • Service principal authentication for automated deployment workflows       │
# │ • Azure CLI integration for interactive deployment and management           │
# │ • Managed identity support for Azure-hosted deployment environments         │
# │ • Multi-tenant authentication support for enterprise Azure subscriptions    │
# │                                                                             │
# │ OPERATIONAL EXCELLENCE AND AUTOMATION:                                      │
# │ • Automated provider.tf file generation across all modules for consistency  │
# │ • Version constraint management for stable and predictable deployments      │
# │ • Feature flag management for controlled Azure service adoption             │
# │ • Configuration standardization for enterprise governance and compliance    │
# └─────────────────────────────────────────────────────────────────────────────┘
#
# AZURE PROVIDER CONFIGURATION COMPONENTS:
# • Version Constraints: Terraform and provider version management for stability
# • Authentication: Service principal, CLI, and managed identity support
# • Feature Flags: Enhanced Azure service features and capabilities enablement
# • Required Providers: Azure Resource Manager and additional provider dependencies
#
# ENTERPRISE PROVIDER PATTERNS:
# • Standardization: Consistent provider configuration across all infrastructure modules
# • Security: Enterprise authentication patterns with service principal integration
# • Governance: Version control and feature flag management for controlled deployments
# • Automation: Generated provider files for deployment consistency and efficiency
generate "provider" {
  # ==============================================================================
  # PROVIDER FILE PATH - GENERATED PROVIDER CONFIGURATION LOCATION
  # ==============================================================================
  # Specifies the file path for the generated provider configuration,
  # ensuring consistent provider setup across all Terraform modules
  # with standardized naming conventions and enterprise organization.
  #
  # PROVIDER FILE NAMING CONVENTION:
  # • File Name: "provider.tf" (Terraform standard provider configuration file)
  # • Location: Root of each module directory for immediate provider availability
  # • Purpose: Centralized provider configuration with enterprise standardization
  #
  # GENERATED FILE BENEFITS:
  # • Consistent provider configuration across all infrastructure modules
  # • Centralized version management and feature enablement control
  # • Simplified module development with automatic provider setup
  # • Enterprise governance with standardized provider configuration patterns
  path = "provider.tf"

  # ==============================================================================
  # FILE OVERWRITE BEHAVIOR - GENERATED FILE MANAGEMENT AND VERSION CONTROL
  # ==============================================================================
  # Configures the behavior when a provider.tf file already exists in the
  # target directory, ensuring consistent provider configuration management
  # and enterprise standardization across all infrastructure modules.
  #
  # OVERWRITE STRATEGY OPTIONS:
  # • "overwrite": Replace existing provider files with generated configuration
  # • "skip": Preserve existing provider files without modification
  # • "overwrite_terragrunt": Overwrite files generated by Terragrunt only
  #
  # ENTERPRISE FILE MANAGEMENT BENEFITS:
  # • Consistent provider configuration across all modules and environments
  # • Centralized provider version and feature management for enterprise governance
  # • Automated provider standardization with controlled configuration updates
  # • Version control integration with generated file tracking and change management
  if_exists = "overwrite"

  # ==============================================================================
  # PROVIDER CONFIGURATION CONTENT - ENTERPRISE AZURE PROVIDER SETUP
  # ==============================================================================
  # Comprehensive Azure provider configuration with enterprise-grade features,
  # authentication patterns, and version constraints for stable and secure
  # infrastructure deployments across development, staging, and production environments.
  #
  # TERRAFORM VERSION CONSTRAINTS AND COMPATIBILITY:
  # • Minimum Terraform version requirement for feature compatibility and stability
  # • Provider version constraints for predictable behavior and security updates
  # • Enterprise authentication with subscription-specific configuration
  # • Feature enablement for advanced Azure service capabilities and enterprise integration
  contents = <<EOF
# ==============================================================================
# TERRAFORM REQUIREMENTS - VERSION CONSTRAINTS AND PROVIDER CONFIGURATION
# ==============================================================================
# Terraform configuration requirements specifying minimum versions,
# required providers, and enterprise-grade settings for Azure infrastructure
# deployments with stability, security, and feature compatibility assurance.

terraform {
  # ==============================================================================
  # REQUIRED PROVIDERS - AZURE PROVIDER CONFIGURATION AND VERSION MANAGEMENT
  # ==============================================================================
  # Azure Resource Manager provider configuration with version constraints,
  # source specification, and enterprise-grade settings for reliable
  # infrastructure management and deployment automation workflows.
  required_version = ">= 1.0"
  required_providers {
    # ==========================================================================
    # AZURE RESOURCE MANAGER PROVIDER - PRIMARY AZURE INFRASTRUCTURE PROVIDER
    # ==========================================================================
    # HashiCorp Azure provider for comprehensive Azure resource management,
    # supporting all Azure services with enterprise authentication patterns,
    # advanced features, and production-ready stability for infrastructure automation.
    #
    # AZURE PROVIDER CAPABILITIES:
    # • Complete Azure service coverage with resource lifecycle management
    # • Enterprise authentication with service principal and managed identity support
    # • Advanced features including private endpoints, network security, and governance
    # • Multi-region deployment support with global Azure service availability
    #
    # VERSION CONSTRAINT STRATEGY:
    # • Specific version constraint (4.35.0) for predictable deployment behavior
    # • Enterprise validation with tested and approved provider versions
    # • Security update management with controlled provider version adoption
    # • Compatibility assurance with existing infrastructure and automation workflows
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.35.0"
    }
  }
}

# ==============================================================================
# AZURE PROVIDER CONFIGURATION - ENTERPRISE AUTHENTICATION AND FEATURES
# ==============================================================================
# Azure Resource Manager provider configuration with enterprise-grade
# authentication, enhanced features, and production-ready settings for
# reliable infrastructure management and deployment automation workflows.

provider "azurerm" {
  # ==============================================================================
  # ENHANCED FEATURES CONFIGURATION - AZURE SERVICE CAPABILITIES ENABLEMENT
  # ==============================================================================
  # Azure provider enhanced features enabling advanced service capabilities,
  # enterprise integration patterns, and production-ready functionality
  # for comprehensive infrastructure management and automation workflows.
  #
  # ENHANCED FEATURES BENEFITS:
  # • Advanced Azure service features and capabilities for enterprise workloads
  # • Improved resource management with enhanced provider functionality
  # • Enterprise integration patterns with Azure AD and security services
  # • Production-ready features for reliable infrastructure automation
  #
  # RESOURCE GROUP DELETION BEHAVIOR:
  # • Development/Testing: Flexible deletion behavior for rapid iteration
  # • Production: Enhanced protection with resource dependency validation
  # • Enterprise governance: Configurable deletion policies for compliance
  # • Operational safety: Resource protection with automated validation workflows
  features {
    # ==========================================================================
    # RESOURCE GROUP ENHANCED FEATURES - FLEXIBLE RESOURCE LIFECYCLE MANAGEMENT
    # ==========================================================================
    # Azure Resource Group enhanced features enabling flexible resource
    # lifecycle management for development and testing environments with
    # enterprise governance and operational safety considerations.
    #
    # RESOURCE GROUP FEATURE BENEFITS:
    # • Flexible resource lifecycle management for development workflows
    # • Enterprise governance with configurable resource protection mechanisms
    # • Operational efficiency with streamlined cleanup and automation processes
    # • Development productivity with rapid iteration and testing capabilities
    #
    # DELETION BEHAVIOR CONFIGURATION:
    # • Allow deletion of non-empty resource groups for development flexibility
    # • Configurable deletion behavior based on environment and governance requirements
    # • Enterprise compliance with resource lifecycle management and audit integration
    # • Automated cleanup workflows with development and testing environment optimization
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }

  # ==============================================================================
  # AZURE SUBSCRIPTION CONFIGURATION - ENTERPRISE SUBSCRIPTION MANAGEMENT
  # ==============================================================================
  # Azure subscription configuration using dynamically resolved subscription ID
  # from Terragrunt local variables, enabling multi-subscription deployments
  # and enterprise Azure environment management with centralized configuration.
  #
  # SUBSCRIPTION MANAGEMENT BENEFITS:
  # • Multi-subscription deployment support with centralized configuration management
  # • Enterprise Azure environment organization with subscription-based isolation
  # • Dynamic subscription resolution from Terragrunt configuration variables
  # • Automated subscription management with environment-specific deployment patterns
  #
  # SUBSCRIPTION ID RESOLUTION:
  # • Local variable interpolation: $${local.subscription_id} from Terragrunt configuration
  # • Environment-specific subscription mapping for development, staging, and production
  # • Centralized subscription management with enterprise governance and compliance
  # • Multi-tenant Azure deployment support with subscription-based resource isolation
  subscription_id = "$${local.subscription_id}"
  # TENANT ID RESOLUTION:
  # • Local variable interpolation: $${local.tenant_id} from Terragrunt configuration
  # • Environment-specific tenant mapping for development, staging, and production
  # • Centralized tenant management with enterprise governance and compliance
  # • Multi-tenant Azure deployment support with subscription-based resource isolation
  tenant_id = "$${local.tenant_id}"
}
EOF
}

# ==============================================================================
# LOCAL VALUES GENERATION - TERRAGRUNT INHERITED CONFIGURATION
# ==============================================================================
# Generate local values file to provide subscription and tenant IDs
# to the Terraform configuration from Terragrunt variables
generate "locals" {
  path      = "locals.tf"
  if_exists = "overwrite"
  contents  = <<EOF
# ==============================================================================
# LOCAL VALUES - TERRAGRUNT INHERITED CONFIGURATION
# ==============================================================================
# Local values inherited from Terragrunt configuration for consistent
# Azure resource deployment and enterprise configuration management.

locals {
  # Azure subscription identifier for resource deployment scope
  subscription_id = "${local.global_vars.locals.subscription_id}"
  
  # Azure tenant identifier for authentication and authorization
  tenant_id = "${local.global_vars.locals.tenant_id}"
}
EOF
}