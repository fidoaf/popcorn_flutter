const { createCipheriv, createDecipheriv, createHash, randomBytes } = require('node:crypto');

class StateTokenCodec {
  constructor(secret) {
    if (typeof secret !== 'string' || Buffer.byteLength(secret) < 32) {
      throw new TypeError('Player state secret must contain at least 32 bytes');
    }
    this.key = createHash('sha256').update(secret).digest();
  }

  encode(type, data, expiresAt) {
    const nonce = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, nonce);
    cipher.setAAD(Buffer.from(type));
    const encrypted = Buffer.concat([
      cipher.update(JSON.stringify({ type, data, expiresAt }), 'utf8'),
      cipher.final(),
    ]);
    const tag = cipher.getAuthTag();
    return [nonce, tag, encrypted].map((part) => part.toString('base64url')).join('.');
  }

  decode(token, type, now = Date.now()) {
    try {
      const [encodedNonce, encodedTag, encodedData, extra] = String(token).split('.');
      if (!encodedNonce || !encodedTag || !encodedData || extra !== undefined) return null;
      const nonce = Buffer.from(encodedNonce, 'base64url');
      const tag = Buffer.from(encodedTag, 'base64url');
      if (nonce.length !== 12 || tag.length !== 16) return null;

      const decipher = createDecipheriv('aes-256-gcm', this.key, nonce);
      decipher.setAAD(Buffer.from(type));
      decipher.setAuthTag(tag);
      const plaintext = Buffer.concat([
        decipher.update(Buffer.from(encodedData, 'base64url')),
        decipher.final(),
      ]).toString('utf8');
      const payload = JSON.parse(plaintext);
      if (payload.type !== type || !Number.isFinite(payload.expiresAt) || payload.expiresAt <= now) return null;
      return payload.data;
    } catch {
      return null;
    }
  }
}

function createStateTokenCodec(env = process.env) {
  if (env.VERCEL !== '1') return null;
  if (!env.PLAYER_STATE_SECRET) {
    throw new Error('PLAYER_STATE_SECRET must be set on Vercel to share playback state across function instances');
  }
  return new StateTokenCodec(env.PLAYER_STATE_SECRET);
}

module.exports = { StateTokenCodec, createStateTokenCodec };