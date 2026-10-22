# Sheru's coach

A [Cloudflare Worker](https://workers.cloudflare.com/) (free plan) that lets
the diary app use Claude without the API key ever being inside the APK. The
app sends it the photo (shrunk) and what the child said; it asks Claude
(`claude-haiku-5-5`) and sends back:

- **ask**: a cheerful reaction and 2-3 questions about the photo,
- **polish**: the Super Sentence (1-3 diary sentences) and its new words,
- **bridge**: the English for a Gujarati or Hindi word.

Requests without the right `APP_TOKEN` are refused. If the Worker is down, the
app carries on offline with Sheru's own questions.

## Deploy

1. console.anthropic.com → **API keys** → **Create key**. Also set a monthly
   **spend limit** for the workspace under **Limits**: that's the real cap.
   Each moment costs well under a rupee.
2. dash.cloudflare.com → **Workers & Pages** → **Create** → **Create Worker** →
   name it `sreyhan-coach` → **Deploy** → **Edit code** → replace everything
   with `worker.js` → **Deploy**.
3. The Worker → **Settings** → **Variables and Secrets** → add two of type
   **Secret**: `ANTHROPIC_API_KEY` (the key from step 1) and `APP_TOKEN` (any
   long random string) → **Deploy**.
4. GitHub → the repo → **Settings** → **Secrets and variables** → **Actions** →
   **New repository secret**, twice: `COACH_URL` = the Worker's URL
   (`https://sreyhan-coach.<you>.workers.dev`) and `COACH_TOKEN` = the same
   string as `APP_TOKEN`. The next build has the coach built in.

Opening the URL in a browser shows `Sheru's coach`.

## Test

    node coach-worker/test.mjs
