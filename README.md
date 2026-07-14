# Coin Flip Serverless

A deliberately tiny web app for **learning AWS Serverless Architecture**. It is not meant to be production software — it exists so you can watch, step by step, how a browser request travels through **API Gateway**, triggers an **AWS Lambda** function written in plain Python, and comes back as a response rendered on the page.

Click "Flip Coin" and the app tells you Heads or Tails. That's the entire feature set, on purpose — the simplicity keeps the focus on the *infrastructure*, not the app logic.

## Project Overview

| Layer | Technology |
|---|---|
| Frontend | Static HTML5 + CSS3 + vanilla JavaScript (no framework) |
| Backend | A single AWS Lambda function, Python 3.12, no web framework |
| API layer | Amazon API Gateway (HTTP API) |
| Infrastructure | Terraform |
| CI/CD | GitHub Actions (GitHub-hosted runners) |
| Logging | Python's stdlib `logging`, captured automatically by CloudWatch Logs |

There is intentionally **no database, no authentication, no framework (no FastAPI/Flask/Django), and no Lambda adapter (no Mangum)**. The Lambda handler is a plain function that receives the raw API Gateway event and returns a plain dict — exactly what Lambda expects, with nothing hidden by a framework.

## Architecture

```
 Browser                API Gateway            Lambda               CloudWatch
┌─────────┐  fetch()   ┌───────────┐  invoke  ┌──────────┐  logs   ┌───────────┐
│ index.html├─────────►│ HTTP API   ├─────────►│ lambda_  ├────────►│ Log Group │
│ app.js   │  GET /flip│ GET /flip  │          │function.py│        │           │
└─────────┘◄─────────┘└───────────┘◄─────────┘└──────────┘         └───────────┘
              JSON response          JSON response
```

## Request Flow

1. The user opens `frontend/index.html` in a browser and clicks **Flip Coin**.
2. `app.js` disables the button, shows a spinner, and calls `fetch()` against the API Gateway endpoint (`GET /flip`).
3. **API Gateway** (an HTTP API, the lightweight/cheaper cousin of a REST API) receives the request and, via a Lambda proxy integration, invokes the **Lambda function**.
4. The **Lambda function** (`backend/lambda_function.py`) runs `lambda_handler(event, context)`:
   - Logs the incoming event, request ID, and timestamp.
   - Uses Python's `random.choice(["Heads", "Tails"])` to pick a result.
   - Logs the generated result and that execution completed.
   - Returns a dict shaped like an API Gateway HTTP API response (`statusCode`, `headers`, `body`).
5. API Gateway converts that dict into an actual HTTP response and sends it back to the browser.
6. `app.js` parses the JSON body and renders the result in an animated card, then re-enables the button.
7. Every invocation's logs land in **CloudWatch Logs**, under `/aws/lambda/coin-flip-flip-coin`.

## Folder Structure

```
coin-flip-serverless/          (this repository)
│
├── frontend/
│   ├── index.html      # Page structure: title, description, button, result area
│   ├── styles.css      # Modern, responsive styling + spinner/card animations
│   └── app.js          # Fetch call, loading state, result rendering
│
├── backend/
│   ├── lambda_function.py   # Plain Lambda handler (no framework, no adapter)
│   └── requirements.txt     # Empty — stdlib only
│
├── terraform/
│   ├── provider.tf     # AWS + archive provider configuration
│   ├── main.tf         # Lambda, IAM role, API Gateway, CloudWatch log group, permissions
│   ├── variables.tf    # Region, project name, runtime, log retention
│   └── outputs.tf      # Invoke URL, function name, log group name
│
├── .github/
│   └── workflows/
│       └── deploy.yml  # CI/CD pipeline (Terraform plan/apply on push to main)
│
├── README.md
└── .gitignore
```

## Running Locally (Frontend Only)

The frontend is fully static — no build step, no bundler.

1. Deploy the backend first (see below) so you have a real API Gateway URL, or point `API_URL` at any already-deployed endpoint.
2. Open `frontend/app.js` and set `API_URL` to your API Gateway invoke URL + `/flip`, e.g.:

   ```js
   const API_URL = "https://abc123xyz.execute-api.us-east-1.amazonaws.com/flip";
   ```

3. Serve the `frontend/` folder with any static file server (opening `index.html` directly via `file://` also works, since the API has CORS enabled for `*`):

   ```bash
   cd frontend
   python -m http.server 8080
   ```

4. Visit `http://localhost:8080` and click **Flip Coin**.

You can also test the Lambda handler in isolation without any AWS resources:

```bash
cd backend
python -c "
from lambda_function import lambda_handler
event = {'requestContext': {'http': {'method': 'GET'}}}
print(lambda_handler(event, type('ctx', (), {'aws_request_id': 'local-test'})()))
"
```

## Deploying with Terraform

Requires [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.6 and AWS credentials configured locally (`aws configure` or environment variables).

```bash
cd terraform
terraform init          # downloads the aws + archive providers
terraform validate      # checks the configuration is syntactically valid
terraform plan          # shows what will be created
terraform apply         # provisions everything, prompts for confirmation
```

What gets created:

- **`aws_iam_role`** — the execution role the Lambda assumes.
- **`aws_iam_role_policy_attachment`** — attaches `AWSLambdaBasicExecutionRole` so the function can write logs.
- **`aws_cloudwatch_log_group`** — `/aws/lambda/coin-flip-flip-coin`, with a configurable retention period.
- **`aws_lambda_function`** — the coin-flip function itself, packaged automatically by the `archive_file` data source (no manual zipping needed for local `terraform apply`).
- **`aws_apigatewayv2_api`** — an HTTP API with CORS enabled for the frontend.
- **`aws_apigatewayv2_integration`** / **`aws_apigatewayv2_route`** / **`aws_apigatewayv2_stage`** — wires `GET /flip` to the Lambda with auto-deploy.
- **`aws_lambda_permission`** — explicitly grants API Gateway permission to invoke the Lambda.

After `terraform apply` finishes, copy the printed `flip_endpoint` output into `frontend/app.js`'s `API_URL`.

```bash
terraform output flip_endpoint
```

To tear everything down when you're done experimenting:

```bash
terraform destroy
```

## Deploying with GitHub Actions

The workflow at `.github/workflows/deploy.yml` runs on every push to `main` using GitHub-hosted runners:

1. Checks out the repository.
2. Sets up Python 3.12.
3. Compiles the Lambda source as a sanity check and zips it (an artifact-verification step; Terraform's `archive_file` still produces the actual deployment package).
4. Configures AWS credentials from GitHub Secrets.
5. Sets up Terraform.
6. Runs `terraform init`, `terraform validate`, `terraform plan`, and `terraform apply -auto-approve`.
7. Prints the deployed API Gateway endpoint.

### Required GitHub Secrets

Set these under **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access key for an IAM user/role with permission to manage Lambda, API Gateway, IAM, and CloudWatch |
| `AWS_SECRET_ACCESS_KEY` | Corresponding secret key |

For real-world use, prefer OIDC-based short-lived credentials over long-lived access keys — this project uses static keys only to keep the learning setup simple.

## Viewing CloudWatch Logs

Every invocation logs the incoming event, request ID, timestamp, generated result, and completion — plus any errors with a full stack trace.

**Console:** AWS Console → CloudWatch → Log groups → `/aws/lambda/coin-flip-flip-coin` → select the latest log stream.

**CLI:**

```bash
aws logs tail /aws/lambda/coin-flip-flip-coin --follow
```

## Testing the API Gateway Endpoint

Once deployed, hit the endpoint directly with `curl`:

```bash
curl https://<api-id>.execute-api.<region>.amazonaws.com/flip
```

Expected response:

```json
{
  "result": "Heads",
  "message": "The coin landed on Heads."
}
```

A failed/unhandled case returns HTTP 500 with a JSON error body instead of a raw stack trace:

```json
{
  "error": "Internal server error",
  "message": "Something went wrong while flipping the coin."
}
```

## Notes on Learning Goals

- The Lambda handler returns the *exact* dict shape API Gateway (HTTP API, payload format 2.0) expects — `statusCode`, `headers`, `body` — so you can see the contract with nothing abstracting it away.
- CORS is handled in two places on purpose: once on the API Gateway resource (`cors_configuration` in `main.tf`) and once in the Lambda's own response headers — a good example of defense-in-depth you'll see in real serverless APIs.
- The frontend never talks to AWS directly; it only ever calls the API Gateway URL, which is the whole point of the pattern — API Gateway is the public front door, Lambda is compute that only runs on demand.
