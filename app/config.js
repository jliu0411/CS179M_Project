// Appwrite Configuration
// Get these values from your Appwrite Console: https://cloud.appwrite.io

export const APPWRITE_CONFIG = {
  endpoint: 'https://sfo.cloud.appwrite.io/v1',  // San Francisco region
  projectId: '699f63e60001708923ba',              // Your Project ID
  databaseId: 'main',
  collectionId: 'results',
  bucketId: 'ply-files',
  functionId: 'process-ply'
};

// You can also use environment variables if preferred:
// export const APPWRITE_CONFIG = {
//   endpoint: process.env.EXPO_PUBLIC_APPWRITE_ENDPOINT,
//   projectId: process.env.EXPO_PUBLIC_APPWRITE_PROJECT_ID,
//   ...
// };
