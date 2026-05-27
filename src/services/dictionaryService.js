import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebaseConfig';

const GEMINI_API_KEY = 'AIzaSyAFYx84TkM4LDRNO1EXiGHgylsgLmCWkaI';
const GEMINI_MODELS = ['gemini-2.5-flash-lite', 'gemini-2.5-flash'];

/**
 * Get word definition: cache-first (Firestore) → LLM fallback (Gemini)
 * @param {string} text - Word or phrase to define
 * @returns {Promise<{word: string, definition: string, phonetic: string}>}
 */
export async function getDefinition(text) {
  const cleanText = text.trim().toLowerCase().replace(/[^a-zA-ZÀ-ỹ\s]/g, '');
  if (!cleanText) throw new Error('Empty text');

  // 1. Check Firestore cache
  try {
    const cached = await getDoc(doc(db, 'dictionary', cleanText));
    if (cached.exists()) {
      const data = cached.data();
      return {
        word: data.word || cleanText,
        definition: data.definition || '',
        phonetic: data.phonetic || '',
      };
    }
  } catch (e) {
    console.warn('Cache read failed:', e);
  }

  // 2. Gemini API fallback
  for (const model of GEMINI_MODELS) {
    try {
      const url = `https://generativelanguage.googleapis.com/v1/models/${model}:generateContent?key=${GEMINI_API_KEY}`;
      const prompt = `Bạn là một từ điển Việt-Anh học thuật. Hãy định nghĩa từ/cụm từ '${cleanText}' bằng tiếng Anh. Trả lời theo format JSON: {"word":"...","definition":"...","phonetic":"..."}. Chỉ trả về JSON, không giải thích thêm.`;

      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
        }),
      });

      if (!response.ok) continue;

      const json = await response.json();
      const content = json.candidates?.[0]?.content?.parts?.[0]?.text || '';

      // Parse JSON from response
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (!jsonMatch) continue;

      const parsed = JSON.parse(jsonMatch[0]);
      const result = {
        word: parsed.word || cleanText,
        definition: parsed.definition || 'Không tìm thấy định nghĩa',
        phonetic: parsed.phonetic || '',
      };

      // 3. Save to Firestore cache
      try {
        await setDoc(doc(db, 'dictionary', cleanText), {
          ...result,
          updatedAt: serverTimestamp(),
        });
      } catch (e) {
        console.warn('Cache write failed:', e);
      }

      return result;
    } catch (e) {
      console.warn(`Gemini ${model} failed:`, e);
      continue;
    }
  }

  throw new Error('Không thể tra từ điển lúc này');
}
