import { LogLevel } from "@azure/msal-browser";

export const msalConfig = {
  auth: {
    clientId: process.env.REACT_APP_MICROSOFT_CLIENT_ID || "your_client_id_here",

    authority: `https://login.microsoftonline.com/${process.env.REACT_APP_MICROSOFT_TENANT_ID || "common"}`,
    redirectUri: process.env.REACT_APP_REDIRECT_URI || "http://localhost:3000/auth/callback"
  },
  cache: {
    cacheLocation: "sessionStorage",
    storeAuthStateInCookie: false
  },
  system: {
    loggerOptions: {
      loggerCallback: (level, message) => {
        if (level === LogLevel.Error) {
          console.error(message);
        }
      }
    }
  }
};

// Configured with ReadWrite permissions
export const loginRequest = {
  scopes: ["User.Read", "Calendars.ReadWrite"]
};

export const tokenRequest = {
  scopes: ["User.Read", "Calendars.ReadWrite"]
};