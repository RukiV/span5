# Microsoft Login Setup Guide

## Prerequisites
- Docker & Docker Compose installed
- Azure Active Directory account (free tier works)

## Setup Steps

### 1. Register Application in Azure AD

1. Go to [Azure Portal](https://portal.azure.com)
2. Search for and navigate to **Azure Active Directory**
3. Go to **App registrations** → Click **+ New registration**
4. Fill in:
   - **Name:** `Facility Management`
   - **Supported account types:** Select "Accounts in this organizational directory only"
   - **Redirect URI:** 
     - Platform: Web
     - URI: `http://localhost:3000/auth/callback`
5. Click **Register**

### 2. Copy Credentials

After registration, you'll see:
- **Application (client) ID** - Copy this
- **Directory (tenant) ID** - Copy this

Click on your app and go to **Certificates & secrets**:
- Click **+ New client secret**
- Copy the secret value (not the ID)

### 3. Create `.env` File

Copy `.env.example` to `.env` at the project root:

```bash
cp .env.example .env
```

Edit `.env` and replace:
```
MICROSOFT_CLIENT_ID=your_application_id_here
REACT_APP_MICROSOFT_CLIENT_ID=your_application_id_here
REACT_APP_MICROSOFT_TENANT_ID=your_directory_id_here
```

Example:
```
MICROSOFT_CLIENT_ID=12345678-1234-1234-1234-123456789abc
REACT_APP_MICROSOFT_CLIENT_ID=12345678-1234-1234-1234-123456789abc
REACT_APP_MICROSOFT_TENANT_ID=87654321-4321-4321-4321-cba987654321
```

### 4. Run Docker Compose

```bash
docker-compose up --build
```

This will:
- Install all npm packages for frontend
- Install all Python packages for backend
- Start PostgreSQL database
- Start backend API (port 8000)
- Start frontend (port 3000)

### 5. Access Application

- **Frontend:** http://localhost:3000
- **Backend API:** http://localhost:8000

### 6. Login Methods

**Traditional Login:**
- Username: `admin` / Password: `admin123`
- Username: `tech` / Password: `tech123`
- Username: `manager` / Password: `manager123`

**Microsoft Login:**
- Click "Teken in met Microsoft"
- Sign in with your Microsoft/Azure AD account
- First login will auto-create your user profile

## Troubleshooting

**"Popup was blocked"**
- Allow popups for localhost:3000 in browser settings

**"Invalid token"**
- Check MICROSOFT_CLIENT_ID matches in .env
- Verify redirect URI is registered in Azure AD

**"User not found"**
- First Microsoft login creates new user automatically
- Check backend logs with: `docker logs learn-backend-1`

**Rebuild Containers**
```bash
docker-compose down
docker-compose up --build
```

## Multiple Users

All users logging in via Microsoft will be automatically created in the system:
- **Traditional login:** Use pre-seeded test accounts
- **Microsoft login:** Any Microsoft account can register

Each user gets their own profile with default role assignment.
