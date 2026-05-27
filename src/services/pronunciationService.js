import { AppStrings } from '../core/constants/appStrings';

/**
 * Evaluate pronunciation by sending audio to the API
 * @param {string} targetText - Expected text
 * @param {Blob} audioBlob - Recorded audio blob
 * @returns {Promise<{targetText: string, recognizedText: string, accuracy: number, passed: boolean}>}
 */
export async function evaluate(targetText, audioBlob) {
  const formData = new FormData();
  formData.append('target_text', targetText);
  formData.append('audio_file', audioBlob, 'recording.wav');

  const response = await fetch(AppStrings.evalEndpoint, {
    method: 'POST',
    body: formData,
  });

  if (!response.ok) {
    throw new Error(`API Error: ${response.status}`);
  }

  const json = await response.json();
  const data = json.data || json;

  const target = (data.target_text || targetText).toLowerCase();
  const recognized = (data.recognized_text || '').toLowerCase();

  // Calculate accuracy word-by-word
  const targetWords = target.split(/\s+/).filter(Boolean);
  const recognizedWords = recognized.split(/\s+/).filter(Boolean);

  let correct = 0;
  for (let i = 0; i < targetWords.length; i++) {
    if (i < recognizedWords.length && targetWords[i] === recognizedWords[i]) {
      correct++;
    }
  }

  const accuracy = targetWords.length > 0
    ? Math.round((correct / targetWords.length) * 100)
    : 0;

  return {
    targetText: target,
    recognizedText: recognized,
    accuracy,
    passed: accuracy >= 80,
  };
}

/**
 * Get TTS audio URL for given text
 * @param {string} text
 * @returns {string}
 */
export function getTtsUrl(text) {
  return `${AppStrings.ttsEndpoint}?text=${encodeURIComponent(text)}`;
}
