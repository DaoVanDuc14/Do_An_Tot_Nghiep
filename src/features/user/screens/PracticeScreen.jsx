import { useParams, useLocation, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import { FiArrowLeft } from 'react-icons/fi';
import { auth } from '../../../firebaseConfig';
import { AppColors } from '../../../core/constants/appColors';
import * as FS from '../../../services/firestoreService';
import PronunciationRecorderWidget from '../../shared/PronunciationRecorderWidget';

export default function PracticeScreen() {
  const { sentenceId } = useParams();
  const location = useLocation();
  const navigate = useNavigate();
  const sentence = location.state?.sentence || { id: sentenceId, vietnamese: '', english: '' };

  const text = sentence.vietnamese || '';

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
          style={{ marginBottom: 16, textAlign: 'center' }}
        >
          <span className="badge badge-primary" style={{ marginBottom: 16 }}>Câu cần đọc</span>
          <p style={{
            fontSize: 24, fontWeight: 700, color: AppColors.textPrimary,
            lineHeight: 1.5, userSelect: 'text', cursor: 'text', marginTop: 16,
          }}>
            {text.toLowerCase()}
          </p>
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
    </div>
  );
}
