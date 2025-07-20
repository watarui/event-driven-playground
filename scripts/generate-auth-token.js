#!/usr/bin/env node

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = {
  "type": "service_account",
  "project_id": "event-driven-playground-prod",
  "private_key_id": "YOUR_PRIVATE_KEY_ID",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEuwIBADANBgkqhkiG9w0BAQEFAASCBKUwggShAgEAAoIBAQDDXqJeU50vKaFl\nyFx3Nng0SOsEFwcdUzFRlhbe6t38m+9KC2hr5m+TLGHqOE5sOTPaeRp63WJ4qVjk\nxvA17V/Ih3r0YESPfxz8vAewI2wq8WhaAQ5yFtSvGnp+NH818fz3AayfLSHf5UIS\nHi8UOfwE5qChOTwKedrNwKkklXqWr1poVQjZPzTRGdsoyMNSM0+r/WOfSZmRq78y\n8LnZbBeb8zqz7uW4/oGhR8x5tC/3YruDHXcP2H0z3SmSsESxPQ1SpVx3e+ZpiwBm\nSwV2Dcw0AJqticAI/35ZAowH1TrwNIH/VMPEQc6oQJmG1tFXztUob2IIzLqSnlLT\niDf4NuLrAgMBAAECgf8YCZ3MOHIOlFmBV6hvNJCyC6v4+mYEaf3xZJcnhXe6sWBs\npQ8om5SYheaHVvfSBMg7fU7W9Ky2Cbmfr3m38R5hg5qYpDedxq1C9h9IQ939hezk\n1B26AE8lE0Ofa2Ds+EZYexv4tOSBdaTeo3UZxf+BcwoJ5lCBZGqOPc1lczMjxmOd\nXS7Ly42dCMeG+5nbury80qO5qkfk8C0KIw7NWXTOK4ETB+ZytWGo14vLkxcWU02s\nIYz4h4rrAz7ErYrQhqZ8R6PGdkJmD5bKmHzF0fJQKXYKdGd3V3FG3+vsugmcURlE\nAiRyHQ+3dAUPRUP+mCS5DRjK003bMJXeyg9MXnkCgYEA6TIZKAdlja9kPNT7/m0b\n5iSb8Kbz4gKGl6FlHgp+fOS7Xzldmd4jWcHHI6I5ha8F0C1mV4xteKduB/lCg32Z\nLHxZ7yJqwbBxqMUSWoMHKjF/ctD0M+Yu3sAArui8sbtXgMLinpoJ6ncs3U+9+364\nxPczRoid4gSh6mvJvmta1g0CgYEA1nmWBit4B2af5R1YYyyjK4DqCIq4EK2Dlf6x\nbolC2SQ9UxTnp8uT5hCL/hPVpmKRzn2s90aWM3us1qfRBiqrTD6bG2RsXEGai0Hf\nx741Rdy0n3oBAdobojF3kEH1epSiSMr7Yanj+ZWKoCuGrV4bn+kbHKos1YsXagMh\nsaioFtcCgYEAwkeCvd6rtMcS87td1jKAs9R8NpphRUJlb55+5/BGQTcvA75/RNnV\nCcpvZjiZQ871QOMSCI5uBb835Fy+FV5mZrGTG6/I0WV2y+yjxdSz+2sRi06apUJ4\negvshcxQqKIz3IqA0zHyYOy47AirdwO0XCS3C2R2ZP8HBo6WnZZDL2ECgYAkGzn3\nde/yBwPaFXOg1o3tr/k2UOwl2qAxazxBqJf5aFFuoDFTnUEb1SNMNdic9zEmux+Y\nTWjR5/sz8/KLgDlwT4XbOa/IZD75PLDItqvPRBWgV3C9+BL43i0Lux7xcP5VFN73\nFRvNE7DPwCQfIZ2y8RJgZAHCPXVGoppUh1ks5wKBgGybDMaXzXahCnkdi2vnUwq/\nbFUn1Ikn6c5JC5XWt++/cpq5J3dR75Q79kZ27jceEZrN76dnjRZAmljPkNZSpUW1\nUTO6mFwRxhQWiMI11Ijwefb+l/ox4U1p48O2zwAJ7EX+B/VF2dOhQwMLbqZ7hVz3\nepjoH/k7PI6fKFj0+7Fp\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-fbsvc@event-driven-playground-prod.iam.gserviceaccount.com",
  "client_id": "YOUR_CLIENT_ID",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "YOUR_CERT_URL"
};

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function createCustomToken() {
  try {
    const uid = 'test-user-123';
    const customClaims = {
      email: 'test@example.com',
      role: 'admin'
    };
    
    const customToken = await admin.auth().createCustomToken(uid, customClaims);
    console.log('Custom token created:');
    console.log(customToken);
    
    // Also create a user if doesn't exist
    try {
      await admin.auth().createUser({
        uid: uid,
        email: customClaims.email,
        emailVerified: true,
        displayName: 'Test User'
      });
      console.log('User created');
    } catch (error) {
      if (error.code === 'auth/uid-already-exists') {
        console.log('User already exists');
      } else {
        throw error;
      }
    }
    
  } catch (error) {
    console.error('Error creating custom token:', error);
  }
  
  process.exit(0);
}

createCustomToken();