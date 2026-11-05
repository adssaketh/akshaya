// Run with: firebase emulators:exec --only firestore "npm test"  (from firebase/)
const { test, before, after, beforeEach } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  deleteDoc,
  writeBatch,
  serverTimestamp,
} = require('firebase/firestore');

const H = 'house-1';
const CODE = 'ABCD2345';
let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'akshaya-rules-test',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  // A household owned by "owner", with "member" in it and a valid invite code.
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'households', H), {
      id: H, name: 'Home', ownerId: 'owner', inviteCode: CODE, createdAt: 1,
    });
    await setDoc(doc(db, 'households', H, 'members', 'owner'), {
      userId: 'owner', displayName: 'Owner', role: 'owner', joinedAt: 1,
    });
    await setDoc(doc(db, 'households', H, 'members', 'member'), {
      userId: 'member', displayName: 'Member', role: 'member', inviteCode: CODE, joinedAt: 2,
    });
    await setDoc(doc(db, 'inviteCodes', CODE), { householdId: H, ownerId: 'owner' });
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

function entry(uid, over = {}) {
  return {
    id: 'e1', householdId: H, createdAt: 1, updatedAt: 2, updatedBy: uid, isDeleted: false,
    syncedAt: serverTimestamp(), listId: 'l1', name: 'Rice', quantity: 2, unit: 'kg',
    isChecked: false, addedReason: 'manual', priority: 'normal', recurrence: 'none',
    ...over,
  };
}

function batch(uid, over = {}) {
  return {
    id: 'b1', householdId: H, createdAt: 1, updatedAt: 2, updatedBy: uid, isDeleted: false,
    syncedAt: serverTimestamp(), itemId: 'i1', quantityBought: 5, quantityRemaining: 5,
    unit: 'kg', purchaseDate: '2026-01-01', storageLocation: 'pantry',
    ...over,
  };
}

function recipe(uid, over = {}) {
  return {
    id: 'r1', householdId: H, createdAt: 1, updatedAt: 2, updatedBy: uid, isDeleted: false,
    syncedAt: serverTimestamp(), title: 'Tomato rice', timeMinutes: 30, servings: 2,
    diet: 'veg', ingredientsJson: '[]', stepsJson: '[]', source: 'ai', savedAt: 1,
    ...over,
  };
}

test('members can save recipes; bad recipe documents are rejected', async () => {
  const ref = doc(as('member'), 'households', H, 'recipes', 'r1');
  await assertSucceeds(setDoc(ref, recipe('member')));
  await assertFails(setDoc(ref, recipe('member', { timeMinutes: '30' })));
  await assertFails(setDoc(ref, recipe('member', { ingredientsJson: 'x'.repeat(20001) })));
  await assertFails(setDoc(ref, recipe('owner')));
  await assertFails(setDoc(doc(as('stranger'), 'households', H, 'recipes', 'r1'), recipe('stranger')));
});

function mealPlan(uid, over = {}) {
  return {
    id: 'm1', householdId: H, createdAt: 1, updatedAt: 2, updatedBy: uid, isDeleted: false,
    syncedAt: serverTimestamp(), planDate: '2026-11-06', slot: 'dinner', title: 'Rajma Masala',
    recipeJson: '{}', leftoverItemId: null, isCooked: false, prepJson: null,
    ...over,
  };
}

test('members can plan meals; bad meal plan documents are rejected', async () => {
  const ref = doc(as('member'), 'households', H, 'mealPlan', 'm1');
  await assertSucceeds(setDoc(ref, mealPlan('member')));
  await assertSucceeds(setDoc(ref, mealPlan('member', { recipeJson: null, title: 'Outside' })));
  await assertFails(setDoc(ref, mealPlan('member', { isCooked: 'no' })));
  await assertFails(setDoc(ref, mealPlan('member', { planDate: '2026-11-06T00:00:00' })));
  await assertFails(setDoc(ref, mealPlan('member', { recipeJson: 'x'.repeat(20001) })));
  await assertFails(setDoc(ref, mealPlan('member', { prepJson: 'x'.repeat(4001) })));
  await assertFails(setDoc(ref, mealPlan('owner')));
  await assertFails(setDoc(doc(as('stranger'), 'households', H, 'mealPlan', 'm1'), mealPlan('stranger')));
});

function trip(uid, over = {}) {
  return {
    id: 't1', householdId: H, createdAt: 1, updatedAt: 2, updatedBy: uid, isDeleted: false,
    syncedAt: serverTimestamp(), name: 'Goa', startDate: '2026-11-10', endDate: '2026-11-15',
    pauseRecurring: true, pauseAlerts: true, essentialsJson: '[]', essentialsAdded: false,
    ...over,
  };
}

test('members can save trips; bad trip documents are rejected', async () => {
  const ref = doc(as('member'), 'households', H, 'trips', 't1');
  await assertSucceeds(setDoc(ref, trip('member')));
  await assertSucceeds(setDoc(ref, trip('member', { name: '', essentialsJson: null })));
  await assertFails(setDoc(ref, trip('member', { pauseAlerts: 'yes' })));
  await assertFails(setDoc(ref, trip('member', { startDate: '2026-11-10T00:00:00' })));
  await assertFails(setDoc(ref, trip('member', { name: 'x'.repeat(81) })));
  await assertFails(setDoc(ref, trip('member', { essentialsJson: 'x'.repeat(4001) })));
  await assertFails(setDoc(ref, trip('owner')));
  await assertFails(setDoc(doc(as('stranger'), 'households', H, 'trips', 't1'), trip('stranger')));
});

test('a non-member cannot read or write household data', async () => {
  const db = as('stranger');
  await assertFails(getDoc(doc(db, 'households', H, 'entries', 'e1')));
  await assertFails(setDoc(doc(db, 'households', H, 'entries', 'e1'), entry('stranger')));
  await assertFails(getDoc(doc(db, 'households', H)));
});

test('a signed-out client cannot do anything', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(doc(db, 'households', H, 'entries', 'e1')));
  await assertFails(getDoc(doc(db, 'inviteCodes', CODE)));
});

test('a member can write and read a valid entry', async () => {
  const db = as('member');
  await assertSucceeds(setDoc(doc(db, 'households', H, 'entries', 'e1'), entry('member')));
  await assertSucceeds(getDoc(doc(db, 'households', H, 'entries', 'e1')));
});

test('updatedBy must be the signed-in user', async () => {
  const db = as('member');
  await assertFails(setDoc(doc(db, 'households', H, 'entries', 'e1'), entry('owner')));
});

test('syncedAt must be the server time', async () => {
  const db = as('member');
  await assertFails(
    setDoc(doc(db, 'households', H, 'entries', 'e1'), entry('member', { syncedAt: 123 })),
  );
});

test('wrong id, household or types are rejected', async () => {
  const db = as('member');
  const ref = doc(db, 'households', H, 'entries', 'e1');
  await assertFails(setDoc(ref, entry('member', { id: 'other' })));
  await assertFails(setDoc(ref, entry('member', { householdId: 'elsewhere' })));
  await assertFails(setDoc(ref, entry('member', { quantity: 'two' })));
  await assertFails(setDoc(ref, entry('member', { isChecked: 'no' })));
  await assertFails(setDoc(ref, entry('member', { updatedAt: '2' })));
});

test('batch remaining quantity cannot be negative', async () => {
  const db = as('member');
  const ref = doc(db, 'households', H, 'batches', 'b1');
  await assertSucceeds(setDoc(ref, batch('member')));
  await assertFails(setDoc(ref, batch('member', { quantityRemaining: -1 })));
});

test('only soft-deleted documents can be purged', async () => {
  const db = as('member');
  const ref = doc(db, 'households', H, 'entries', 'e1');
  await assertSucceeds(setDoc(ref, entry('member')));
  await assertFails(deleteDoc(ref));
  await assertSucceeds(setDoc(ref, entry('member', { isDeleted: true })));
  await assertSucceeds(deleteDoc(ref));
});

test('a new member can join with a valid invite code', async () => {
  const db = as('newbie');
  const b = writeBatch(db);
  b.set(doc(db, 'households', H, 'members', 'newbie'), {
    userId: 'newbie', displayName: 'New', role: 'member', inviteCode: CODE, joinedAt: 3,
  });
  b.set(doc(db, 'users', 'newbie'), { householdId: H });
  await assertSucceeds(b.commit());
  await assertSucceeds(getDoc(doc(db, 'households', H)));
});

test('joining with a wrong or other household code is denied', async () => {
  const db = as('newbie');
  await assertFails(
    setDoc(doc(db, 'households', H, 'members', 'newbie'), {
      userId: 'newbie', displayName: 'New', role: 'member', inviteCode: 'ZZZZ9999', joinedAt: 3,
    }),
  );
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'inviteCodes', 'OTHER234'), {
      householdId: 'house-2', ownerId: 'someone',
    });
  });
  await assertFails(
    setDoc(doc(db, 'households', H, 'members', 'newbie'), {
      userId: 'newbie', displayName: 'New', role: 'member', inviteCode: 'OTHER234', joinedAt: 3,
    }),
  );
});

test('nobody can join as owner or on behalf of someone else', async () => {
  const db = as('newbie');
  await assertFails(
    setDoc(doc(db, 'households', H, 'members', 'newbie'), {
      userId: 'newbie', displayName: 'New', role: 'owner', joinedAt: 3,
    }),
  );
  await assertFails(
    setDoc(doc(db, 'households', H, 'members', 'someoneelse'), {
      userId: 'someoneelse', displayName: 'X', role: 'member', inviteCode: CODE, joinedAt: 3,
    }),
  );
});

test('creating a household in one batch works for its owner', async () => {
  const db = as('founder');
  const b = writeBatch(db);
  b.set(doc(db, 'households', 'h2'), {
    id: 'h2', name: 'Flat', ownerId: 'founder', inviteCode: 'WXYZ6789', createdAt: 5,
  });
  b.set(doc(db, 'households', 'h2', 'members', 'founder'), {
    userId: 'founder', displayName: 'Founder', role: 'owner', joinedAt: 5,
  });
  b.set(doc(db, 'inviteCodes', 'WXYZ6789'), { householdId: 'h2', ownerId: 'founder' });
  b.set(doc(db, 'users', 'founder'), { householdId: 'h2' });
  await assertSucceeds(b.commit());
});

test('a household cannot be created in someone else\'s name', async () => {
  const db = as('mallory');
  await assertFails(
    setDoc(doc(db, 'households', 'h3'), {
      id: 'h3', name: 'Mine', ownerId: 'owner', inviteCode: 'WXYZ6789', createdAt: 5,
    }),
  );
});

test('the owner can remove a member; a member cannot remove others', async () => {
  await assertFails(deleteDoc(doc(as('member'), 'households', H, 'members', 'owner')));
  await assertSucceeds(deleteDoc(doc(as('owner'), 'households', H, 'members', 'member')));
  await assertFails(getDoc(doc(as('member'), 'households', H, 'entries', 'e1')));
});

test('a member can leave but the owner cannot', async () => {
  await assertFails(deleteDoc(doc(as('owner'), 'households', H, 'members', 'owner')));
  await assertSucceeds(deleteDoc(doc(as('member'), 'households', H, 'members', 'member')));
});

test('only the owner can replace the invite code', async () => {
  const code = 'NEWC2345';
  const ownerDb = as('owner');
  const b = writeBatch(ownerDb);
  b.update(doc(ownerDb, 'households', H), { inviteCode: code });
  b.delete(doc(ownerDb, 'inviteCodes', CODE));
  b.set(doc(ownerDb, 'inviteCodes', code), { householdId: H, ownerId: 'owner' });
  await assertSucceeds(b.commit());

  const memberDb = as('member');
  await assertFails(
    setDoc(doc(memberDb, 'households', H), {
      id: H, name: 'Home', ownerId: 'owner', inviteCode: 'HACK2345', createdAt: 1,
    }),
  );
});

test('the account pointer is private to its owner', async () => {
  await assertSucceeds(setDoc(doc(as('member'), 'users', 'member'), { householdId: H }));
  await assertFails(getDoc(doc(as('owner'), 'users', 'member')));
  await assertFails(setDoc(doc(as('owner'), 'users', 'member'), { householdId: 'x' }));
});
