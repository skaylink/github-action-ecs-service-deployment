# github-action-ecs-service-deployment

A Github Action to deploy Skaylink Managed AWS ECS Services.

## Requirements

* secrets named `deploy-api-token` plus `deploy-url`

## Inputs

| Input | Required? | Default | Description |
| ----- | --------- | ------- | ----------- |
| `service` | `true` |  | The name of the ECS service to update. |
| `image` | `true` |  | The container image to use for the service. |
| `force` | `false` | `false` | Force deployment of same image. |
| `secret_arns` | `false` | | Comma-separated list of secret ARNs to attach to the service. |
| `detached` | `false` | `false` | Detached deployment without waiting for result. |
