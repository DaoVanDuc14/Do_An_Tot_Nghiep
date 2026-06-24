import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { db } from '../firebaseConfig';

const GEMINI_API_KEY = 'AIzaSyAFYx84TkM4LDRNO1EXiGHgylsgLmCWkaI';
const GEMINI_MODELS = ['gemini-1.5-flash', 'gemini-1.5-pro'];

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

  // 2. Gọi API từ VPS (Giống hệ thống App)
  try {
    const url = 'http://116.118.2.137:8000/api/v1/dictionary';
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ text: cleanText }),
    });

    if (!response.ok) throw new Error('Lỗi từ VPS API');

    const json = await response.json();
    if (json.detail) throw new Error(json.detail);
    
    const content = json.definition || '';

    let parsed = {};
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      try {
        parsed = JSON.parse(jsonMatch[0]);
      } catch(e) {}
    }

    const definition = parsed.definition || parsed['Nghĩa'] || parsed['Giải thích'] || content.replace(/```json/g, '').replace(/```/g, '').trim();
    const phonetic = parsed.phonetic || parsed['Phiên âm'] || '';

    const result = {
      word: parsed.word || cleanText,
      definition: definition || 'Không tìm thấy định nghĩa',
      phonetic: phonetic,
    };

    // 3. Save to Firestore cache
    try {
      await setDoc(doc(db, 'dictionary', cleanText), {
        ...result,
        updatedAt: serverTimestamp(),
      });
    } catch (e) {}

    return result;
  } catch (vpsError) {
    console.warn(`VPS Dictionary API failed, trying Google Translate fallback:`, vpsError);
    
    // 3. Google Translate Fallback
    try {
      const gtUrl = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=vi&tl=en&dt=t&dt=bd&q=${encodeURIComponent(cleanText)}`;
      const gtRes = await fetch(gtUrl);
      if (!gtRes.ok) throw new Error('Google Translate API failed');
      const gtJson = await gtRes.json();
      
      let translated = '';
      if (gtJson[0] && gtJson[0][0] && gtJson[0][0][0]) {
        translated = gtJson[0][0][0];
      }
      
      let parts = [];
      if (gtJson[1] && gtJson[1].length > 0) {
        gtJson[1].forEach(pos => {
           const type = pos[0] || 'word';
           const terms = (pos[1] || []).join(', ');
           parts.push({ type, terms });
        });
      }
      
      const result = {
        word: cleanText,
        definition: translated, // Primary translation
        phonetic: '',
        parts: parts // Structured parts of speech
      };
      
      try {
        await setDoc(doc(db, 'dictionary', cleanText), {
          ...result,
          updatedAt: serverTimestamp(),
        });
      } catch (e) {}
      
      return result;
    } catch (gtError) {
      console.warn(`Google Translate Fallback failed:`, gtError);
      throw new Error('Không thể tra từ điển lúc này');
    }
  }
}
