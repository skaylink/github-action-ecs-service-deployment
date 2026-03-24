# github-action-ecs-service-deployment

A Github Action to deploy Skaylink Managed AWS ECS Services.

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

## Example

You need to add action secrets for `token`, `url` and `service`.

```yaml
on:
  release:
    types:
      - published # run on new release

env:
  # name of your repo. You might as well just use the same name as for the service
  # and then use ${{ secrets.DEPLOYMENT_SERVICE }}
  REPOSITORY: my-ecr-repo

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v6
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v5.1.1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-central-1
      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2
      - name: Build, tag, and push docker image to Amazon ECR
        run: |
          docker buildx build --push -t ${{ steps.login-ecr.outputs.registry }}/$REPOSITORY:${{ github.ref_name }} .
      - name: Deploy Service
        uses: skaylink/github-action-ecs-service-deployment
        id: deploy-service
        with:
          token: ${{ secrets.DEPLOYMENT_TOKEN }}
          url: ${{ secrets.DEPLOYMENT_URL }}
          service: ${{ secrets.DEPLOYMENT_SERVICE }}
          image: ${{ steps.login-ecr.outputs.registry }}/$REPOSITORY:${{ github.ref_name }}
```
