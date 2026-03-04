type Environment = 'local' | 'production';

const CURRENT_ENVIRONMENT: Environment = 'production';

const API_CONFIG = {
  local: {
    baseURL: 'http://10.13.173.21:8000',
    description: 'Local development server',
  },
  production: {
    baseURL: 'https://cs179m-project-test.onrender.com', 
    description: 'Production server on Render',
  },
};

const config = API_CONFIG[CURRENT_ENVIRONMENT];

export const API_BASE_URL = config.baseURL;
export const API_ENVIRONMENT = CURRENT_ENVIRONMENT;
export const API_DESCRIPTION = config.description;

export const API_ENDPOINTS = {
  uploadPLY: '/api/upload-ply',
  downloadCleaned: (filename: string) => `/api/download-cleaned/${filename}`,
};

export const getAPIInfo = () => {
  console.log(`🌐 API Environment: ${API_ENVIRONMENT}`);
  console.log(`📡 Base URL: ${API_BASE_URL}`);
  console.log(`ℹ️  ${API_DESCRIPTION}`);
};
