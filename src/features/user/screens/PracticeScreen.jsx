import { useState } from 'react';
import { useParams, useLocation, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { FiArrowLeft, FiVolume2, FiBook, FiX } from 'react-icons/fi';
import { auth } from '../../../firebaseConfig';
import { AppColors } from '../../../core/constants/appColors';
import * as FS from '../../../services/firestoreService';
import { getDefinition } from '../../../services/dictionaryService';
import PronunciationRecorderWidget from '../../shared/PronunciationRecorderWidget';

export default function PracticeScreen() {
  const { sentenceId } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const sentence = location.state?.sentence || { id: sentenceId, vietnamese: '', english: '' };

  const text = sentence.vietnamese || '';

  // Dictionary & Selection state
  const [popupPos, setPopupPos] = useState(null);
  const [selectedText, setSelectedText] = useState('');
  const [dictModal, setDictModal] = useState(null); // { word, definition, phonetic, loading }

  const handleResult = async (result) => {
    const user = auth.currentUser;
    if (user) {
      await FS.saveProgress({
        uid: user.uid,
        sentenceId: sentence.id,
        topicId: sentence.topicId || '',
        score: result.accuracy,
      });
    }
  };

  const handleMouseUp = (e) => {
    const selection = window.getSelection();
    const textStr = selection.toString().trim();
    if (textStr.length > 0 && textStr.length < 50) {
      // Calculate position slightly above cursor
      setPopupPos({ x: e.clientX, y: e.clientY - 40 });
      setSelectedText(textStr);
    } else {
      setPopupPos(null);
      setSelectedText('');
    }
  };

  const handleListen = () => {
    if (!selectedText) return;
    const utterance = new SpeechSynthesisUtterance(selectedText);
    utterance.lang = 'en-US'; // Hoặc 'vi-VN' tùy ngôn ngữ ưu tiên
    window.speechSynthesis.speak(utterance);
    setPopupPos(null);
    window.getSelection()?.removeAllRanges();
  };

  const handleLookup = async () => {
    if (!selectedText) return;
    const wordToLookUp = selectedText;
    setPopupPos(null);
    window.getSelection()?.removeAllRanges();
    setDictModal({ loading: true, word: wordToLookUp });
    try {
      const result = await getDefinition(wordToLookUp);
      setDictModal({ ...result, loading: false });
    } catch (err) {
      setDictModal({ word: wordToLookUp, definition: 'Không thể tra từ điển lúc này.', phonetic: '', loading: false });
    }
  };

  return (
    <div style={{ minHeight: '100vh', background: AppColors.background, display: 'flex', flexDirection: 'column' }}>
      {/* Header */}
      <div className="gradient-header">
        <button className="back-btn" onClick={() => navigate(-1)}><FiArrowLeft size={22} /></button>
        <h2>Luyện Phát Âm</h2>
        <div style={{ width: 48 }} />
      </div>

      {/* Content */}
      <div style={{ flex: 1, overflowY: 'auto', padding: 20 }}>
        <div className="content-centered">
        {/* Target text card */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          className="card"
          style={{ marginBottom: 16, textAlign: 'center', position: 'relative' }}
        >
          <span className="badge badge-primary" style={{ marginBottom: 16 }}>Câu cần đọc</span>
          <div onMouseUp={handleMouseUp} onTouchEnd={handleMouseUp}>
            <p style={{
              fontSize: 24, fontWeight: 700, color: AppColors.textPrimary,
              lineHeight: 1.5, userSelect: 'text', cursor: 'text', marginTop: 16,
            }}>
              {text.toLowerCase()}
            </p>
          </div>
          {sentence.english && (
            <p style={{ fontSize: 14, color: AppColors.textSecondary, marginTop: 8, fontStyle: 'italic' }}>
              {sentence.english}
            </p>
          )}
        </motion.div>

        {/* Recorder card */}
        <motion.div
          initial={{ opacity: 0, y: 10 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.2 }}
          className="card"
        >
          <div style={{ textAlign: 'center', marginBottom: 20 }}>
            <span className="badge badge-accent">Kết quả nhận diện</span>
          </div>
          <PronunciationRecorderWidget
            targetText={text}
            recordId={`practice_${sentence.id}`}
            showListenSample={true}
            onResult={handleResult}
          />
        </motion.div>
        </div>
      </div>

      {/* Floating Selection Menu */}
      {popupPos && (
        <div style={{
          position: 'fixed', top: popupPos.y, left: popupPos.x,
          transform: 'translate(-50%, -100%)', zIndex: 9999,
          background: 'white', borderRadius: 8, padding: '4px 8px',
          boxShadow: '0 4px 12px rgba(0,0,0,0.15)', display: 'flex', gap: 8,
          border: '1px solid rgba(0,0,0,0.05)'
        }}>
          <button onClick={handleListen} className="btn-icon" style={{ width: 32, height: 32, background: AppColors.primaryLight, color: 'white' }}>
            <FiVolume2 size={16} />
          </button>
          <button onClick={handleLookup} className="btn-icon" style={{ width: 32, height: 32, background: AppColors.accent, color: 'white' }}>
            <FiBook size={16} />
          </button>
        </div>
      )}

      {/* Dictionary Modal */}
      {dictModal && (
        <div className="modal-overlay" onClick={() => setDictModal(null)}>
          <motion.div className="modal-content" onClick={e => e.stopPropagation()} initial={{ scale: 0.9 }} animate={{ scale: 1 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <h3 style={{ margin: 0, color: AppColors.primary }}>Tra từ điển</h3>
              <button className="btn-icon" onClick={() => setDictModal(null)}><FiX size={20} /></button>
            </div>
            
            {dictModal.loading ? (
              <div style={{ textAlign: 'center', padding: 20 }}>
                <div className="spinner" style={{ margin: '0 auto 12px' }}></div>
                <p style={{ color: AppColors.textSecondary }}>Đang tra từ...</p>
              </div>
            ) : (
              <div>
                <p style={{ fontSize: 22, fontWeight: 700, margin: '0 0 4px 0', color: AppColors.textPrimary }}>{dictModal.word}</p>
                {dictModal.phonetic && <p style={{ color: AppColors.textSecondary, fontStyle: 'italic', margin: '0 0 12px 0' }}>/{dictModal.phonetic}/</p>}
                
                <div style={{ background: AppColors.background, padding: 16, borderRadius: 8, marginTop: 12 }}>
                  {/* Primary Definition */}
                  <p style={{ margin: 0, fontSize: 16, fontWeight: 600, color: AppColors.primary, marginBottom: dictModal.parts?.length ? 12 : 0 }}>
                    {dictModal.definition}
                  </p>

                  {/* Fallback Structured Parts */}
                  {dictModal.parts && dictModal.parts.length > 0 && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                      {dictModal.parts.map((p, idx) => (
                        <div key={idx} style={{ background: 'white', padding: 12, borderRadius: 6, border: '1px solid rgba(0,0,0,0.05)' }}>
                          <span style={{ 
                            display: 'inline-block', padding: '2px 8px', borderRadius: 4, 
                            background: AppColors.primaryLight + '20', color: AppColors.primary, 
                            fontSize: 12, fontWeight: 600, marginBottom: 6, textTransform: 'uppercase' 
                          }}>
                            {p.type}
                          </span>
                          <p style={{ margin: 0, color: AppColors.textPrimary, lineHeight: 1.5 }}>
                            {p.terms}
                          </p>
                        </div>
                      ))}
                    </div>
                  )}

                  {/* Raw AI String Parsing (if AI is working) */}
                  {!dictModal.parts && typeof dictModal.definition === 'string' && dictModal.definition.includes('\n') && (
                    <div style={{ marginTop: 12 }}>
                      {dictModal.definition.split('\n').map((line, i) => {
                        if (!line.trim()) return null;
                        if (line.includes(':')) {
                          const [label, ...rest] = line.split(':');
                          return (
                            <p key={i} style={{ margin: '0 0 8px 0', lineHeight: 1.5 }}>
                              <strong style={{ color: AppColors.textPrimary }}>{label}:</strong> {rest.join(':')}
                            </p>
                          );
                        }
                        return <p key={i} style={{ margin: '0 0 8px 0', lineHeight: 1.5 }}>{line}</p>;
                      })}
                    </div>
                  )}
                </div>
              </div>
            )}
          </motion.div>
        </div>
      )}
    </div>
  );
}
