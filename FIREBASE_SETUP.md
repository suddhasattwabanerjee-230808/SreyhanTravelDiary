# Set up diary sync

This diary uses its **own Firebase project**. Do not select the TripSplit
project. TripSplit's Firebase and Cloudflare setup stays separate.

## Do these steps

1. In the [Firebase console](https://console.firebase.google.com/), create a new
   project named **Sreyhan Travel Diary**.
2. In that new project, add an **Android app** with package name
   `com.bittu.sreyhan_diary`. Download its `google-services.json` file and put
   it here: `android/app/google-services.json`.
3. Add the Android signing fingerprints in Project settings → General → Your
   apps → `com.bittu.sreyhan_diary` → SHA certificate fingerprints:

   - SHA-1: `32:31:9A:34:CA:FF:D6:59:45:70:C3:6E:AD:E2:BC:52:2F:EC:EE:A5`
   - SHA-256: `A6:12:28:86:A4:ED:FB:B6:E7:41:DD:33:BE:81:D1:19:7F:49:13:64:64:22:18:B3:39:0D:9F:7F:65:E3:B2:F4`

4. In Authentication → Sign-in providers, turn on **Phone** and save. In
   Authentication → Settings → SMS region policy, allow the country code for
   the phone that will receive the codes (India for a `+91` number). The number
   itself is entered in the app; the optional test-number field is only for
   Firebase test numbers.
5. Create a Firestore database and a Storage bucket.
6. Install the Firebase command line tool, sign in, and deploy this app's rules
   from the diary project folder:

   ```sh
   npm install -g firebase-tools
   firebase login
   firebase deploy --only firestore:rules,storage
   ```

   This folder is already set to project `sreyhan-travel-diary-20816`.
7. Build and install the updated app on all three phones. In the grown-ups'
   corner, enter the same phone number on every phone and verify each with the
   SMS code. The first verification creates the diary account. Select which
   existing entries to add on each phone; new entries then sync automatically.

**Storage billing:** Firebase requires the new project to use the Blaze billing
plan for Cloud Storage. Check this before creating the bucket. If you do not
want to enable billing, stop after step 2 and tell me; I can change photo sync
to use Cloudflare R2 instead. [Firebase's Storage billing details](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).
