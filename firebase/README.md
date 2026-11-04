# Firestore rules tests

Needs Node 20+, Java 17+ and the Firebase CLI (`npm i -g firebase-tools`).

```
cd firebase
npm install
firebase emulators:exec --only firestore --project akshaya-rules-test "npm test"
```

`firebase.json` at the repo root points the emulator at `../firestore.rules`.
