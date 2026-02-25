import { Client, Storage, Databases, Functions, ID, Query } from 'react-native-appwrite';
import { APPWRITE_CONFIG } from '../config';

/**
 * Appwrite Service for PLY file processing
 * Handles file uploads, processing, and result retrieval
 */
class AppwriteService {
  constructor() {
    this.client = new Client();
    this.client
      .setEndpoint(APPWRITE_CONFIG.endpoint)
      .setProject(APPWRITE_CONFIG.projectId);
    
    this.storage = new Storage(this.client);
    this.databases = new Databases(this.client);
    this.functions = new Functions(this.client);
  }

  /**
   * Check if Appwrite services are accessible
   */
  async checkHealth() {
    try {
      // Try to list buckets to verify connection
      await this.storage.listBuckets();
      return { status: 'ok', message: 'Connected to Appwrite' };
    } catch (error) {
      throw new Error('Unable to connect to Appwrite. Check your configuration.');
    }
  }

  /**
   * Get available processing methods
   */
  async getMethods() {
    return [
      { value: 'AABB', label: 'Axis-Aligned Bounding Box' },
      { value: 'OBB', label: 'Oriented Bounding Box' },
      { value: 'PCA', label: 'Principal Component Analysis' }
    ];
  }

  /**
   * Upload PLY file to Appwrite Storage and process it
   * @param {Object} file - File object with uri, name, type
   * @param {string} method - Processing method (AABB, OBB, or PCA)
   * @param {function} onProgress - Progress callback function
   */
  async uploadPlyFile(file, method = 'AABB', onProgress = null) {
    try {
      // Step 1: Upload file to Appwrite Storage
      if (onProgress) onProgress(10);
      
      const uploadedFile = await this.storage.createFile(
        APPWRITE_CONFIG.bucketId,
        ID.unique(),
        {
          uri: file.uri,
          name: file.name,
          type: file.mimeType || 'application/octet-stream'
        }
      );

      if (onProgress) onProgress(30);

      // Step 2: Create a result document in database
      const resultDoc = await this.databases.createDocument(
        APPWRITE_CONFIG.databaseId,
        APPWRITE_CONFIG.collectionId,
        ID.unique(),
        {
          filename: file.name,
          method: method,
          fileId: uploadedFile.$id,
          status: 'processing',
          width: 0,
          length: 0,
          height: 0
        }
      );

      if (onProgress) onProgress(40);

      // Step 3: Trigger Appwrite Function to process the file
      const execution = await this.functions.createExecution(
        APPWRITE_CONFIG.functionId,
        JSON.stringify({
          fileId: uploadedFile.$id,
          method: method,
          resultId: resultDoc.$id
        }),
        false // async execution
      );

      if (onProgress) onProgress(60);

      // Step 4: Poll for results (check every 2 seconds, max 60 seconds)
      const maxAttempts = 30;
      let attempts = 0;

      while (attempts < maxAttempts) {
        await new Promise(resolve => setTimeout(resolve, 2000));
        attempts++;

        if (onProgress) {
          const progress = 60 + Math.min((attempts / maxAttempts) * 40, 35);
          onProgress(Math.round(progress));
        }

        const updatedDoc = await this.databases.getDocument(
          APPWRITE_CONFIG.databaseId,
          APPWRITE_CONFIG.collectionId,
          resultDoc.$id
        );

        if (updatedDoc.status === 'completed') {
          if (onProgress) onProgress(100);
          return {
            success: true,
            filename: updatedDoc.filename,
            method: updatedDoc.method,
            dimensions: {
              width: updatedDoc.width,
              length: updatedDoc.length,
              height: updatedDoc.height
            },
            fileId: uploadedFile.$id,
            resultId: resultDoc.$id
          };
        } else if (updatedDoc.status === 'failed') {
          throw new Error(updatedDoc.error || 'Processing failed');
        }
      }

      throw new Error('Processing timeout. Please try again.');

    } catch (error) {
      if (error.message) {
        throw new Error(error.message);
      } else if (error.response) {
        throw new Error(error.response.message || 'Upload failed');
      } else {
        throw new Error('Upload failed. Please check your connection.');
      }
    }
  }

  /**
   * Get processing history
   * @param {number} limit - Maximum number of results to fetch
   */
  async getHistory(limit = 10) {
    try {
      const response = await this.databases.listDocuments(
        APPWRITE_CONFIG.databaseId,
        APPWRITE_CONFIG.collectionId,
        [
          Query.orderDesc('$createdAt'),
          Query.limit(limit)
        ]
      );
      return response.documents;
    } catch (error) {
      throw new Error('Failed to fetch history');
    }
  }

  /**
   * Delete a result and its associated file
   * @param {string} resultId - Document ID
   * @param {string} fileId - File ID
   */
  async deleteResult(resultId, fileId) {
    try {
      // Delete file from storage
      await this.storage.deleteFile(APPWRITE_CONFIG.bucketId, fileId);
      
      // Delete document from database
      await this.databases.deleteDocument(
        APPWRITE_CONFIG.databaseId,
        APPWRITE_CONFIG.collectionId,
        resultId
      );
      
      return true;
    } catch (error) {
      throw new Error('Failed to delete result');
    }
  }
}

export default new AppwriteService();
