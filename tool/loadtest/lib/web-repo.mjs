// Firestore kurallarının ve web kaynaklarının TEK kaynağı: Regipass-Web reposu (İP-1).
// Varsayılan: bu reponun yanındaki klasör (~/Developer/Regipass/Regipass-Web).
// Başka yerdeyse: REGIPASS_WEB=/yol/Regipass-Web node <betik>
import { resolve } from 'node:path';

export const WEB_ROOT = process.env.REGIPASS_WEB
  ?? resolve(import.meta.dirname, '..', '..', '..', '..', 'Regipass-Web');
