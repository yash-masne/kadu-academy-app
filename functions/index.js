// index.js - Firebase Cloud Functions
// This file contains all Cloud Functions for managing tests and users.
// UPDATED to support targeted notifications for scheduled and published tests.

// Import the required modules from Firebase
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const admin = require('firebase-admin');

// Initialize Firebase Admin SDK if it hasn't been already.
if (!admin.apps.length) {
    admin.initializeApp();
}

const firestore = admin.firestore();

// ====================================================================
// NEW: Helper function for consistent date formatting
// ====================================================================
function formatDateTimeIST(timestamp) {
    if (!timestamp) return 'N/A';

    // FIX: Check if the input is a Timestamp object, a Date object, or a string
    let date;
    if (timestamp instanceof admin.firestore.Timestamp) {
        date = timestamp.toDate();
    } else if (timestamp instanceof Date) {
        date = timestamp;
    } else if (typeof timestamp === 'string') {
        date = new Date(timestamp);
    } else {
        return 'N/A';
    }

    const options = {
        timeZone: 'Asia/Kolkata',
        day: '2-digit',
        month: 'short',
        year: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        hour12: true
    };
    
    // Format the date
    const formatter = new Intl.DateTimeFormat('en-IN', options);
    let formattedString = formatter.format(date);
    
    // Remove the comma and ensure AM/PM is uppercase
    formattedString = formattedString.replace(',', '').toUpperCase();
    return formattedString;
}
// ====================================================================


/**
 * Helper function to send notifications to a targeted audience.
 * This is now a generic function that can be used by multiple parts of the code.
 * @param {object} testData - The data of the test being published/scheduled.
 * @param {string} testId - The ID of the test.
 * @param {string} notificationTitle - The title of the notification.
 * @param {string} notificationBody - The body text of the notification.
 * @param {string} notificationType - The type of notification (e.g., 'new_published', 'new_scheduled').
 */
async function sendTargetedNotifications(testData, testId, notificationTitle, notificationBody, notificationType) {
    const isFreeTest = testData.isFree ?? false;
    const isPaidCollege = testData.isPaidCollege ?? false;
    const isPaidKaduAcademy = testData.isPaidKaduAcademy ?? false;
    const allowedBranches = testData.allowedBranches ?? [];
    const allowedYears = testData.allowedYears ?? [];
    const allowedCourses = testData.allowedCourses ?? [];

    let usersQuery = firestore.collection('users').where('isDenied', '==', false);

    // Filter users based on test eligibility
    if (isPaidCollege) {
        usersQuery = usersQuery.where('studentType', '==', 'college');
        // If specific branches/years are set, filter by those
        if (allowedBranches.length > 0) {
            usersQuery = usersQuery.where('branches', 'array-contains-any', allowedBranches);
        }
        if (allowedYears.length > 0) {
            usersQuery = usersQuery.where('years', 'array-contains-any', allowedYears);
        }
    } else if (isPaidKaduAcademy) {
        usersQuery = usersQuery.where('studentType', '==', 'kadu_academy');
        // If specific courses are set, filter by those
        if (allowedCourses.length > 0) {
            usersQuery = usersQuery.where('courses', 'array-contains-any', allowedCourses);
        }
    } else if (isFreeTest) {
        // Free tests go to everyone, including unapproved/unregistered users
        // We will target all users, but exclude those who are approved for paid plans to respect app logic
        const collegeApproved = firestore.collection('users').where('studentType', '==', 'college').where('isApprovedByAdminCollegeStudent', '==', true);
        const kaduApproved = firestore.collection('users').where('studentType', '==', 'kadu_academy').where('isApprovedByAdminKaduAcademy', '==', true);
        const [collegeSnap, kaduSnap] = await Promise.all([collegeApproved.get(), kaduApproved.get()]);

        const excludedUids = [...collegeSnap.docs.map(doc => doc.id), ...kaduSnap.docs.map(doc => doc.id)];
        if (excludedUids.length > 0) {
          // This is a complex query that Firestore cannot do directly. A simpler approach is to get all users
          // and filter them in the function, or send to all and let client handle it.
          // For now, let's keep it simple and just query for general users.
        }
        // Let's stick with the original logic from your frontend: Free tests are for non-paid users.
        // We'll broaden the audience to `isRegistered == false` as per your app's rules.
        usersQuery = firestore.collection('users').where('isRegistered', '==', false);
        
    } else {
        // If it's none of the above, don't send any notifications.
        console.log(`Test ${testId} has no target audience defined. Skipping notifications.`);
        return;
    }

    try {
        const usersSnapshot = await usersQuery.get();
        if (usersSnapshot.empty) {
            console.log(`No users found for notification for test ${testId}.`);
            return;
        }

        const tokens = [];
        usersSnapshot.docs.forEach(doc => {
            const token = doc.data().fcmToken;
            if (token) {
                tokens.push(token);
            }
        });

        if (tokens.length > 0) {
            const message = {
                notification: {
                    title: notificationTitle,
                    body: notificationBody,
                },
                data: {
                    testId: testId,
                    testTitle: testData.title,
                    type: notificationType, // Use the dynamic type parameter
                },
                tokens: tokens,
            };

            const response = await admin.messaging().sendEachForMulticast(message);
            console.log(`Successfully sent ${response.successCount} new test notifications for test ${testId}. Failures: ${response.failureCount}`);
        } else {
            console.log(`No valid FCM tokens found for notification for test ${testId}.`);
        }
    } catch (error) {
        console.error(`Error sending targeted notifications for test ${testId}:`, error);
        throw error;
    }
}


/**
 * NEW: Triggered when a new test document is created.
 * Sends an immediate notification if the test is either published or scheduled.
 */
exports.onNewTestCreated = onDocumentCreated('tests/{testId}', async (event) => {
    const testData = event.data.data();
    const testId = event.params.testId;

    if (testData.isPublished) {
        // Case 1: Test is published immediately upon creation
        console.log(`New test "${testData.title}" published immediately. Sending notifications.`);
        await sendTargetedNotifications(
            testData,
            testId,
            'New Test Published!',
            `The test "${testData.title}" is now available.`,
            'newly_published'
        );
    } else if (testData.scheduledPublishTime) {
        // Case 2: Test is scheduled for a future time
        const scheduledTime = formatDateTimeIST(testData.scheduledPublishTime); // MODIFIED
        console.log(`New test "${testData.title}" scheduled. Sending notification.`);
        await sendTargetedNotifications(
            testData,
            testId,
            'New Test Scheduled!',
            `The test "${testData.title}" is scheduled to be released on ${scheduledTime}.`,
            'newly_scheduled'
        );
    } else {
        // Case 3: Test is a draft, no notification needed.
        console.log(`New test "${testData.title}" is a draft. No notification sent.`);
    }
    return null;
});


/**
 * NEW: Triggered when an existing test document is updated.
 * Specifically checks for a change in 'isPublished' status from false to true.
 * This handles cases where a draft test is manually published by the admin.
 */
exports.onTestPublished = onDocumentUpdated('tests/{testId}', async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const testId = event.params.testId;

    // Check if the test was previously not published and is now published.
    // This handles the "Publish Now" button on the Admin panel.
    if (!beforeData.isPublished && afterData.isPublished) {
        console.log(`Test "${afterData.title}" manually published. Sending notifications.`);
        await sendTargetedNotifications(
            afterData,
            testId,
            'New Test Published!',
            `The test "${afterData.title}" is now available.`,
            'newly_published'
        );
    }

    return null;
});


/**
 * A scheduled function that runs every 5 minutes to automatically
 * publish tests whose scheduled time has passed and archive tests
 * whose global expiry time has passed. This updated version also sends
 * an FCM notification when a test is published.
 * * NOTE: The notification logic for scheduled tests becoming published
 * is already correct here and is preserved.
 */
exports.publishAndExpireTests = onSchedule('every 5 minutes', async (context) => {
    const now = admin.firestore.Timestamp.now();
    const batch = firestore.batch();
    let publishedCount = 0;
    let expiredCount = 0;
    const newlyPublishedTests = [];

    // --- 1. Logic for PUBLISHING tests ---
    try {
        const testsToPublishSnapshot = await firestore.collection('tests')
            .where('isPublished', '==', false)
            .where('scheduledPublishTime', '<=', now)
            .where('isArchived', '==', false)
            .get();

        if (!testsToPublishSnapshot.empty) {
            testsToPublishSnapshot.docs.forEach(doc => {
                const docData = doc.data();
                // Check if the test is already globally expired before publishing
                if (docData.globalExpiryTime && now.toDate() > docData.globalExpiryTime.toDate()) {
                    console.log(`SKIPPING PUBLISH: Test ${doc.id} is due to publish but has already globally expired. Marking as archived instead.`);
                    batch.update(doc.ref, {
                        isPublished: false,
                        isArchived: true,
                        updatedAt: now
                    });
                    expiredCount++;
                } else {
                    console.log(`Publishing test: ${doc.id} - "${docData.title}"`);
                    batch.update(doc.ref, {
                        isPublished: true,
                        publishTime: now,
                        scheduledPublishTime: null, // Clear the scheduled time
                        updatedAt: now
                    });
                    publishedCount++;
                    newlyPublishedTests.push({ id: doc.id, data: docData });
                }
            });
        }
    } catch (error) {
        console.error('Error querying for tests to publish:', error);
    }

    // --- 2. Logic for EXPIRING/ARCHIVING tests ---
    try {
        const testsToExpireSnapshot = await firestore.collection('tests')
            .where('isPublished', '==', true)
            .where('globalExpiryTime', '<=', now)
            .where('isArchived', '==', false)
            .get();

        if (!testsToExpireSnapshot.empty) {
            testsToExpireSnapshot.docs.forEach(doc => {
                console.log(`Expiring/Archiving test: ${doc.id} - "${doc.data().title}"`);
                batch.update(doc.ref, {
                    isPublished: false, // Make it not published
                    isArchived: true,    // Mark as archived
                    updatedAt: now
                });
                expiredCount++;
            });
        }
    } catch (error) {
        console.error('Error querying for tests to expire:', error);
    }

    // --- Commit all gathered updates if there are any changes ---
    if (publishedCount > 0 || expiredCount > 0) {
        try {
            await batch.commit();
            console.log(`Batch commit successful. Published ${publishedCount} test(s), Expired/Archived ${expiredCount} test(s).`);

            // --- NEW: Send targeted notifications for newly published tests ---
            if (newlyPublishedTests.length > 0) {
                for (const test of newlyPublishedTests) {
                    await sendTargetedNotifications(
                        test.data,
                        test.id,
                        'Test is now live!', // Changed title to be more specific
                        `The scheduled test "${test.data.title}" is now available. Good luck!`,
                        'scheduled_to_published' // New notification type
                    );
                }
            }
        } catch (error) {
            console.error('Error committing batch updates or sending notifications:', error);
            // Re-throw the error to indicate function failure
            throw new Error('Failed to commit batch updates for scheduled tests.');
        }
    } else {
        console.log('No tests to publish or expire at this time.');
    }
});


/**
 * An HTTP callable function that an admin can use to manually
 * trigger a notification for a newly scheduled test.
 * This is a more precise approach than relying on the scheduled
 * publish function for the first notification.
 */
exports.sendScheduledTestNotification = onCall(async (request) => {
    // 1. Authenticate Caller: Ensure the request is made by an authenticated user.
    if (!request.auth || !request.auth.uid) {
        console.warn('Callable function "sendScheduledTestNotification" called by unauthenticated user.');
        throw new HttpsError(
            'unauthenticated',
            'You must be logged in to access this function.'
        );
    }

    const { testId, testTitle, scheduledTime } = request.data;
    const scheduledTimeFormatted = formatDateTimeIST(new Date(scheduledTime)); // MODIFIED

    // 2. Validate Input
    if (!testId || !testTitle || !scheduledTime) {
        throw new HttpsError('invalid-argument', 'Missing testId, testTitle, or scheduledTime.');
    }

    // 3. Authorize Caller: Verify if the authenticated user is an administrator.
    try {
        const callerUserDoc = await firestore.collection('users').doc(request.auth.uid).get();
        if (!callerUserDoc.exists || callerUserDoc.data().isAdmin !== true) {
            console.warn(`Non-admin user ${request.auth.uid} attempted to send a scheduled test notification.`);
            throw new HttpsError('permission-denied', 'Only administrators are authorized.');
        }
    } catch (error) {
        console.error(`Error verifying admin status for user ${request.auth.uid}:`, error);
        throw new HttpsError('internal', 'Failed to verify admin privileges.');
    }

    // 4. Fetch test data to get audience info
    const testDoc = await firestore.collection('tests').doc(testId).get();
    if (!testDoc.exists) {
        throw new HttpsError('not-found', 'Test not found.');
    }
    const testData = testDoc.data();

    const notificationBody = `The test "${testTitle}" has been scheduled for ${scheduledTimeFormatted}.`;
    
    // 5. Send targeted notifications
    await sendTargetedNotifications(
        testData,
        testId,
        'Upcoming Test Scheduled!',
        notificationBody,
        'newly_scheduled' // Changed notification type to be specific
    );

    return { success: true, message: `Scheduled test notifications sent for test ${testId}.` };
});


// ====================================================================
// FUNCTIONS FOR USER MANAGEMENT
// ====================================================================

/**
 * An HTTP callable function for an admin to delete a specific user and their data.
 * This function handles the deletion of the user's Firebase Authentication account
 * and their corresponding Firestore profile. It includes robust security checks.
 *
 * It takes a single argument:
 * @param {string} data.uid - The ID of the user document to delete.
 */
exports.deleteUserAccount = onCall(async (request) => {
    // 1. Authenticate Caller: Ensure the request is made by an authenticated user.
    if (!request.auth || !request.auth.uid) {
        console.warn('Callable function "deleteUserAccount" called by unauthenticated user.');
        throw new HttpsError(
            'unauthenticated',
            'You must be logged in to access this function.'
        );
    }

    const callerUid = request.auth.uid;
    const targetUid = request.data.uid;

    // 2. Validate Input: Ensure the target user ID is provided.
    if (!targetUid || typeof targetUid !== 'string') {
        console.error(`Callable function "deleteUserAccount" received invalid argument: target UID is missing. Caller UID: ${callerUid}`);
        throw new HttpsError(
            'invalid-argument',
            'The target user ID to delete is missing.'
        );
    }

    // 3. Authorize Caller: Verify if the authenticated user is an administrator.
    try {
        const callerUserDoc = await firestore.collection('users').doc(callerUid).get();
        if (!callerUserDoc.exists || callerUserDoc.data().isAdmin !== true) {
            console.warn(`Non-admin user ${callerUid} attempted to delete user ${targetUid}. Access denied.`);
            throw new HttpsError('permission-denied', 'Only administrators are authorized.');
        }
    } catch (error) {
        console.error(`Error verifying admin status for user ${callerUid}:`, error);
        throw new HttpsError('internal', 'Failed to verify admin privileges.');
    }

    // 4. Perform User Deletion: Delete the user from Firebase Auth and Firestore.
    try {
        await admin.auth().deleteUser(targetUid);
        console.info(`Successfully deleted user from Firebase Authentication: ${targetUid}`);

        // Delete the user's Firestore profile document
        await firestore.collection('users').doc(targetUid).delete();
        console.info(`Successfully deleted user profile document from Firestore: ${targetUid}`);

        // NOTE: If you have other user-related data in other collections
        // (e.g., student results), you should add the deletion logic here.
        // This ensures a complete and clean deletion of all user data.
        
        return { success: true, message: `User ${targetUid} deleted successfully.` };

    } catch (error) {
        console.error(`Error during user deletion process for user ${targetUid}:`, error);
        if (error.code === 'auth/user-not-found') {
            throw new HttpsError(
                'not-found',
                'The specified user does not exist in Firebase Authentication.'
            );
        }
        throw new HttpsError(
            'internal',
            `Failed to delete user account due to an internal error: ${error.message || 'Unknown error'}`
        );
    }
});