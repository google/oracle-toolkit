1\. Feature Overview
--------------------

Security and compliance standards often require that database connections be encrypted in transit. Historically, configuring TLS for Oracle involved complex manual steps: managing Certificate Authorities (CAs), generating wallets with orapki, and manually editing configuration files.

This solution completely automates TLS encryption for self-managed Oracle workloads on Google Cloud. By simply supplying a TLS secret configuration, the infrastructure automatically provisions trusted certificates from [Google Certificate Authority Service (CAS)](https://www.google.com/search?q=https://cloud.google.com/certificate-authority-service/docs), secures the keys in Secret Manager, and configures the database listeners.

__Key Benefits:__

-   ***Zero-Touch Configuration:*** No manual orapki commands or wallet management required.
-   ***Root of Trust:*** Certificates are issued by your organization's private Certificate Authority (CAS), ensuring valid identity attestation.
-   ***Cloud-Native Security:*** Private keys are stored securely in Secret Manager and retrieved only by the database VM's authorized identity.
-   ***Client Readiness:*** Automatically generates a downloadable "Client Bundle" containing the necessary truststore and configuration files for immediate connectivity.
-   ***Multi-Node & 26ai Ready:*** Fully supports active Data Guard architectures (minting distinct certificates per node) and seamlessly adapts to Oracle 23ai/26ai WALLET_ROOT architectures alongside legacy 19c deployments.

__Supported Configurations:__
- Oracle 19c or 23ai/26ai.
- Google Cloud VMs only.
- Configuration via Terraform (see `docs/terraform.md`).
- *Note:* This configuration uses certificates to validate the server, but does not configure client certificates (mTLS).

2\. How to Enable TLS
---------------------

To enable encryption, you need to explicitly enable TLS and provide your Identity and Trust resources in your Terraform configuration (.tfvars).

__Prerequisites:__

-   ***Required APIs Enabled on Project:***
    * Compute Engine (`compute.googleapis.com`)
    * Secret Manager (`secretmanager.googleapis.com`)
    * Artifact Registry (`artifactregistry.googleapis.com`)
    * Certificate Authority (`privateca.googleapis.com`)

-   ***Required IAM Roles for Deployment:*** roles/dns.admin, roles/privateca.certificateManager, and roles/secretmanager.secretAccessor (or roles/secretmanager.admin if creating secrets dynamically).

-   ***Google CA Pool:*** A Private CA Pool to issue certificates. You can create this via the Google Cloud Console (Security -> Certificate Authority Service) or using the provided Terraform resources (see the CAS Setup section in the Terraform `.tf` examples).
-   ***Cloud DNS Zone:*** A private DNS zone configured in your project to route the internal database endpoints (e.g., `internal.corp.com.`).

**Configuration:** Add the following variables to your Terraform deployment:  
_(Note: For a fully working reference deployment, see [terraform/terraform.tfvars.tls.example](https://github.com/google/oracle-toolkit/blob/master/terraform/terraform.tfvars.tls.example) in the repository)._

~~~
# 1. Enable TLS explicitly 

enable_tls = true

tls_listener_port = "2484" # Optional: Defaults to 2484 if omitted

# 2. Trust Infrastructure (Must exist in your project)

cas_pool_id = "projects/my-project/locations/us-central1/caPools/prod-ca-pool"

# 3. Network Identity (DNS)

# The database will register 'finance-db-1.internal.corp.com' in this zone

dns_zone_name = "my-private-dns-zone" 

dns_domain_name = "internal.corp.com." 

instance_name = "finance-db" # Nodes will automatically be suffixed (e.g., finance-db-1, finance-db-2)
~~~

3\. Connecting Clients
----------------------

Since the database now uses a private certificate, database clients will require a wallet including your private CA certificate in the trust store. We automatically generate a Client Connectivity Bundle to solve this.

***Step 1: Retrieve and Secure the Client Bundle*** 

A zip file containing the Truststore (Root CA) and a pre-configured wallet is generated on the database VM directly in the Oracle user's home directory (`/home/oracle/client_bundle.zip`). 

Download it to your client machine:

~~~
gcloud compute scp oracle@finance-db-1:/home/oracle/client_bundle.zip .
~~~

**Security Requirement:** Because this bundle acts as an authentication token, you must immediately secure it from other users on your client machine:

~~~
chmod 600 client_bundle.zip 

unzip client_bundle.zip -d client_bundle 

chmod 700 client_bundle # Restrict access to the extracted directory
~~~

***Step 2: Configure Your Client***

The bundle contains an auto-login wallet (cwallet.sso) that already trusts the server. Point your client's sqlnet.ora to this unzipped directory:

~~~
WALLET_LOCATION = (SOURCE = (METHOD = FILE) (METHOD_DATA = (DIRECTORY = /path/to/unzipped/client_bundle)))

SSL_CLIENT_AUTHENTICATION = FALSE
~~~

***Step 3: Connect***

You can now connect securely using the TCPS protocol. You will be prompted for your password:

~~~
sqlplus system@"tcps://finance-db-01.internal.corp.com:2484/ORCL"
~~~

4\. Behind the Scenes: How It Works
-----------------------------------

We utilize a secure, multi-stage orchestration process to ensure keys are protected and configuration is consistent.

**Stage 1: Identity & Issuance (Terraform)**

-   ***Strict Policy Enforcement:*** The CA Pool utilizes IAM Conditions and CEL-based Issuance Policies to ensure certificates are only issued if the Subject Alternative Name (SAN) matches the authorized internal domain (e.g., *.internal.corp.com).

-   ***Certificate Generation:*** Terraform dynamically generates distinct 2048-bit RSA private keys in memory and submits a CSR to your Google CA Pool for every node in the cluster.

-   ***Secure Vaulting:*** The resulting Certificates, Private Keys, and passwords are consolidated into a single JSON payload per node and stored directly in Google Secret Manager.

**Stage 2: Provisioning (Ansible)**

-   ***Secure Retrieval:*** When the database VM boots, it authenticates using its attached Service Account. This identity is strictly granted secretAccessor rights only to the specific secrets created for its distinct instance.

-   ***Wallet Construction:*** The automation builds an Oracle Auto-Login Wallet (cwallet.sso). Depending on the engine version, it gracefully targets either WALLET_LOCATION (19c) or the native WALLET_ROOT (26ai) to avoid conflicts with Transparent Data Encryption (TDE).

-   ***Client Artifact Generation:*** A separate, clean wallet is created for clients. The automation exports the public Root CA chain, imports it as a "Trusted Certificate," and packages it into client_bundle.zip.

**Note on Certificate Rotation:** Automated certificate rotation is currently deferred pending a security design review to ensure strict adherence to least-privilege IAM principles.

5\. Verifying Security
----------------------

To confirm that your database is listening securely:

1.  Log into the database VM.

2.  Switch to the oracle user: 

~~~
sudo su - oracle
~~~

3.  Check the listener status: 

~~~
lsnrctl status
~~~

***Success Indicator:*** You will see the secure endpoint listed in the summary: (DESCRIPTION=(ADDRESS=(PROTOCOL=tcps)(HOST=finance-db-01...)(PORT=2484)))

***Verifying the Converse (Unencrypted Endpoints):***
You will notice that port 1521 (TCP) remains open. This is intentional. The unencrypted port is preserved strictly for local administrative tasks (like dbstart) and internal Data Guard operations. To verify complete external security, ensure your VPC firewall rules only permit ingress on the encrypted port (default 2484, or your configured tls_listener_port) and explicitly block the standard TCP port (default 1521, or your configured ora_listener_port) from downstream clients.
