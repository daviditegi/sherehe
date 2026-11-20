# Sherehe: go-live guide

Files: `index.html` (the whole site), `supabase/schema.sql` (database, security rules, storage).

## 1. Supabase (about 10 minutes)
1. Create a project at supabase.com.
2. **SQL Editor**: paste all of `supabase/schema.sql` and click Run.
3. **Authentication > Providers > Phone**: switch it on and connect an SMS provider (Twilio, MessageBird, Vonage or TextLocal). Real SMS to Kenyan numbers needs this.
   - To test for free first: on the same page, add **test phone numbers with fixed codes** (for example `254712345678=123456`). No SMS is sent.
4. **Project Settings > API**: copy the **Project URL** and the **anon public key**.
5. Open `index.html`, find `CFG` near the top of the script, and paste both values. The anon key is meant to be public. The security rules in the SQL protect the data.

## 2. GitHub + hosting
1. Create a GitHub repo and upload `index.html` and the `supabase` folder.
2. **Settings > Pages > Deploy from a branch > main / root**. Your site goes live at `https://YOURNAME.github.io/REPO/`.
   (Netlify or Vercel also work: connect the repo, no build settings needed.)

## 3. What is demo right now
| Feature | Now | Before real launch |
|---|---|---|
| M-Pesa KSh 20 | `demo_pay()` function unlocks the chat for free | Safaricom Daraja STK Push in a Supabase Edge Function. The M-Pesa callback inserts into `unlocks` using the service role. Then `drop function demo_pay`. |
| Selfie check | `demo_verify()` marks everyone verified | Face match and liveness (Smile ID, Veriff, AWS Rekognition) from an Edge Function that sets `verified`. Then `drop function demo_verify`. |

Important: while `demo_pay` and `demo_verify` exist, a technical user can call them directly. Remove them as soon as the real versions are in.

## 4. Before you share it widely
- Add Report and Block buttons, and an 18+ confirmation.
- Add a privacy policy and terms. Kenya's Data Protection Act applies: register with the ODPC if required.
- Set Supabase **Auth > Rate Limits** so SMS codes can't be abused.
