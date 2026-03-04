import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet, ActivityIndicator, ScrollView } from 'react-native';
import * as DocumentPicker from 'expo-document-picker';
import axios from 'axios';
import { API_BASE_URL, API_ENVIRONMENT, API_ENDPOINTS, getAPIInfo } from '@/constants/api';

export default function HomeScreen() {
  const [file, setFile] = useState<any>(null);
  const [dimensions, setDimensions] = useState<any>(null);
  const [loading, setLoading] = useState(false);
  const [statusMessage, setStatusMessage] = useState('');
  const [error, setError] = useState<string | null>(null);

  // Log API configuration on mount
  useEffect(() => {
    getAPIInfo();
  }, []);

  const pickFile = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: ['*/*'],
        copyToCacheDirectory: true,
      });
      
      if (!result.canceled && result.assets && result.assets.length > 0) {
        const selectedFile = result.assets[0];
        
        if (!selectedFile.name.toLowerCase().endsWith('.ply')) {
          setError('Please select a .ply file');
          return;
        }
        
        setFile(selectedFile);
        setError(null);
        setDimensions(null);
        setStatusMessage('');
        console.log('📁 Selected file:', selectedFile.name);
      }
    } catch (err) {
      setError('Error picking file: ' + err);
      console.error(err);
    }
  };

  const processFile = async () => {
    if (!file) return;

    setLoading(true);
    setStatusMessage('Uploading...');
    setError(null);

    try {
      const formData = new FormData();
      // @ts-ignore
      formData.append('file', {
        uri: file.uri,
        type: 'application/octet-stream',
        name: file.name,
      });

      console.log(`📤 Uploading to: ${API_BASE_URL}${API_ENDPOINTS.uploadPLY}`);

      const response = await axios.post(`${API_BASE_URL}${API_ENDPOINTS.uploadPLY}`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
        timeout: 120000, // 2 minutes for Render cold starts
      });

      if (response.data.success) {
        setDimensions(response.data.dimensions);
        setStatusMessage('Complete ✓');
      }
    } catch (err: any) {
      console.error('Upload error:', err);
      if (err.code === 'ECONNABORTED') {
        setError('Server timeout - it may be waking up. Try again in 30 seconds.');
      } else {
        setError(err.message || 'Upload failed');
      }
    } finally {
      setLoading(false);
    }
  };

  const reset = () => {
    setFile(null);
    setDimensions(null);
    setStatusMessage('');
    setError(null);
  };

  return (
    <ScrollView contentContainerStyle={styles.container}>
      <Text style={styles.title}>PLY Processor</Text>
      
      {/* Environment Badge */}
      <View style={[
        styles.envBadge, 
        API_ENVIRONMENT === 'production' ? styles.envProduction : styles.envLocal
      ]}>
        <Text style={styles.envText}>
          {API_ENVIRONMENT === 'production' ? '☁️ Cloud' : '💻 Local'}
        </Text>
      </View>

      {file ? (
        <View style={styles.fileCard}>
          <Text style={styles.fileName}>📄 {file.name}</Text>
          <Text style={styles.fileSize}>{(file.size / 1024).toFixed(1)} KB</Text>
        </View>
      ) : (
        <View style={styles.emptyCard}>
          <Text style={styles.emptyText}>No file selected</Text>
        </View>
      )}

      <TouchableOpacity style={styles.button} onPress={pickFile} disabled={loading}>
        <Text style={styles.buttonText}>Select PLY File</Text>
      </TouchableOpacity>

      {loading && <ActivityIndicator size="large" color="#2196F3" style={styles.loader} />}
      {statusMessage && <Text style={styles.status}>{statusMessage}</Text>}
      {error && <Text style={styles.error}>❌ {error}</Text>}

      {dimensions && (
        <View style={styles.results}>
          <Text style={styles.resultsTitle}>Dimensions:</Text>
          <Text style={styles.dim}>Width: {dimensions.width.toFixed(3)} m</Text>
          <Text style={styles.dim}>Length: {dimensions.length.toFixed(3)} m</Text>
          <Text style={styles.dim}>Height: {dimensions.height.toFixed(3)} m</Text>
        </View>
      )}

      <View style={styles.buttonRow}>
        <TouchableOpacity 
          style={[styles.processButton, (!file || loading) && styles.disabled]}
          onPress={processFile}
          disabled={!file || loading}
        >
          <Text style={styles.buttonText}>Process</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.resetButton} onPress={reset}>
          <Text style={styles.buttonText}>Reset</Text>
        </TouchableOpacity>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flexGrow: 1,
    padding: 20,
    paddingTop: 60,
    backgroundColor: '#f5f5f5',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    marginBottom: 30,
    textAlign: 'center',
  },
  fileCard: {
    backgroundColor: '#E3F2FD',
    padding: 20,
    borderRadius: 10,
    marginBottom: 16,
  },
  fileName: {
    fontSize: 16,
    fontWeight: '600',
    marginBottom: 4,
  },
  fileSize: {
    fontSize: 14,
    color: '#666',
  },
  emptyCard: {
    backgroundColor: '#f0f0f0',
    padding: 30,
    borderRadius: 10,
    marginBottom: 16,
    alignItems: 'center',
  },
  emptyText: {
    fontSize: 16,
    color: '#999',
  },
  button: {
    backgroundColor: '#2196F3',
    padding: 16,
    borderRadius: 10,
    alignItems: 'center',
    marginBottom: 20,
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
  loader: {
    marginVertical: 20,
  },
  status: {
    fontSize: 16,
    color: '#4CAF50',
    textAlign: 'center',
    marginVertical: 10,
  },
  error: {
    fontSize: 14,
    color: '#F44336',
    textAlign: 'center',
    marginVertical: 10,
  },
  results: {
    backgroundColor: '#E8F5E9',
    padding: 20,
    borderRadius: 10,
    marginVertical: 20,
  },
  resultsTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 12,
  },
  dim: {
    fontSize: 16,
    marginVertical: 4,
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 12,
  },
  processButton: {
    flex: 1,
    backgroundColor: '#4CAF50',
    padding: 16,
    borderRadius: 10,
    alignItems: 'center',
  },
  resetButton: {
    backgroundColor: '#F44336',
    paddingHorizontal: 24,
    paddingVertical: 16,
    borderRadius: 10,
  },
  disabled: {
    backgroundColor: '#ccc',
  },
  envBadge: {
    alignSelf: 'center',
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 20,
    marginBottom: 20,
  },
  envProduction: {
    backgroundColor: '#4CAF50',
  },
  envLocal: {
    backgroundColor: '#FF9800',
  },
  envText: {
    color: 'white',
    fontSize: 12,
    fontWeight: '600',
  },
});
