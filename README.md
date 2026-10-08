# Oracle ORDS + APEX Docker Deployment

Docker-based deployment of **Oracle REST Data Services (ORDS)** with **Oracle APEX**.

This project is designed to provide a repeatable ORDS/APEX deployment using Docker Compose. ORDS configuration is persisted outside the Docker image so that the container can be recreated or upgraded without reinstalling ORDS unnecessarily.

---

## 1. Architecture

```text
                    Docker Host
                         │
                         │
              ┌──────────▼──────────┐
              │     ORDS Container   │
              │                     │
              │  Oracle ORDS        │
              │  Java               │
              │  run_ords.sh        │
              └──────────┬──────────┘
                         │
                         │ Oracle JDBC
                         ▼
                 Oracle Database
                         │
                         │
                    XEPDB1 Service
                         │
                         ▼
                    Oracle APEX
```

ORDS configuration is persisted using a host directory:

```text
./ORDS/config
        │
        ▼
/opt/ords-config
```

This prevents the generated ORDS configuration from being lost when the container is recreated.

---

# 2. Project Structure

The project should have the following structure:

```text
Tryparameter/
│
├── Dockerfile
├── docker-compose.yml
├── run_ords.sh
├── .env
├── .env.example
├── .gitignore
├── README.md
│
├── ORDS/
│   └── config/
│
└── apex/
    ├── apex/
    ├── images/
    └── ...
```

> The exact APEX extracted directory structure may differ depending on the Oracle APEX package version.

---

# 3. Required Software

The deployment machine must have:

* Docker
* Docker Compose
* Access to the Oracle Database
* Oracle APEX installation files
* Oracle ORDS installation package
* Appropriate database credentials
* Network connectivity between the Docker host and Oracle Database

Verify Docker:

```bash
docker --version
```

Verify Docker Compose:

```bash
docker compose version
```

---

# 4. Before Deployment

Before running Docker Compose, prepare the ORDS and APEX files.

There are two important software packages that must be supplied separately:

1. Oracle APEX
2. Oracle REST Data Services (ORDS)

These files may be subject to Oracle licensing/distribution requirements and should be obtained from the appropriate Oracle source.

---

# 5. Prepare Oracle APEX

Download the required Oracle APEX ZIP package.

Extract the APEX package into the project.

For example:

```text
apex/
├── apex/
├── images/
├── apexins.sql
├── apexins_cdb.sql
├── apexins_con.sql
└── ...
```

The important requirement for this Docker deployment is that the APEX `images` directory is available at:

```text
./apex/images
```

The Docker Compose file mounts this directory into the container:

```yaml
volumes:
  - ./apex:/opt/oracle/apex:ro
```

Therefore, ORDS can access:

```text
/opt/oracle/apex/images
```

### APEX directory requirement

Make sure this path exists before starting the container:

```text
./apex/images
```

Check on Linux:

```bash
ls -la ./apex/images
```

Check on Windows PowerShell:

```powershell
Get-ChildItem .\apex\images
```

---

# 6. Prepare Oracle ORDS

Download the required Oracle REST Data Services ZIP package.

Extract the ORDS package.

The ORDS files are used to build the Docker image.

For example:

```text
ORDS/
    ...
```

The Dockerfile should copy/install ORDS into the expected container directory:

```text
/opt/ords
```

---

# 7. ORDS Version Changes

If a different ORDS version is used, check the `Dockerfile` and `run_ords.sh`.

For example, if the ORDS installation directory or ZIP filename changes, update the corresponding references.

The startup script expects ORDS to be available at:

```text
/opt/ords
```

and the ORDS executable at:

```text
/opt/ords/bin/ords
```

The script defines:

```bash
ORDS_DIR="/opt/ords"
ORDS_BIN="/opt/ords/bin/ords"
```

### Important

If the ORDS directory inside the image changes, update `run_ords.sh` accordingly.

Do not change these paths unless the Dockerfile is also changed to use the same paths.

---

# 8. Configure Database Connection

Database connection parameters are supplied through `.env`.

Create `.env` from the example:

```bash
cp .env.example .env
```

On Windows PowerShell:

```powershell
Copy-Item .env.example .env
```

Edit `.env`.

Example:

```env
DB_HOSTNAME=host.docker.internal
DB_PORT=1521
DB_SERVICENAME=xepdb1

DB_USERNAME=SYS

SYS_PASS=CHANGE_ME
ORDS_PASS=CHANGE_ME

ORDS_CONFIG_DIR=/opt/ords-config
ORDS_PORT=8085
```

---

# 9. Database Parameters

Change these values according to the target Oracle Database.

### DB_HOSTNAME

Example:

```env
DB_HOSTNAME=host.docker.internal
```

For a Linux production server, this may instead be:

```env
DB_HOSTNAME=192.168.1.100
```

or:

```env
DB_HOSTNAME=oracle-server.example.com
```

Use the hostname/IP address that is reachable **from the Docker container**.

---

### DB_PORT

Default Oracle listener port:

```env
DB_PORT=1521
```

Change it if the Oracle listener uses another port.

---

### DB_SERVICENAME

Example:

```env
DB_SERVICENAME=xepdb1
```

This must match the Oracle database service name.

For Oracle XE, a common service is:

```text
xepdb1
```

Verify the actual service name on the target database before deployment.

---

# 10. Database Passwords

The following values must be changed in `.env`:

```env
SYS_PASS=CHANGE_ME
ORDS_PASS=CHANGE_ME
```

Example:

```env
SYS_PASS=<actual-SYS-password>
ORDS_PASS=<actual-ORDS-runtime-password>
```

### Security requirement

Do **NOT** put real passwords into:

```text
docker-compose.yml
Dockerfile
run_ords.sh
.env.example
README.md
```

The real passwords belong only in:

```text
.env
```

The `.env` file is excluded from Git using `.gitignore`.

---

# 11. Docker Compose Configuration

The Docker Compose file uses environment variables:

```yaml
environment:
  DB_HOSTNAME: ${DB_HOSTNAME}
  DB_PORT: ${DB_PORT}
  DB_SERVICENAME: ${DB_SERVICENAME}
  DB_USERNAME: ${DB_USERNAME:-SYS}
  SYS_PASS: ${SYS_PASS}
  ORDS_PASS: ${ORDS_PASS}
  ORDS_CONFIG_DIR: /opt/ords-config
  ORDS_PORT: ${ORDS_PORT:-8085}
```

Do not replace these with hard-coded passwords.

---

# 12. ORDS Configuration Directory

The Docker Compose file contains:

```yaml
volumes:
  - ./ORDS/config:/opt/ords-config
```

This means:

```text
Host:
./ORDS/config

        ↓ Docker bind mount

Container:
/opt/ords-config
```

The directory must exist before the first deployment.

Create it if necessary:

Linux:

```bash
mkdir -p ORDS/config
```

Windows PowerShell:

```powershell
docker compose down --rmi all --volumes --remove-orphans

Then remove the local ORDS configuration:

Remove-Item -Recurse -Force .\ORDS\config
New-Item -ItemType Directory -Force .\ORDS\config
```

---

# 13. First Installation

For a new installation, make sure:

```text
ORDS/config/
```

does not contain an existing ORDS installation.

Do NOT delete the directory unless a complete ORDS reinstallation is intentionally required.

Start the deployment:

```bash
docker compose up -d
```

or, if the image must be built locally:

```bash
docker compose up -d --build
```

Monitor the logs:

```bash
docker compose logs -f ords
```

A successful startup should eventually show information similar to:

```text
Mapped local pools from /opt/ords-config/databases:

/ords/ => default => VALID
```

and:

```text
Oracle REST Data Services initialized
Oracle REST Data Services version : 26.x.x
```

---

# 14. First Installation Process

The startup script checks whether the ORDS configuration already exists.

Conceptually:

```text
Does pool.xml exist?
       │
       ├── YES
       │    │
       │    └── Start ORDS
       │
       └── NO
            │
            ├── Configure database
            ├── Install ORDS
            ├── Create/configure ORDS runtime users
            ├── Generate ORDS configuration
            └── Start ORDS
```

This means ORDS should only be installed automatically during the first initialization of an empty configuration directory.

---

# 15. Normal Startup

After ORDS has been successfully installed, use:

```bash
docker compose up -d
```

The existing ORDS configuration will be reused.

You do NOT need to reinstall ORDS every time the container starts.

---

# 16. Restart ORDS

To restart:

```bash
docker compose restart
```

Or:

```bash
docker restart ords_apex
```

---

# 17. Stop ORDS

```bash
docker compose down
```

This stops and removes the container/network but does not remove the host directory:

```text
ORDS/config/
```

Therefore, the ORDS configuration remains available.

---

# 18. Check ORDS Logs

Use:

```bash
docker compose logs -f ords
```

or:

```bash
docker logs -f ords_apex
```

Check container status:

```bash
docker compose ps
```

Expected status:

```text
ords_apex    Up
```

---

# 19. Test ORDS

The default HTTP port is:

```text
8085
```

Open:

```text
http://localhost:8085/ords/
```

For APEX:

```text
http://localhost:8085/ords/apex
```

If the Docker server is remote, replace `localhost` with the server hostname/IP.

Example:

```text
http://192.168.1.100:8085/ords/apex
```

---

# 20. ORDS Connection Pool

The generated pool configuration is normally located under:

```text
ORDS/config/databases/default/
```

For example:

```text
ORDS/config/databases/default/pool.xml
```

Do not manually delete or modify generated ORDS configuration unless there is a specific reason.

The pool must report:

```text
/ords/ => default => VALID
```

for a healthy database connection.

---

# 21. ORDS Performance Tuning

ORDS connection pool settings can be tuned if required.

However, increasing the connection pool does not automatically make APEX applications faster.

Performance depends on:

```text
ORDS
  ↓
Connection Pool
  ↓
Oracle Database
  ↓
APEX
  ↓
Application SQL / PL/SQL
```

Before increasing pool limits, investigate:

* Database CPU
* Database memory
* SQL execution time
* APEX application processing
* Buffer gets
* Disk reads
* Connection concurrency

Do not set extremely high connection limits without testing.

---

# 22. Updating the ORDS Docker Image

When updating ORDS or the Docker image:

```bash
docker compose build
```

Then:

```bash
docker compose up -d
```

The existing:

```text
ORDS/config/
```

is preserved.

This allows the container image to be replaced without automatically deleting the ORDS configuration.

---

# 23. Changing ORDS Version

When upgrading ORDS:

1. Obtain the new ORDS package.
2. Update the Dockerfile.
3. Check the ORDS installation path.
4. Check `run_ords.sh`.
5. Build the new image.
6. Test the new version.
7. Keep a backup of the existing ORDS configuration.
8. Start the updated container.

Before deployment, verify:

```bash
/opt/ords/bin/ords --version
```

inside the container.

---

# 24. Changing APEX Version

When upgrading APEX:

1. Obtain the new APEX package.
2. Replace the APEX files in the project according to the deployment procedure.
3. Ensure the following path exists:

```text
./apex/images
```

4. Rebuild/redeploy the Docker container if required.
5. Upgrade the APEX installation in the Oracle Database according to Oracle's APEX installation/upgrade procedure.
6. Verify APEX through ORDS.

Changing the APEX static files alone does not necessarily upgrade the APEX database components.

---

# 25. Complete ORDS Reinstallation

A complete ORDS reinstallation should only be performed intentionally.

Before doing this, back up:

```text
ORDS/config/
```

Then stop the container:

```bash
docker compose down
```

Remove the generated ORDS configuration:

Linux:

```bash
rm -rf ORDS/config/*
```

Windows PowerShell:

```powershell
Remove-Item -Recurse -Force .\ORDS\config\*
```

Recreate the directory if necessary:

Linux:

```bash
mkdir -p ORDS/config
```

Windows:

```powershell
New-Item -ItemType Directory -Force .\ORDS\config
```

Then start:

```bash
docker compose up -d --build
```

The startup script will detect that no ORDS configuration exists and perform the first-time installation.

> Do not perform this procedure during normal restarts or routine upgrades.

---

# 26. Git and Security

The following files must NOT be committed to Git:

```text
.env
ORDS/config/*
```

The `.gitignore` file protects these files.

The repository should contain:

```text
.env.example
```

instead of:

```text
.env
```

`.env.example` contains placeholders only:

```env
SYS_PASS=CHANGE_ME
ORDS_PASS=CHANGE_ME
```

---

# 27. Git Deployment to Linux

On the Linux server:

```bash
git clone <repository-url>
cd <project-directory>
```

Create the local environment file:

```bash
cp .env.example .env
```

Edit:

```bash
nano .env
```

Enter the target database configuration and passwords.

Create the ORDS configuration directory:

```bash
mkdir -p ORDS/config
```

Then:

```bash
docker compose up -d --build
```

Check:

```bash
docker compose ps
```

and:

```bash
docker compose logs -f ords
```

---

# 28. Important Git Rule

The following are application/source files and can be version controlled:

```text
Dockerfile
docker-compose.yml
run_ords.sh
.env.example
.gitignore
README.md
```

The following are environment-specific and must remain outside Git:

```text
.env
ORDS/config/
```

This allows the same Docker project to be deployed to multiple environments without exposing credentials.

---

# 29. Troubleshooting

## ORDS says ORA-01017

Example:

```text
ORA-01017: invalid username/password; logon denied
```

Check:

```text
.env
```

Verify:

```env
DB_HOSTNAME=
DB_PORT=
DB_SERVICENAME=
SYS_PASS=
```

Do not modify the password in `docker-compose.yml`.

---

## ORDS says ORA-28000

Example:

```text
ORA-28000: The account is locked
```

Check the Oracle user:

```sql
SELECT username, account_status
FROM dba_users
WHERE username IN (
    'ORDS_PUBLIC_USER',
    'ORDS_METADATA',
    'APEX_PUBLIC_USER',
    'APEX_REST_PUBLIC_USER'
);
```

The relevant runtime accounts should not be unintentionally locked.

---

## ORDS pool is INVALID

Check:

```bash
docker compose logs ords
```

Look for:

```text
ORA-
invalid username/password
connection refused
listener
service
database
```

Verify the database connection values in `.env`.

---

## ORDS container keeps restarting

Run:

```bash
docker compose ps
```

Then:

```bash
docker compose logs --tail=200 ords
```

Look for the first actual error rather than the final container restart message.

---

## Port 8085 is already in use

Check the host port.

Windows:

```powershell
netstat -ano | findstr :8085
```

Linux:

```bash
ss -lntp | grep 8085
```

Change the host port in `docker-compose.yml` or `.env` if required.

---

# 30. Useful Docker Commands

### Build

```bash
docker compose build
```

### Start

```bash
docker compose up -d
```

### Start and rebuild

```bash
docker compose up -d --build
```

### Stop

```bash
docker compose down
```

### Restart

```bash
docker compose restart
```

### View logs

```bash
docker compose logs -f ords
```

### Container status

```bash
docker compose ps
```

### Open a shell inside the container

```bash
docker exec -it ords_apex /bin/bash
```

### Check ORDS version

```bash
docker exec ords_apex /opt/ords/bin/ords --version
```

### Check generated pool

```bash
docker exec ords_apex \
  cat /opt/ords-config/databases/default/pool.xml
```

Do not share pool configuration publicly if it contains sensitive information.

---

# 31. Deployment Checklist

Before handing the project to the client, verify:

### Files

* [ ] `Dockerfile` is present
* [ ] `docker-compose.yml` is present
* [ ] `run_ords.sh` is present
* [ ] `.gitignore` is present
* [ ] `.env.example` is present
* [ ] `README.md` is present
* [ ] `ORDS/config/.gitkeep` is present

### ORDS

* [ ] Correct ORDS package/version is used
* [ ] `ORDS_DIR` matches the Dockerfile
* [ ] `/opt/ords/bin/ords` exists
* [ ] ORDS starts successfully
* [ ] ORDS pool reports `VALID`

### APEX

* [ ] Correct APEX package is used
* [ ] `apex/images` exists
* [ ] APEX is installed/configured in the target database
* [ ] APEX is accessible through ORDS

### Database

* [ ] Database hostname is correct
* [ ] Database port is correct
* [ ] Database service name is correct
* [ ] SYS credentials are correct
* [ ] ORDS runtime credentials are correct
* [ ] Required database users are unlocked

### Security

* [ ] `.env` is NOT committed
* [ ] Real passwords are NOT in `docker-compose.yml`
* [ ] Real passwords are NOT in `Dockerfile`
* [ ] Real passwords are NOT in `run_ords.sh`
* [ ] Real passwords are NOT in `README.md`
* [ ] Generated `ORDS/config` is NOT committed
* [ ] Git history has been checked for accidentally committed passwords

---

# 32. Production Recommendation

For production/client deployment, keep the following separation:

```text
Git Repository
│
├── Dockerfile
├── docker-compose.yml
├── run_ords.sh
├── .env.example
├── .gitignore
└── README.md

Client Server
│
├── .env
│
└── ORDS/
    └── config/
        └── generated ORDS configuration
```

The Docker image contains the application/runtime components.

The client server contains environment-specific configuration and secrets.

This allows the same Docker image/project to be deployed to development, testing, and production environments without embedding credentials into the image.

---

# 33. Final Deployment Flow

```text
1. Obtain Oracle APEX package
          │
          ▼
2. Extract APEX
   into ./apex
          │
          ▼
3. Obtain Oracle ORDS package
          │
          ▼
4. Configure Dockerfile
   with correct ORDS version/path
          │
          ▼
5. Verify run_ords.sh
          │
          ▼
6. Create .env
   with target DB credentials
          │
          ▼
7. Ensure ./ORDS/config exists
          │
          ▼
8. Build Docker image
          │
          ▼
9. Start Docker Compose
          │
          ▼
10. ORDS first-time installation
          │
          ▼
11. ORDS generates configuration
          │
          ▼
12. Pool becomes VALID
          │
          ▼
13. Access APEX through ORDS
          │
          ▼
14. Commit source files to Git
    without secrets
```

---

## Important

**Never commit real database passwords to Git.**

Use:

```text
.env
```

for environment-specific secrets and:

```text
.env.example
```

for documentation/placeholders.

Keep generated ORDS configuration under:

```text
ORDS/config/
```

on the deployment server, but exclude it from Git.
