import { ref, uploadBytes, getDownloadURL, deleteObject } from 'firebase/storage';
import { storage } from '../firebaseConfig';

/**
 * Upload image file to Firebase Storage
 * @param {File} file - The file to upload
 * @param {string} folder - Storage folder (e.g. 'avatars')
 * @returns {Promise<string>} Download URL
 */
export async function uploadImage(file, folder = 'avatars') {
  const fileName = `${folder}/${Date.now()}_${file.name}`;
  const storageRef = ref(storage, fileName);
  const snapshot = await uploadBytes(storageRef, file);
  // Small delay to ensure file is available (matching Flutter's whenComplete fix)
  await new Promise(resolve => setTimeout(resolve, 500));
  const url = await getDownloadURL(snapshot.ref);
  return url;
}

/**
 * Delete file from Storage by its download URL
 * @param {string} url - The download URL
 */
export async function deleteByUrl(url) {
  try {
    const storageRef = ref(storage, url);
    await deleteObject(storageRef);
  } catch (e) {
    console.warn('Storage delete failed:', e);
  }
}
