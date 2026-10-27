# Set up diary sync

This diary uses its **own Firebase project**. Do not select the TripSplit
project. TripSplit's Firebase and Cloudflare setup stays separate.

## Do these steps

1. In the [Firebase console](https://console.firebase.google.com/), create a new
   project named **Sreyhan Travel Diary**.
2. In that new project, add an **Android app** with package name
   `com.bittu.sreyhan_diary`. Download its `google-services.json` file and put
   it here: `android/app/google-services.json`.
3. In the new project, enable **Email/Password** under Authentication →
   Sign-in method. Create a Firestore database and a Storage bucket.
4. Install the Firebase command line tool, sign in, and choose the new diary
   project from this folder:

   ```sh
   npm install -g firebase-tools
   firebase login
   firebase use --add
   firebase deploy --only firestore:rules,storage
   ```

   When asked, select **Sreyhan Travel Diary**, not TripSplit.
5. Build and install the app on all three phones. In the grown-ups' corner,
   create the account on one phone. Use that same email and password on the
   other two. On each phone, select which existing entries to add. The selected
   entries and their photos merge into the shared diary; new entries then sync
   automatically.

**Storage billing:** Firebase requires the new project to use the Blaze billing
plan for Cloud Storage. Check this before creating the bucket. If you do not
want to enable billing, stop after step 2 and tell me; I can change photo sync
to use Cloudflare R2 instead. [Firebase's Storage billing details](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024).
