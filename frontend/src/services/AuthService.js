/*// Authentication service
// Currently uses local testing data
// When backend is ready, change the routes below to call actual backend endpoints

const testUsers = [
  {
    user_id: 1,
    username: 'admin',
    password: 'admin123',
    name: 'Admin User',
    email: 'admin@fbs.com',
    role: 'Admin',
    status: 'Aktief'
  },
  {
    user_id: 2,
    username: 'tech',
    password: 'tech123',
    name: 'Technician John',
    email: 'john@fbs.com',
    role: 'Technician',
    status: 'Aktief'
  },
  {
    user_id: 3,
    username: 'manager',
    password: 'manager123',
    name: 'Manager Sarah',
    email: 'sarah@fbs.com',
    role: 'Manager',
    status: 'Aktief'
  }
];

const generateToken = (userId) => {
  return `token_${userId}_${Date.now()}`;
};

export const authService = {
  // LOCAL TESTING VERSION
  // CHANGE THIS TO: apiClient.post('/auth/login', { username, password })  
  login: async (username, password) => {
    await new Promise(resolve => setTimeout(resolve, 1000)); // Simulate network delay
    
    const user = testUsers.find(u => u.username === username && u.password === password);
    
    if (!user) {
      const error = new Error('Invalid credentials');
      error.response = { data: { detail: 'Gebruikersnaam of wagwoord is ongeldig' } };
      throw error;
    }
    
    return {
      data: {
        access_token: generateToken(user.user_id),
        token_type: 'bearer'
      }
    };
  },

  
  // CHANGE THIS TO: apiClient.get('/auth/me')
  me: async () => {
    await new Promise(resolve => setTimeout(resolve, 500));
    
    const token = localStorage.getItem('token');
    if (!token) {
      const error = new Error('Not authenticated');
      error.response = { data: { detail: 'Nie geverifieer nie' } };
      throw error;
    }
    
    const userId = parseInt(token.split('_')[1]);
    const user = testUsers.find(u => u.user_id === userId);
    
    if (!user) {
      const error = new Error('User not found');
      error.response = { data: { detail: 'Gebruiker nie gevind nie' } };
      throw error;
    }
    
    return {
      data: {
        user_id: user.user_id,
        username: user.username,
        name: user.name,
        email: user.email,
        role: user.role,
        status: user.status
      }
    };
  },

  
  // CHANGE THIS TO: apiClient.post('/auth/logout')
  logout: async () => {
    await new Promise(resolve => setTimeout(resolve, 500));
    return { data: { message: 'Logout successful' } };
  }

  
};

export default authService; */

