import React, { useState, useEffect } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TouchableOpacity,
  ActivityIndicator,
  ScrollView,
  Alert,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import * as DocumentPicker from 'expo-document-picker';
import apiService from './services/apiService';

export default function App() {
  const [selectedFile, setSelectedFile] = useState(null);
  const [processing, setProcessing] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [method, setMethod] = useState('AABB');
  const [result, setResult] = useState(null);
  const [serverStatus, setServerStatus] = useState('checking');

  // Check server health on mount
  useEffect(() => {
    checkServerHealth();
  }, []);

  const checkServerHealth = async () => {
    try {
      await apiService.checkHealth();
      setServerStatus('connected');
    } catch (error) {
      setServerStatus('disconnected');
      Alert.alert(
        'Appwrite Connection Error',
        'Cannot connect to Appwrite. Please ensure:\n\n' +
        '1. You have set up your Appwrite project\n' +
        '2. The projectId in config.js is correct\n' +
        '3. You have internet connection\n\n' +
        'Visit: https://cloud.appwrite.io',
        [{ text: 'Retry', onPress: checkServerHealth }]
      );
    }
  };

  const pickDocument = async () => {
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: '*/*', // Allow all files; we'll filter on backend
        copyToCacheDirectory: true,
      });

      if (result.type === 'success' || !result.canceled) {
        const file = result.assets ? result.assets[0] : result;
        
        // Check if file is PLY
        if (!file.name.toLowerCase().endsWith('.ply')) {
          Alert.alert('Invalid File', 'Please select a PLY file');
          return;
        }

        setSelectedFile(file);
        setResult(null);
      }
    } catch (error) {
      Alert.alert('Error', 'Failed to pick file: ' + error.message);
    }
  };

  const uploadAndProcess = async () => {
    if (!selectedFile) {
      Alert.alert('No File Selected', 'Please select a PLY file first');
      return;
    }

    setProcessing(true);
    setUploadProgress(0);
    setResult(null);

    try {
      const response = await apiService.uploadPlyFile(
        selectedFile,
        method,
        (progress) => setUploadProgress(progress)
      );

      setResult(response);
      Alert.alert('Success', 'File processed successfully!');
    } catch (error) {
      Alert.alert('Processing Error', error.message);
    } finally {
      setProcessing(false);
      setUploadProgress(0);
    }
  };

  const renderMethodButton = (methodValue, methodLabel) => (
    <TouchableOpacity
      key={methodValue}
      style={[
        styles.methodButton,
        method === methodValue && styles.methodButtonActive,
      ]}
      onPress={() => setMethod(methodValue)}
      disabled={processing}
    >
      <Text
        style={[
          styles.methodButtonText,
          method === methodValue && styles.methodButtonTextActive,
        ]}
      >
        {methodLabel}
      </Text>
    </TouchableOpacity>
  );

  const renderServerStatus = () => {
    const statusConfig = {
      checking: { color: '#FFA500', text: 'Checking...' },
      connected: { color: '#4CAF50', text: 'Connected' },
      disconnected: { color: '#F44336', text: 'Disconnected' },
    };

    const config = statusConfig[serverStatus];

    return (
      <View style={styles.statusContainer}>
        <View style={[styles.statusDot, { backgroundColor: config.color }]} />
        <Text style={styles.statusText}>Server: {config.text}</Text>
      </View>
    );
  };

  return (
    <View style={styles.container}>
      <StatusBar style="dark" />
      
      <ScrollView contentContainerStyle={styles.scrollContent}>
        <Text style={styles.title}>PLY File Processor</Text>
        <Text style={styles.subtitle}>
          Upload and analyze 3D point cloud files with Appwrite
        </Text>

        {renderServerStatus()}

        {/* File Selection */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>1. Select PLY File</Text>
          <TouchableOpacity
            style={styles.primaryButton}
            onPress={pickDocument}
            disabled={processing}
          >
            <Text style={styles.primaryButtonText}>📁 Choose File</Text>
          </TouchableOpacity>

          {selectedFile && (
            <View style={styles.fileInfo}>
              <Text style={styles.fileName}>✓ {selectedFile.name}</Text>
              <Text style={styles.fileSize}>
                {(selectedFile.size / 1024 / 1024).toFixed(2)} MB
              </Text>
            </View>
          )}
        </View>

        {/* Method Selection */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>2. Choose Processing Method</Text>
          <View style={styles.methodContainer}>
            {renderMethodButton('AABB', 'AABB')}
            {renderMethodButton('OBB', 'OBB')}
            {renderMethodButton('PCA', 'PCA')}
          </View>
          <Text style={styles.methodDescription}>
            {method === 'AABB' && 'Axis-Aligned Bounding Box'}
            {method === 'OBB' && 'Oriented Bounding Box'}
            {method === 'PCA' && 'Principal Component Analysis'}
          </Text>
        </View>

        {/* Process Button */}
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>3. Process File</Text>
          <TouchableOpacity
            style={[
              styles.processButton,
              (!selectedFile || processing || serverStatus !== 'connected') &&
                styles.processButtonDisabled,
            ]}
            onPress={uploadAndProcess}
            disabled={!selectedFile || processing || serverStatus !== 'connected'}
          >
            {processing ? (
              <View style={styles.processingContainer}>
                <ActivityIndicator color="#fff" />
                <Text style={styles.primaryButtonText}>
                  {uploadProgress < 100
                    ? `Uploading ${uploadProgress}%`
                    : 'Processing...'}
                </Text>
              </View>
            ) : (
              <Text style={styles.primaryButtonText}>🚀 Process File</Text>
            )}
          </TouchableOpacity>
        </View>

        {/* Results */}
        {result && (
          <View style={styles.resultContainer}>
            <Text style={styles.resultTitle}>📊 Results</Text>
            <View style={styles.resultCard}>
              <Text style={styles.resultLabel}>File:</Text>
              <Text style={styles.resultValue}>{result.filename}</Text>
            </View>
            <View style={styles.resultCard}>
              <Text style={styles.resultLabel}>Method:</Text>
              <Text style={styles.resultValue}>{result.method}</Text>
            </View>
            <View style={styles.dimensionsContainer}>
              <Text style={styles.dimensionsTitle}>Dimensions</Text>
              <View style={styles.dimensionRow}>
                <Text style={styles.dimensionLabel}>Width:</Text>
                <Text style={styles.dimensionValue}>
                  {result.dimensions.width.toFixed(3)} units
                </Text>
              </View>
              <View style={styles.dimensionRow}>
                <Text style={styles.dimensionLabel}>Length:</Text>
                <Text style={styles.dimensionValue}>
                  {result.dimensions.length.toFixed(3)} units
                </Text>
              </View>
              <View style={styles.dimensionRow}>
                <Text style={styles.dimensionLabel}>Height:</Text>
                <Text style={styles.dimensionValue}>
                  {result.dimensions.height.toFixed(3)} units
                </Text>
              </View>
            </View>
          </View>
        )}
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  scrollContent: {
    padding: 20,
    paddingTop: 60,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 8,
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    marginBottom: 24,
    textAlign: 'center',
  },
  statusContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 8,
    paddingHorizontal: 16,
    backgroundColor: '#fff',
    borderRadius: 20,
    marginBottom: 24,
    alignSelf: 'center',
  },
  statusDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginRight: 8,
  },
  statusText: {
    fontSize: 14,
    color: '#666',
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 18,
    fontWeight: '600',
    color: '#333',
    marginBottom: 12,
  },
  primaryButton: {
    backgroundColor: '#007AFF',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  primaryButtonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: '600',
  },
  processButton: {
    backgroundColor: '#34C759',
    padding: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  processButtonDisabled: {
    backgroundColor: '#ccc',
  },
  processingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  fileInfo: {
    marginTop: 12,
    padding: 12,
    backgroundColor: '#E8F5E9',
    borderRadius: 8,
  },
  fileName: {
    fontSize: 14,
    color: '#2E7D32',
    fontWeight: '500',
  },
  fileSize: {
    fontSize: 12,
    color: '#66BB6A',
    marginTop: 4,
  },
  methodContainer: {
    flexDirection: 'row',
    gap: 8,
  },
  methodButton: {
    flex: 1,
    padding: 12,
    borderRadius: 8,
    backgroundColor: '#fff',
    borderWidth: 2,
    borderColor: '#ddd',
    alignItems: 'center',
  },
  methodButtonActive: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  methodButtonText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
  },
  methodButtonTextActive: {
    color: '#fff',
  },
  methodDescription: {
    marginTop: 8,
    fontSize: 13,
    color: '#666',
    textAlign: 'center',
  },
  resultContainer: {
    backgroundColor: '#fff',
    padding: 20,
    borderRadius: 12,
    marginTop: 8,
  },
  resultTitle: {
    fontSize: 20,
    fontWeight: '600',
    color: '#333',
    marginBottom: 16,
  },
  resultCard: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#eee',
  },
  resultLabel: {
    fontSize: 14,
    color: '#666',
  },
  resultValue: {
    fontSize: 14,
    color: '#333',
    fontWeight: '500',
  },
  dimensionsContainer: {
    marginTop: 16,
    padding: 16,
    backgroundColor: '#F0F9FF',
    borderRadius: 8,
  },
  dimensionsTitle: {
    fontSize: 16,
    fontWeight: '600',
    color: '#0284C7',
    marginBottom: 12,
  },
  dimensionRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingVertical: 6,
  },
  dimensionLabel: {
    fontSize: 15,
    color: '#0369A1',
  },
  dimensionValue: {
    fontSize: 15,
    fontWeight: '600',
    color: '#0C4A6E',
  },
});
