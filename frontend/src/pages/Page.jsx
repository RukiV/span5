import { useNavigate } from "react-router-dom";
import { authAPI } from '../services/api';
import { clearAuthSession } from '../authSession';


export function useLogout() {
  const navigate = useNavigate();

  const logout = async (e) => {
    if (e) e.preventDefault();
    // mark that logout started (diagnostic)
    try { sessionStorage.setItem('logout_ran', new Date().toISOString()); } catch(_) {}
    
    try {
      // Call backend logout endpoint
      await authAPI.logout();
    } catch (err) {
      // Ignore errors - we're logging out anyway
      console.error("Backend logout error:", err);
    }
    
    clearAuthSession();
    
    // Then redirect to login with absolute URL to force complete reload
    // Use window.location.replace to prevent back button access
    window.location.replace(window.location.origin + '/login');
  };

  return logout;
}
