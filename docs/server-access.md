# Production server access

A quick reference for getting onto the existing RPG server and looking around.
The commands below open a session or inspect the deployment; they do not deploy,
restart services, or delete data.

## Your computer: find the right server and account

**Kirk's workstation uses AWS profile `personal`, not the old-job SSO profiles.**
Keep the profile and region explicit on each AWS command rather than changing
system-wide defaults. Other operators should use their own authorized profile.

Current access details, verified against CloudFormation on **2026-09-08**:

| Setting | Value |
|---|---|
| AWS profile on Kirk's workstation | `personal` |
| Region | `us-west-2` |
| CloudFormation stack | `rpg-gaming-platform` |
| Public IP | `52.37.237.141` |
| Instance ID | `i-017780344a5d8d778` |
| SSH user | `ubuntu` |
| Existing SSH key | `~/.ssh/rpg-deployment.pem` |

If the server is replaced, rediscover its IP, instance ID, and SSH command before
using the examples below. Run this **on your computer**, not inside the server:

```bash
aws --profile personal --region us-west-2 cloudformation describe-stacks \
  --stack-name rpg-gaming-platform \
  --query 'Stacks[0].Outputs' \
  --output table
```

Look for `PublicIP`, `InstanceId`, and `SSHCommand`. The values returned by AWS
are the current authority; the table above is a dated reference.

Do not run `aws configure` or regenerate the key merely to connect. Those are
setup operations, and Kirk's working credentials and key already exist. Never
paste private keys, AWS credentials, Discord tokens, or the server's `.env` into
chat or GitHub.

## Your computer: connect

### SSH — simplest

```bash
ssh -i ~/.ssh/rpg-deployment.pem \
  -o IdentitiesOnly=yes \
  ubuntu@52.37.237.141
```

`IdentitiesOnly=yes` keeps SSH from trying unrelated keys. Once connected, the
prompt normally changes to something like `ubuntu@ip-10-0-1-207`.

If SSH reports a changed host key, verify the target and host identity through
your trusted access path. Do not disable host-key checking or blindly remove the
old trust entry.

### Alternative: AWS Session Manager

Requires AWS CLI, the Session Manager plugin, and permission to start a session.
The plugin is installed on Kirk's workstation; this route does not use the SSH key.

```bash
aws --profile personal --region us-west-2 ssm start-session \
  --target i-017780344a5d8d778
```

SSM may open as a different user from SSH. Run `whoami` to see which account you
have. If access or Docker permissions are denied, stop and check the intended
profile/user with the owner rather than changing groups or permissions.

For either connection, use `exit` or **Ctrl+D** to disconnect.

## On the server: see what is running

All commands in the remaining sections run **inside your SSH or SSM session**.

```bash
whoami
hostname
cd /opt/rpg-deployment
docker compose -f docker-compose.prod.yml ps --all
```

| Container | Purpose |
|---|---|
| `rpg-api` | Go game server |
| `rpg-web` | Browser application |
| `rpg-envoy` | gRPC-Web proxy |
| `rpg-nginx` | Public-facing proxy |
| `rpg-discord-auth` | Discord authentication |
| `rpg-redis` | Stored game data |

`Restarting` is a warning sign: the application is exiting and Docker is trying
again. `Up` alone is not the same as a successful application health check.

## On the server: read logs and restart counts

```bash
# Recent API logs
docker logs --since 10m --tail 100 rpg-api

# Follow new API logs
docker logs --tail 50 --follow rpg-api
```

**Ctrl+C stops following logs. It does not stop the container.** Substitute
`rpg-web`, `rpg-envoy`, or `rpg-nginx` to inspect another service.

```bash
docker inspect rpg-api --format \
  'status={{.State.Status}} restarts={{.RestartCount}} exit={{.State.ExitCode}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}'
```

If the restart count keeps increasing, inspect the startup error before trying
repeated restarts. For example, the 2026-09-07 release failed to start because
persistent dungeon YAML still used the deleted wall `edges` format. A restart
alone could not repair those files.

## On the server: identify deployed versions

`latest` is a moving image tag, not a version. The OCI revision label identifies
the commit used to build each running application image:

```bash
docker inspect rpg-api rpg-web --format \
  '{{.Name}} revision={{index .Config.Labels "org.opencontainers.image.revision"}} imageID={{.Image}}'
```

The checkout in `/opt/rpg-deployment` contains deployment configuration. It is
**not** the API or web source checkout; those applications ship inside images.

```bash
# Revision of deployment configuration, not the application images
git -C /opt/rpg-deployment rev-parse HEAD
```

## On the server: resources and important files

```bash
df -h                       # Disk space
free -h                     # Host memory
docker stats --no-stream    # Container resource usage
docker system df            # Docker disk usage; inspection only
```

| Location | Contains |
|---|---|
| `/opt/rpg-deployment/` | Deployment configuration and Compose files |
| `/opt/rpg-deployment/content/` | Persistent authored dungeon YAML |
| `/home/ubuntu/release-backups/` | Backups retained during recovery operations |

```bash
ls -lh /opt/rpg-deployment/content
ls -lh /home/ubuntu/release-backups
```

Content files persist across deployments and are not replaced merely by pulling
new images. Back them up before an approved change. Keep backups outside the
active content directory so the API does not try to load old YAML from them.

## Health checks and safety

- A successful Actions deployment or HTTP 200 from `/health` is not enough to
  prove the API works. That endpoint is served by nginx. Check API logs, health,
  restart count, and an actual request through the activity.
- Some public API routes require the Discord routing headers; a bare `curl`
  can receive an intentional 404. A 503, an authentication response, and an
  application error mean different things. Do not bypass authentication to test.
- Inspect selected Docker fields as above instead of dumping configuration that
  may contain environment secrets.
- Do not run `docker compose down -v`, volume pruning, Redis flush commands, or
  dungeon cleanup scripts while just looking around.
- Restarting, deploying, moving dungeon files, or restoring backups is a separate,
  explicitly approved operation—not part of this inspection guide.

[Back to the deployment README](../README.md)
