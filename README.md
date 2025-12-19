# github-action-ecs-service-deployment

A Github Action to deploy Skaylink Managed AWS ECS Services.

Example:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy Service
        uses: skaylink/github-action-ecs-service-deployment
        with:
          token: ${{ secret.API_TOKEN }}
          url: ${{ secret.API_URL }}
          service: my-example-service
          image: my/image:new-version
```

## Inputs

| Input | Required? | Default | Description |
| ----- | --------- | ------- | ----------- |
| `token` | `true` |  | Deployment API token. (please use `${{ secret.<your-secret-name> }}`) |
| `url` | `true` |  | Deployment API url. (please use `${{ secret.<your-secret-name> }}`) |
| `service` | `true` |  | The name of the ECS service to update. |
| `image` | `true` |  | The container image to use for the service. |
| `force` | `false` | `false` | Force deployment of same image. |
| `secret_arns` | `false` | | Comma-separated list of secret ARNs to attach to the service. |
| `detached` | `false` | `false` | Detached deployment without waiting for result. |
