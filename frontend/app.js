// Base URL of the API Gateway HTTP API. Replace this with the "invoke_url"
// Terraform output after running `terraform apply` (see terraform/outputs.tf).
const API_URL = "https://REPLACE_ME.execute-api.REGION.amazonaws.com/flip";

const flipButton = document.getElementById("flip-btn");
const btnLabel = flipButton.querySelector(".btn-label");
const spinner = flipButton.querySelector(".spinner");
const resultArea = document.getElementById("result-area");
const errorMessage = document.getElementById("error-message");

function setLoading(isLoading) {
  flipButton.disabled = isLoading;
  spinner.hidden = !isLoading;
  btnLabel.textContent = isLoading ? "Flipping..." : "Flip Coin";
}

function renderResult(result, message) {
  const variant = result.toLowerCase() === "heads" ? "heads" : "tails";
  resultArea.innerHTML = `
    <div class="result-card ${variant}">
      <p class="result-value">${result}</p>
      <p class="result-message">${message}</p>
    </div>
  `;
}

function renderError(text) {
  errorMessage.textContent = text;
  errorMessage.hidden = false;
}

async function flipCoin() {
  errorMessage.hidden = true;
  setLoading(true);

  try {
    const response = await fetch(API_URL, { method: "GET" });

    if (!response.ok) {
      throw new Error(`Request failed with status ${response.status}`);
    }

    const data = await response.json();
    renderResult(data.result, data.message);
  } catch (error) {
    renderError(`Something went wrong: ${error.message}`);
  } finally {
    setLoading(false);
  }
}

flipButton.addEventListener("click", flipCoin);
