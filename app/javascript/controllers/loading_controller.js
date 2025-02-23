import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["button", "spinner"];

  connect() {
    console.log("Loading controller connected");
  }

  start(event) {
    console.log("Loading started");
    this.buttonTarget.disabled = true;
    this.spinnerTarget.classList.remove("hidden");
  }

  end(event) {
    console.log("Loading ended");
    this.buttonTarget.disabled = false;
    this.spinnerTarget.classList.add("hidden");
  }

  error(event) {
    console.log("Loading error:", event.detail);
    this.buttonTarget.disabled = false;
    this.spinnerTarget.classList.add("hidden");
  }
}
