# MCP Runner Docker Image

A minimal Docker image that, on startup, clones a specified repository and serves its MCP server using `npx` (with sensible fallbacks). Suitable for Docker and Kubernetes.

## Environment Variables

- `NODE_NPX_REPO_URL` (required): Git URL to clone.
- `NODE_NPX_REPO_TOKEN` (optional/required for private repos): Token used via HTTP headers during clone.
- `NODE_NPX_REPO_PROXY` (optional): HTTP/HTTPS proxy URL if your cluster requires it.
- `NODE_NPX_RUN_CMD` (optional): Explicit command to run (e.g. `npx my-mcp@latest`).

## How it works

On container start:
1. Optionally configures git/npm proxy if `NODE_NPX_REPO_PROXY` is set
2. Clones `NODE_NPX_REPO_URL` into `/app/repo` (uses `NODE_NPX_REPO_TOKEN` via headers if set)
3. Installs Node dependencies if `package.json` exists
4. Selects a start command and `exec`s it so signals are handled properly:
   - `NODE_NPX_RUN_CMD` (if provided)
   - `npm run mcp` if present
   - `npm start` if present
   - otherwise `npx .` (or `node server.js`/`node .` if no `package.json`)

If the server process exits non-zero, the container exits. Errors are visible in container logs.

## Build

```bash
docker build -t mcp-runner:latest .
```

## Run (Docker)

```bash
docker run --rm \
  -e NODE_NPX_REPO_URL=https://github.com/your-org/your-mcp-repo.git \
  -e NODE_NPX_REPO_TOKEN=$YOUR_TOKEN \
  -e NODE_NPX_REPO_PROXY=http://proxy.internal:3128 \
  mcp-runner:latest
```

## Kubernetes Example

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-runner
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mcp-runner
  template:
    metadata:
      labels:
        app: mcp-runner
    spec:
      containers:
        - name: mcp-runner
          image: your-registry/mcp-runner:latest
          env:
            - name: NODE_NPX_REPO_URL
              value: "https://github.com/your-org/your-mcp-repo.git"
            - name: NODE_NPX_REPO_TOKEN
              valueFrom:
                secretKeyRef:
                  name: mcp-repo-token
                  key: token
            - name: NODE_NPX_REPO_PROXY
              value: "http://proxy.internal:3128" # optional
          ports:
            - containerPort: 3000 # adjust to your MCP server port if needed
      restartPolicy: Always
```

Create the secret:

```bash
kubectl create secret generic mcp-repo-token --from-literal=token=YOUR_TOKEN
```

## Notes

- Uses `tini` for clean signal handling and `exec`s the server process.
- Includes `git`, `python3`, `make`, and `g++` to build native modules during `npm install`.
- Set `NODE_NPX_RUN_CMD` to run a specific command if desired.

# oottb.docker.anymcp.npx
This docker image will setup and run MCP with npx based
