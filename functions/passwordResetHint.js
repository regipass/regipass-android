const { HttpsError } = require('firebase-functions/v2/https');

function maskAuthPhone(phone) {
  if (typeof phone !== 'string' || !/^\+[1-9]\d{6,14}$/.test(phone)) return '';
  if (/^\+90\d{10}$/.test(phone)) return `+90 XXX XXX XX ${phone.slice(-2)}`;
  return `+${'X'.repeat(phone.length - 3)}${phone.slice(-2)}`;
}

// Profildeki phoneVerified bayrağı tek başına kurtarma yetkisi değildir.
// Yalnızca Firebase Auth'a gerçekten bağlanmış telefon kullanılır.
function createPasswordResetHintHandler({ auth, rateLimit, logError }) {
  return async (request) => {
    const raw = request.data?.email;
    const email = typeof raw === 'string' ? raw.trim().toLowerCase() : '';
    if (email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError('invalid-argument', 'Invalid email.');
    }
    await rateLimit(email);
    try {
      const user = await auth.getUserByEmail(email);
      return { maskedPhone: user.disabled ? '' : maskAuthPhone(user.phoneNumber), roles: [] };
    } catch (error) {
      if (error?.code === 'auth/user-not-found') return { maskedPhone: '', roles: [] };
      logError({ code: error?.code || 'unknown' });
      throw new HttpsError('unavailable', 'Could not load recovery hint.');
    }
  };
}

module.exports = { maskAuthPhone, createPasswordResetHintHandler };
