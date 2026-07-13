// GummyPlugin template UI logic. Each control binds to its APVTS parameter via
// the JUCE frontend library (relay id === parameter id from docs/contracts/parameters.md).
import * as Juce from "./juce/index.js";

function bindSlider(paramId, inputEl, readoutEl, formatValue) {
  const state = Juce.getSliderState(paramId);

  // UI -> backend
  inputEl.addEventListener("pointerdown", () => state.sliderDragStarted());
  inputEl.addEventListener("input", () => {
    state.setNormalisedValue(parseFloat(inputEl.value));
  });
  inputEl.addEventListener("pointerup", () => state.sliderDragEnded());

  // backend -> UI (automation, presets, other controls)
  state.valueChangedEvent.addListener(() => {
    inputEl.value = state.getNormalisedValue();
    if (readoutEl) readoutEl.textContent = formatValue(state.getScaledValue());
  });
}

bindSlider(
  "gain",
  document.getElementById("gain"),
  document.getElementById("gain-readout"),
  (db) => `${db.toFixed(1)} dB`
);
