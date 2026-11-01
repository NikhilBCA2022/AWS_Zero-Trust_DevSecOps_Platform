# AWS Zero-Trust DevSecOps Platform

A security-focused DevSecOps platform built on AWS using Terraform, Amazon EKS, Docker, GitHub Actions, Amazon ECR, AWS WAF, and CloudWatch.

The project demonstrates how infrastructure as code, automated security checks, identity-based CI/CD authentication, container security, Kubernetes deployments, and cloud monitoring can work together in a practical cloud environment.

## Project Objectives

- Provision cloud infrastructure using Terraform.
- Deploy a containerized FastAPI application to Amazon EKS.
- Automate testing, security scanning, image publishing, and deployment.
- Use GitHub Actions OIDC for AWS authentication.
- Protect application traffic with AWS WAF.
- Monitor application availability and infrastructure activity.

## Architecture

Developer Push
      |
      v
GitHub Repository
      |
      v
GitHub Actions CI/CD
      |
      +--> Gitleaks — secret scanning
      +--> Python tests
      +--> Bandit — Python security analysis
      +--> pip-audit — dependency vulnerability checks
      +--> Terraform formatting and validation
      +--> Docker image build
      +--> Trivy — container image vulnerability scanning
      |
      v
AWS Authentication through OIDC
      |
      v
Amazon ECR
      |
      v
Amazon EKS
      |
      v
FastAPI Application
      |
      +--> Amazon RDS
      |
      v
Application Load Balancer
      |
      v
AWS WAF
      |
      v
Application Users

Monitoring:
- Amazon CloudWatch
- VPC Flow Logs
- CloudWatch alarm for unhealthy ALB targets

## Technology Stack

**Cloud:** AWS  
**Infrastructure as Code:** Terraform  
**Containers:** Docker  
**Container Orchestration:** Amazon EKS, Kubernetes  
**CI/CD:** GitHub Actions  
**Container Registry:** Amazon ECR  
**Security:** AWS WAF, Gitleaks, Bandit, pip-audit, Trivy, GitHub Actions OIDC  
**Application:** Python, FastAPI  
**Database:** Amazon RDS, PostgreSQL  
**Monitoring:** Amazon CloudWatch, VPC Flow Logs

## Security Features

### Infrastructure as Code
Terraform manages the project's AWS infrastructure and supports repeatable, reviewable infrastructure changes.

### CI/CD Security
The GitHub Actions pipeline includes secret scanning, Python testing, static security analysis, dependency auditing, Terraform validation, and container image vulnerability scanning.

### Identity-Based AWS Authentication
GitHub Actions uses OpenID Connect (OIDC) to authenticate to AWS without relying on long-lived AWS access keys stored in GitHub secrets.

### Container Security
Docker images are scanned with Trivy before publication to Amazon ECR. The pipeline applies a HIGH/CRITICAL vulnerability gate.

### Network and Application Protection
AWS WAF is associated with the Application Load Balancer. Its configured protections include AWS managed rule groups and an IP-based rate-based rule.

### Kubernetes Deployment
The FastAPI application runs on Amazon EKS with two application replicas. Application health and readiness endpoints have been verified.

### Cloud Monitoring
VPC Flow Logs capture network traffic records, and a CloudWatch alarm monitors unhealthy targets for the application's load balancer target group.

## Validation Performed

- Terraform infrastructure deployment completed successfully.
- Amazon EKS cluster reached the ACTIVE state.
- GitHub Actions CI/CD pipeline completed successfully.
- Application deployment reached two ready replicas.
- Application health endpoint returned HTTP 200.
- Application readiness endpoint returned HTTP 200, including a database connectivity check.
- AWS WAF was associated with the Application Load Balancer.
- VPC Flow Logs were active.
- CloudWatch unhealthy-target alarm was created.

## Important Scope Notes

- HTTPS and a custom domain are not included in the current project scope.
- The CloudWatch alarm changes alarm state but does not send notifications unless an alarm action is configured.
- GuardDuty and a separately configured CloudTrail trail were not confirmed in the latest audit.
- This project demonstrates selected zero-trust and defense-in-depth practices; it should not be interpreted as a certification of complete zero-trust compliance.

## Repository

GitHub: https://github.com/NikhilBCA2022/AWS_Zero-Trust_DevSecOps_Platform

## Learning Outcomes

This project provided hands-on experience with:

- AWS infrastructure provisioning using Terraform
- EKS and Kubernetes application deployment
- CI/CD pipeline design and troubleshooting
- AWS OIDC-based workload authentication
- Automated security checks in CI/CD
- Docker image scanning and ECR publishing
- AWS WAF configuration
- CloudWatch monitoring and VPC Flow Logs
- Application health and database readiness validation

## Future Improvements

Potential extensions include HTTPS with a custom domain, alarm notifications through SNS, centralized audit logging, GuardDuty, and additional observability tooling.

---

**Project focus:** Secure infrastructure, automated delivery, Kubernetes operations, and cloud security.